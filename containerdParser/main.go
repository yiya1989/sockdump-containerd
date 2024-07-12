package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/containerd/containerd/runtime/v2/task"
	"github.com/containerd/ttrpc"
	"github.com/gogo/protobuf/proto"
	spb "google.golang.org/genproto/googleapis/rpc/status"
	"google.golang.org/grpc/codes"

	"containerdParser/pkg"
)

var req_map map[string]proto.Message
var resp_map map[string]proto.Message

func init() {
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

func getArgs() (debug bool, msgType string, method string, payload string) {
	var debugStr string
	if len(os.Args) >= 2 {
		debugStr = os.Args[1]
	}
	if len(os.Args) >= 3 {
		msgType = os.Args[2]
	}
	if len(os.Args) >= 4 {
		method = os.Args[3]
	}
	if len(os.Args) >= 5 {
		payload = os.Args[4]
	}

	if debugStr == "" {
		debugStr = os.Getenv("LUA_DEBUG")
	}
	if msgType == "" {
		msgType = os.Getenv("LUA_MSGTYPE")
	}
	if method == "" {
		method = os.Getenv("LUA_METHOD")
	}
	if payload == "" {
		payload = os.Getenv("LUA_PAYLOAD")
	}

	if debugStr == "1" || debugStr == "true" {
		debug = true
	}

	return
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

func parsePayload(method string, payload []byte, msgType string) (req, resp proto.Message, Status *spb.Status, err error) {
	codec := pkg.Codec{}

	if msgType == "1" {
		ttReq := &ttrpc.Request{}
		err = codec.Unmarshal(payload, ttReq)
		if err != nil {
			return nil, nil, nil, err
		}
		dataReq, ok := req_map[ttReq.Method]
		if !ok || dataReq == nil {
			return nil, nil, nil, fmt.Errorf("cann't find method's request: %s", ttReq.Method)
		}
		err = codec.Unmarshal(ttReq.Payload, dataReq)
		if err != nil {
			return nil, nil, nil, err
		}
		return dataReq, nil, nil, nil
	} else if msgType == "2" {
		ttResp := &ttrpc.Response{}
		err = codec.Unmarshal(payload, ttResp)
		if err != nil {
			return nil, nil, nil, err
		}

		if ttResp.Status != nil && ttResp.Status.Code != int32(codes.OK) {
			return nil, nil, ttResp.Status, nil
		}
		dataResp, ok := resp_map[method]
		if !ok || dataResp == nil {
			return nil, nil, nil, fmt.Errorf("cann't find method's response: %s", method)
		}
		err = codec.Unmarshal(ttResp.Payload, dataResp)
		if err != nil {
			return nil, nil, nil, err
		}
		return nil, dataResp, ttResp.Status, nil
	} else {
		return nil, nil, nil, fmt.Errorf("unsupported msg type: %s", msgType)
	}
}

func parseAndShowPayload(method string, payloadStr string, msgType string) (result Result) {

	if len(payloadStr) == 0 {
		errMsg := "payload is empty"
		log.Printf(errMsg)
		result.Err = errMsg
		return
	}

	if len(msgType) == 0 {
		errMsg := "msgType is empty"
		log.Printf(errMsg)
		result.Err = errMsg
		return
	}

	payload, err := hex.DecodeString(payloadStr)
	if err != nil {
		errMsg := fmt.Sprintf("hex.DecodeString payload failed, err: %s", err.Error())
		log.Printf(errMsg)
		result.Err = errMsg
		return
	}

	dateReq, dataResp, status, err := parsePayload(method, payload, msgType)
	if err != nil {
		errMsg := fmt.Sprintf("parsePayload failed: %s", err.Error())
		log.Printf(errMsg)
		result.Err = errMsg
		return
	}
	log.Printf("status: %s", status.String())
	if dateReq != nil {
		log.Printf("dateReq: %s, ", dateReq.String())
	}
	if dataResp != nil {
		log.Printf("dataResp: %s, ", dataResp.String())
	}
	result = Result{
		Method: method,
		Req:    dateReq,
		Resp:   dataResp,
		Status: status,
	}

	return result
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

	parseAndShowPayload("Wait", creqHexString, "1")
}

type Result struct {
	Method string        `json:"method"`
	Req    proto.Message `json:"req"`
	Resp   proto.Message `json:"resp"`
	Status *spb.Status   `json:"status"`
	Err    string        `json:"err"`
}

func main() {
	//for local generate and reparse
	// testGenerateParse()

	debug, msgType, method, payload := getArgs()
	if !debug {
		log.SetOutput(io.Discard)
	}
	log.Printf("input args: debug: %t, msgType: %s, method: %s, payload: %s", debug, msgType, method, payload)

	// method = "Wait"
	// msgType = "1"
	// payload = "0A17636F6E7461696E6572642E7461736B2E76322E5461736B1204576169741A420A403233313066373937393338633637396638663764393830366462623533356166323865383131346131306264626563323066346663323831616136653764653120F8C197A0252A240A1A636F6E7461696E6572642D6E616D6573706163652D747472706312066B38732E696F"

	// method = "Wait"
	// msgType = "2"
	// payload = "120F0809120B089FFCBDB40610DDD4EB12"

	result := parseAndShowPayload(method, payload, msgType)
	log.Printf("result: %#v", result)
	bytes, err := json.Marshal(result)
	if err != nil {
		log.Printf("{\"err\": %s}", err.Error())
		return
	}
	fmt.Println(string(bytes))
}
