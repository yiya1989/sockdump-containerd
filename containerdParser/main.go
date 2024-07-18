package main

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"reflect"
	"strconv"
	"strings"

	"github.com/containerd/containerd/runtime/v2/task"
	"github.com/containerd/ttrpc"
	"github.com/gogo/protobuf/proto"
	"github.com/shirou/gopsutil/v4/process"
	"github.com/spf13/cobra"
	spb "google.golang.org/genproto/googleapis/rpc/status"
	"google.golang.org/grpc/codes"

	"containerdParser/pkg"
)

func init() {
	cfg = Cfg{}
	req_map = map[string]proto.Message{}
	resp_map = map[string]proto.Message{}

	req_map["State"] = &task.StateRequest{}
	req_map["Create"] = &task.CreateTaskRequest{}
	req_map["Start"] = &task.StartRequest{}
	req_map["Delete"] = &task.DeleteRequest{}
	req_map["Pids"] = &task.PidsRequest{}
	req_map["Pause"] = &task.PauseRequest{}
	req_map["Resume"] = &task.ResumeRequest{}
	req_map["Checkpoint"] = &task.CheckpointTaskRequest{}
	req_map["Kill"] = &task.KillRequest{}
	req_map["Exec"] = &task.ExecProcessRequest{}
	req_map["ResizePty"] = &task.ResizePtyRequest{}
	req_map["CloseIO"] = &task.CloseIORequest{}
	req_map["Update"] = &task.UpdateTaskRequest{}
	req_map["Wait"] = &task.WaitRequest{}
	req_map["Stats"] = &task.StatsRequest{}
	req_map["Connect"] = &task.ConnectRequest{}
	req_map["Shutdown"] = &task.ShutdownRequest{}

	resp_map["State"] = &task.StateResponse{}
	resp_map["Create"] = &task.CreateTaskResponse{}
	resp_map["Start"] = &task.StartResponse{}
	resp_map["Delete"] = &task.DeleteResponse{}
	resp_map["Pids"] = &task.PidsResponse{}
	resp_map["Wait"] = &task.WaitResponse{}
	resp_map["Stats"] = &task.StatsResponse{}
	resp_map["Connect"] = &task.ConnectResponse{}
}

type Cfg struct {
	debug   bool
	pppid   bool
	msgType string
	method  string
	frame   string
	ppid    string
}

func (c Cfg) String() string {
	return fmt.Sprintf("input args: debug: %t, msgType: %s, method: %s, frame: %s, ppid: %s",
		cfg.debug, cfg.msgType, cfg.method, cfg.frame, cfg.ppid)
}

func getUnrecognized(input interface{}) []byte {
	value := reflect.ValueOf(input).Elem()
	fieldValue := value.FieldByName("XXX_unrecognized")
	if !fieldValue.CanInterface() {
		return nil
	}
	result, ok := fieldValue.Interface().([]byte)
	if ok {
		log.Printf("getUnrecognized data: %v", result)
	}
	return result
}

const guessMethodPrifix = "guess_"

var cfg Cfg
var req_map map[string]proto.Message
var resp_map map[string]proto.Message

var rootCmd = &cobra.Command{
	Use:   "ttrpc-parser",
	Short: "ttrpc packet parser",
	Long:  `ttrpc packet parser`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return runCommand(cfg)
	},
}

func RunCmd() Cfg {

	rootCmd.PersistentFlags().BoolVarP(&cfg.debug, "debug", "d", false, "debug mode, show debug log")
	rootCmd.PersistentFlags().BoolVarP(&cfg.pppid, "pppid", "", false, "default false. pppid mode will use pppid as uniq task id, otherwise use ppid")
	rootCmd.PersistentFlags().StringVarP(&cfg.msgType, "msg_type", "t", "", "msg type: 0, 1, 2")
	rootCmd.PersistentFlags().StringVarP(&cfg.method, "method", "m", "", "msg method, request will auto detect")
	rootCmd.PersistentFlags().StringVarP(&cfg.frame, "frame", "f", "", "msg frame, include total ttrpc packet")
	rootCmd.PersistentFlags().StringVarP(&cfg.ppid, "ppid", "p", "", "caller pid, it not defined, then auto detect")

	rootCmd.Execute()
	return cfg
}

func getString(input interface{}) []byte {
	b, _ := json.Marshal(input)
	return b
}

func generatePayload(method string, req interface{}) ([]byte, error) {
	codec := pkg.Codec{}

	reqPayload, err := codec.Marshal(req)
	if err != nil {
		return nil, err
	}

	creq := &ttrpc.Request{
		Service: "containerd.shim.kata.v2",
		Method:  method,
		Payload: reqPayload,
	}

	creqPayload, err := codec.Marshal(creq)
	if err != nil {
		return nil, err
	}

	return creqPayload, nil
}

func parsePayload(method string, payload []byte, msgType string) (real_method string, req, resp []byte, Status *spb.Status, err error) {
	codec := pkg.Codec{}

	if msgType == "01" {
		ttReq := &ttrpc.Request{}
		err = codec.Unmarshal(payload, ttReq)
		if err != nil {
			return "", nil, nil, nil, err
		}
		dataReq, ok := req_map[ttReq.Method]
		if !ok || dataReq == nil {
			return "", nil, nil, nil, fmt.Errorf("cann't find method's request: %s", ttReq.Method)
		}
		err = codec.Unmarshal(ttReq.Payload, dataReq)
		if err != nil {
			return "", nil, nil, nil, err
		}
		return ttReq.Method, getString(dataReq), nil, nil, nil
	} else if msgType == "02" {
		ttResp := &ttrpc.Response{}
		err = codec.Unmarshal(payload, ttResp)
		if err != nil {
			return method, nil, nil, nil, err
		}

		if ttResp.Status != nil && ttResp.Status.Code != int32(codes.OK) {
			return method, nil, nil, ttResp.Status, nil
		}

		if len(method) == 0 && len(ttResp.Payload) == 0 {
			return method, nil, nil, nil, nil
			// return method, "", "", nil, errors.New("method name for response is necessary")
		}

		if len(method) != 0 && !strings.HasPrefix(method, guessMethodPrifix) {
			dataResp, ok := resp_map[method]
			if !ok || dataResp == nil {
				return method, nil, nil, nil, fmt.Errorf("cann't find method's response struct: %s", method)
			}
			err = codec.Unmarshal(ttResp.Payload, dataResp)
			if err != nil {
				return method, nil, nil, nil, err
			}
			return method, nil, getString(dataResp), ttResp.Status, nil
		} else {
			var matchedMethod []string
			dataResp := map[string]interface{}{}
			for key, value := range resp_map {
				err = codec.Unmarshal(ttResp.Payload, value)
				if err != nil {
					continue
				}
				unrecognized := getUnrecognized(value)
				if len(unrecognized) > 0 {
					continue
				}
				matchedMethod = append(matchedMethod, key)
				dataResp[key] = value
			}
			if len(dataResp) == 0 {
				return method, nil, nil, nil, fmt.Errorf("cann't guess any method's response struct")
			}
			method = guessMethodPrifix + strings.Join(matchedMethod, "_")
			resp = getString(dataResp)
			return method, nil, resp, ttResp.Status, nil
		}

	} else {
		return method, nil, nil, nil, fmt.Errorf("unsupported msg type: %s", msgType)
	}
}

func parsePayloadWrap(method string, payloadStr string, msgType string) (real_method string, req, resp []byte, status *spb.Status, err error) {

	if len(payloadStr) == 0 {
		// fill method
		if method == "" {
			method = "unknown_empty"
		}
		return method, nil, nil, nil, nil
	}

	if len(msgType) == 0 {
		return "", nil, nil, nil, errors.New("msgType is empty")
	}

	payload, err := hex.DecodeString(payloadStr)
	if err != nil {
		return "", nil, nil, nil, fmt.Errorf("hex.DecodeString payload failed, err: %s", err.Error())
	}

	real_method, req, resp, status, err = parsePayload(method, payload, msgType)
	if err != nil {
		return "", nil, nil, nil, fmt.Errorf("parsePayload failed: %s", err.Error())
	}
	log.Printf("status: %s", status.String())
	if req != nil {
		log.Printf("req: %s, ", req)
	}
	if resp != nil {
		log.Printf("resp: %s, ", resp)
	}

	return real_method, req, resp, status, nil
}

func testGenerateParse() {
	req := &task.StateRequest{
		ID: "1234567890",
	}
	creqPayload, err := generatePayload("State", req)
	if err != nil {
		log.Panicf(err.Error())
	}
	log.Printf("creqPayload: %#v", creqPayload)
	creqHexString := hex.EncodeToString(creqPayload)
	log.Printf("creqHexString: %s", creqHexString)

	parsePayloadWrap("Wait", string(creqHexString), "1")
}

type CacheMgr struct {
	TaskId string
	cache  map[string]string
}

func (c CacheMgr) String() string {
	b, _ := json.Marshal(c.cache)
	return string(b)
}

func (c CacheMgr) cacheFile() string {
	return fmt.Sprintf("cache.%s", c.TaskId)
}

func (c *CacheMgr) Get(key string) string {
	if c.cache == nil {
		c.cache = make(map[string]string)
	}
	return c.cache[key]
}

func (c *CacheMgr) Add(key, value string) {
	if c.cache == nil {
		c.cache = make(map[string]string)
	}
	c.cache[key] = value
}

func (c *CacheMgr) Save() error {
	content, err := json.Marshal(c.cache)
	if err != nil {
		return err
	}

	// 写入内容到文件，如果文件不存在则创建
	err = os.WriteFile(c.cacheFile(), content, 0666)
	if err != nil {
		return fmt.Errorf("failed to write file: %v", err)
	}
	return nil
}
func (c *CacheMgr) Load() error {
	// 写入内容到文件，如果文件不存在则创建
	content, err := os.ReadFile(c.cacheFile())
	if err != nil {
		if os.IsNotExist(err) {
			c.cache = make(map[string]string)
			return nil
		}
		return fmt.Errorf("failed to write file: %v", err)
	}

	return json.Unmarshal(content, &c.cache)
}

type Result struct {
	TaskId     string          `json:"task_id"`
	DataLength uint64          `json:"data_length"`
	StreamID   string          `json:"stream_id"`
	MsgType    string          `json:"msg_type"`
	MsgFlags   string          `json:"msg_flags"`
	Method     string          `json:"method"`
	Req        json.RawMessage `json:"req"`
	Resp       json.RawMessage `json:"resp"`
	Status     *spb.Status     `json:"status"`
	Err        string          `json:"err"`
}

func parseFrameHeader(hexFrame string) (dataLength uint64, streamId string, msgType string, msgFlags string, payload []byte, err error) {
	// examle: 0000008a 00001893 01 00
	if len(hexFrame) < 20 {
		return 0, "", "", "", nil, fmt.Errorf("frame error, ttrpc frame min lenth should be 20 hex string")
	}

	// dataLength, err = hex.DecodeString(hexFrame[:8])
	dataLength, err = strconv.ParseUint(hexFrame[:8], 16, 64)
	if err != nil {
		return 0, "", "", "", nil, fmt.Errorf("hex.dataLength payload failed, hexString: %s, err: %s", hexFrame[:8], err.Error())
	}

	streamId = hexFrame[8:16]
	msgType = hexFrame[16:18]
	msgFlags = hexFrame[18:20]

	payload = []byte(hexFrame[20:])
	return
}

func get_cap_task_ppid(cfg Cfg) (pidStr string, err error) {
	ppid := os.Getppid()
	log.Printf("parentpid: %d", ppid)

	if cfg.pppid {
		p, err := process.NewProcess(int32(ppid))
		if err != nil {
			return "", err
		}

		pppid, err := p.Ppid()
		if err != nil {
			return "", err
		}
		ppid = int(pppid)
		log.Printf("wireshark mode, use parentpid's parentpid: %d", ppid)
	}
	pidStr = fmt.Sprintf("%d", ppid)

	return
}

func showResult(result Result, err error) {
	if err != nil {
		result.Err = err.Error()
		log.Print(err)
	}

	bytes, err := json.Marshal(result)
	if err != nil {
		log.Printf("result: %#v", result)
		log.Printf("{\"err\": %s}", err.Error())
		return
	}
	fmt.Println(string(bytes))
}

func runCommand(cfg Cfg) error {
	if !cfg.debug {
		log.SetOutput(io.Discard)
	}
	log.Print(cfg.String())

	//for local generate and reparse
	// testGenerateParse()

	// method = "Wait"
	// msgType = "1"
	// payload = "0A17636F6E7461696E6572642E7461736B2E76322E5461736B1204576169741A420A403233313066373937393338633637396638663764393830366462623533356166323865383131346131306264626563323066346663323831616136653764653120F8C197A0252A240A1A636F6E7461696E6572642D6E616D6573706163652D747472706312066B38732E696F"

	// method = "Wait"
	// msgType = "2"
	// payload = "120F0809120B089FFCBDB40610DDD4EB12"

	// 0000008a0000189301000a17636f6e7461696e6572642e7461736b2e76322e5461736b120553746174731a420a40623063613530666438633236363134373561346631336636383864636163623365636433643936383263636264333030613538336364646161646638376131342a240a1a636f6e7461696e6572642d6e616d6573706163652d747472706312066b38732e696f

	var result Result

	ppid, err := get_cap_task_ppid(cfg)
	if err != nil {
		errWrap := fmt.Errorf("parseFrameHeader err: %s", err.Error())
		showResult(result, errWrap)
		return nil
	}
	log.Printf("ppid: %s", ppid)

	cacheMgr := CacheMgr{
		TaskId: ppid,
	}
	if err := cacheMgr.Load(); err != nil {
		showResult(result, fmt.Errorf("load task cache failed, err: %w", err))
		return nil
	}
	// println(cacheMgr.String())

	dataLength, streamId, msgType, msgFlags, payload, err := parseFrameHeader(cfg.frame)
	result = Result{
		TaskId:     ppid,
		DataLength: dataLength,
		StreamID:   streamId,
		MsgType:    msgType,
		MsgFlags:   msgFlags,
	}
	if err != nil {
		errWrap := fmt.Errorf("parseFrameHeader err: %s", err.Error())
		showResult(result, errWrap)
		return nil
	}

	input_method := cacheMgr.Get(streamId)
	if cfg.method != "" {
		input_method = cfg.method
	}
	method, req, resp, status, err := parsePayloadWrap(input_method, string(payload), string(msgType))
	result.Method = method
	result.Req = json.RawMessage(req)
	result.Resp = json.RawMessage(resp)
	result.Status = status
	if err != nil {
		errWrap := fmt.Errorf("parsePayload err: %s", err.Error())
		showResult(result, errWrap)
		return nil
	}

	if result.Method != "" {
		cacheMgr.Add(streamId, result.Method)
	}
	if err := cacheMgr.Save(); err != nil {
		showResult(result, fmt.Errorf("save task cache failed, err: %w", err))
		return nil
	}

	showResult(result, nil)
	return nil
}

func main() {

	_ = RunCmd()

}
