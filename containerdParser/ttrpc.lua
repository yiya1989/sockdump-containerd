
print(_VERSION)

-- local pb = require "pb"
-- local protoc = require "protoc"

local status, pb = pcall(require, "pb")
if not status then
    error("Failed to load luapb library: " .. pb)
end

local status, protoc = pcall(require, "protoc")
if not status then
    error("Failed to load protoc library: " .. protoc)
end

local json = require "dkjson"

local process = require('process')

-- 加载 proto 文件
local function loadProto(protoFile)
    local p = protoc.new()
    local protoContent = ""
    
    -- 读取 proto 文件内容
    local file = io.open(protoFile, "r")
    if file then
        protoContent = file:read("*all")
        file:close()
    else
        error("Cannot open proto file: " .. protoFile)
    end
    
    -- 编译 proto 文件内容
    -- print(protoContent)
    p:load(protoContent)
end

-- 打印表格（用于调试）
local function printTable(t, indent)
    if t == nil then
        return
    end
    indent = indent or 0
    local prefix = string.rep(" ", indent)
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(prefix .. k .. ":")
            printTable(v, indent + 2)
        else
            print(prefix .. k .. ": " .. tostring(v))
        end
    end
end

local function printJson(table, indent)
    if table == nil then
        return ""
    end
    local json_data = json.encode(table, { indent = indent })
    -- print(json_data)
    return json_data
end


local function showMap(data)
    for k, v in pairs(data) do
        print(k, v, type(k), type(v))
    end      
end

local defaultMapDataName = "map.txt"

function updateMapToFile(map, filename)
    if not filename then
        filename = defaultMapDataName
    end
    
    -- 打开文件以写入模式
    local file = io.open(filename, "w+")
    if file then
      -- 遍历哈希表的键值对，并将其写入文件
      for k, v in pairs(map) do
        file:write(k .. "=" .. v .. "\n")
      end
      file:close()
    --   print("Map updated to file: " .. filename)
    else
      print("Failed to open file: " .. filename)
    end
  end
  
  -- 函数用于从文件加载哈希表
function loadMapFromFile(filename)
    if not filename then
        filename = defaultMapDataName
    end
    
    local map = {}
    -- 打开文件以读取模式
    local file = io.open(filename, "r")
    if file then
      -- 逐行读取文件内容，并解析为键值对更新哈希表
      for line in file:lines() do
        local key, value = line:match("([^=]+)=(.+)")
        if key and value then
          map[key] = value
        end
      end
      file:close()
    --   print("Map loaded from file: " .. filename)
      return map
    else
      print("Failed to open file: " .. filename)
      return {}
    end
    return nil
end
  
-- 解析二进制数据
local function parseBinaryData(messageType, binaryData)
    local decodedData = pb.decode(messageType, binaryData)
    if not decodedData then
        error("Failed to decode binary data.")
    end
    return decodedData
end

-- 将浮点数时间戳转换为指定格式的时间字符串
local function formatTimestamp(timestamp)
    if timestamp == nil then
        return ""
    end

    local seconds = math.floor(timestamp) -- 获取整数部分（秒）
    local microseconds = math.floor((timestamp - seconds) * 1000000) -- 获取小数部分（微秒）
    -- date_str = os.date("%Y-%m-%d %H:%M:%S", time)
    date_str = os.date("%H:%M:%S", seconds)

    -- 构建时间字符串
    local formattedString = string.format("%s.%06d", date_str, microseconds)

    return formattedString
end

 -- 将字节数组转换为十六进制字符串
local function bytesToHexString(bytes)
    local hexString = ""
    for i = 1, #bytes do
        hexString = hexString .. string.format("%02X", bytes[i])
    end
    return hexString
 end
 
 -- 将字符串转换为十六进制字符串
 local function stringToHexString(str)
    local hexString = ""
    for i = 1, #str do
        local byteValue = string.byte(str, i)
        hexString = hexString .. string.format("%02X", byteValue)
    end
    return hexString
 end

-- 执行本地命令并获取输出
local function executeCommand(command)
    local file = io.popen(command)
    local output = file:read("*a")
    file:close()
    return output
end

local formattedTime = formatTimestamp(timestamp)
print(formattedTime)
local req_map = {}
req_map["State"]="StateRequest"
req_map["Create"]="CreateTaskRequest"
req_map["Start"]="StartRequest"
req_map["Delete"]="DeleteRequest"
req_map["Pids"]="PidsRequest"
req_map["Pause"]="PauseRequest"
req_map["Resume"]="ResumeRequest"
req_map["Checkpoint"]="CheckpointTaskRequest"
req_map["Kill"]="KillRequest"
req_map["Exec"]="ExecProcessRequest"
req_map["ResizePty"]="ResizePtyRequest"
req_map["CloseIO"]="CloseIORequest"
req_map["Update"]="UpdateTaskRequest"
req_map["Wait"]="WaitRequest"
req_map["Stats"]="StatsRequest"
req_map["Connect"]="ConnectRequest"
req_map["Shutdown"]="ShutdownRequest"


local resp_map = {}
resp_map["State"]="StateResponse"
resp_map["Create"]="CreateTaskResponse"
resp_map["Start"]="StartResponse"
resp_map["Delete"]="DeleteResponse"
resp_map["Pids"]="PidsResponse"
resp_map["Wait"]="WaitResponse"
resp_map["Stats"]="StatsResponse"
resp_map["Connect"]="ConnectResponse"

local msgTypeMap = {
    ["1"] = "Request(0x01)",
    ["2"] = "Response(0x02)",
    ["3"] = "Stream(0x03)"
}

-- 配置文件路径和消息类型
-- local messageType = "containerd.task.v2.Task"
local messageType = ""
local unkonwn_method = "<unkonwn>"

local dummy_proto = Proto("dummy", "Dummy Protocol")

local dst_field = ProtoField.uint64("dummy.dst", "Destination")
local src_field = ProtoField.uint64("dummy.src", "Source")
local ttrpc_len_field = ProtoField.bytes("dummy.ttrpc_len", "TTRPC Data Length")
local ttrpc_stream_id_field = ProtoField.bytes("dummy.stream_id", "TTRPC Stream ID")
local ttrpc_msg_type_field = ProtoField.string("dummy.msg_type", "TTRPC Msg Type")
local ttrpc_flags_field = ProtoField.bytes("dummy.flags", "TTRPC Flags")
-- local ttrpc_headerfield = ProtoField.bytes("dummy.header", "TTRPC Header")
local ttrpc_data_field = ProtoField.bytes("dummy.data", "TTRPC Data")
local ttrpc_method_field = ProtoField.string("dummy.method", "TTRPC Method")
local ttrpc_req_field = ProtoField.string("dummy.req", "TTRPC Req")
local ttrpc_resp_status_field = ProtoField.string("dummy.resp_status", "TTRPC Resp Rpc Status")
local ttrpc_resp_field = ProtoField.string("dummy.resp", "TTRPC Resp")

dummy_proto.fields = { dst_field, src_field, 
    ttrpc_len_field, ttrpc_stream_id_field, ttrpc_msg_type_field, ttrpc_flags_field, -- ttrpc_headerfield,
    ttrpc_data_field, ttrpc_method_field, ttrpc_req_field, ttrpc_resp_status_field, ttrpc_resp_field}

function dummy_proto.dissector(buf, pinfo, tree)
    local buf_len = buf:len()

    local subtree = tree:add(dummy_proto, buf(), "Dummy Protocol Data")
    subtree:add(dst_field, buf(0, 8))
    subtree:add(src_field, buf(8, 8))

    pinfo.cols.protocol = "DUMMY"
    local dst = tostring(buf(0, 8):uint64())
    local src = tostring(buf(8, 8):uint64())
    pinfo.cols.dst = dst
    pinfo.cols.src = src

    local stream_id = buf(20, 4)
    local stream_id_str = tostring(stream_id)
    subtree:add(ttrpc_len_field, buf(16, 4))
    subtree:add(ttrpc_stream_id_field, stream_id)

    local msg_type = tostring(buf(24, 1):uint())
    subtree:add(ttrpc_msg_type_field, msgTypeMap[msg_type])
    subtree:add(ttrpc_flags_field, buf(25, 1))

    local ttrpc_headerfield_data
    if buf_len > 26 then
        ttrpc_headerfield_data = buf(26, 1)
    else
        ttrpc_headerfield_data = buf(26)
    end
    -- print("ttrpc_headerfield_data", ttrpc_headerfield_data, type(ttrpc_headerfield_data))
    -- subtree:add(ttrpc_headerfield, ttrpc_headerfield_data)
    subtree:add(ttrpc_data_field, buf(26))

    -- 解析二进制数据
    local cmdPayloadStr = tostring(buf(16):tvb():bytes())

    local command = string.format("./containerdParser/ttrpc-parser -f %s", cmdPayloadStr)
    -- print(command)
    local output = executeCommand(command)
    -- print(output)

    -- 使用 dkjson.decode 解析 JSON 文本
    local parsed_data, pos, err = json.decode(output, 1, nil)
    -- printTable(parsed_data)

    -- 检查是否有错误
    if err then
        print("Json parse error:" .. err .. "output: " .. output)
        error("Json parse error:" .. err .. "output: " .. output)
        return
    end

    err = parsed_data.err
    if err ~= nil and err ~= "" then
        print("Go parse error::" .. err .. "output: " .. output)
        error("Go parse error:" .. err .. "output: " .. output)
        return
    end

    -- local task_id = printJson(parsed_data.task_id)
    -- local data_length = printJson(parsed_data.data_length)
    -- local stream_id = printJson(parsed_data.stream_id)
    -- local msg_type = printJson(parsed_data.msg_type)
    -- local msg_flags = printJson(parsed_data.msg_flags)
    local method = parsed_data.method
    local req = printJson(parsed_data.req)
    local resp = printJson(parsed_data.resp)
    local status = printJson(parsed_data.status)
    -- print("parsed_data", parsed_data.method,  err, status, req, resp)

    local method_name = "<unkonwn>"
    if method ~= nil and method ~= "" then
        method_name = method
    end
    subtree:add(ttrpc_method_field, method_name)

    local formattedString
    if msg_type == "1" then 
        subtree:add(ttrpc_req_field, req)
        formattedString = string.format(
            "%s, StreamId: %s, %s -> %s,\t %s Method: %9s, req: %s",
            formatTimestamp(pinfo.abs_ts), stream_id_str, src, dst, msg_type, method_name, req
        )
    elseif msg_type == "2" then 
        subtree:add(ttrpc_resp_status_field, status)
        subtree:add(ttrpc_resp_field, resp)
        if method_name == unkonwn_method then
            formattedString = string.format(
                "%s, StreamId: %s, %s -> %s,\t %s Method: %9s, payload: %s",
                formatTimestamp(pinfo.abs_ts), stream_id_str, src, dst, msg_type, method_name, cmdPayloadStr
            )
        else
            formattedString = string.format(
                "%s, StreamId: %s, %s -> %s,\t %s Method: %9s, resp: %s",
                formatTimestamp(pinfo.abs_ts), stream_id_str, src, dst, msg_type, method_name, resp
            )
        end
    elseif msg_type == "3" then 
        formattedString = string.format(
            "%s, StreamId: %s, %s -> %s,\t %s Method: %9s, stream: %s",
            formatTimestamp(pinfo.abs_ts), stream_id_str, src, dst, msg_type, method_name, ""
        )
    end
    print(formattedString)
    
end

local wtap_encap_table = DissectorTable.get("wtap_encap")
wtap_encap_table:add(wtap.USER0, dummy_proto)
