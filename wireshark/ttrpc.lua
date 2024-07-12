
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
        return nil
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
    [1] = "Request(0x01)",
    [2] = "Response(0x02)",
    [3] = "Stream(0x03)"
}

-- 配置文件路径和消息类型
-- local messageType = "containerd.task.v2.Task"
local messageType = ""

local dummy_proto = Proto("dummy", "Dummy Protocol")

local dst_field = ProtoField.uint64("dummy.dst", "Destination")
local src_field = ProtoField.uint64("dummy.src", "Source")
local ttrpc_len_field = ProtoField.bytes("dummy.ttrpc_len", "TTRPC Data Length")
local ttrpc_stream_id_field = ProtoField.bytes("dummy.stream_id", "TTRPC Stream ID")
local ttrpc_msg_type_field = ProtoField.string("dummy.msg_type", "TTRPC Msg Type")
local ttrpc_flags_field = ProtoField.bytes("dummy.flags", "TTRPC Flags")
local ttrpc_headerfield = ProtoField.bytes("dummy.header", "TTRPC Header")
local ttrpc_data_field = ProtoField.bytes("dummy.data", "TTRPC Data")
local ttrpc_method_field = ProtoField.string("dummy.method", "TTRPC Method")
local ttrpc_req_field = ProtoField.string("dummy.req", "TTRPC Req")
local ttrpc_resp_field = ProtoField.string("dummy.resp", "TTRPC Resp")

dummy_proto.fields = { dst_field, src_field, 
    ttrpc_len_field, ttrpc_stream_id_field, ttrpc_msg_type_field, ttrpc_flags_field, ttrpc_headerfield,
    ttrpc_data_field, ttrpc_method_field, ttrpc_req_field, ttrpc_resp_field}

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
    -- pinfo.cols.data = tostring(buf(16))

    local stream_id = buf(20, 4)
    local stream_id_str = tostring(stream_id)
    subtree:add(ttrpc_len_field, buf(16, 4))
    subtree:add(ttrpc_stream_id_field, stream_id)

    local msg_type_int = buf(24, 1):uint()
    subtree:add(ttrpc_msg_type_field, msgTypeMap[msg_type_int])
    subtree:add(ttrpc_flags_field, buf(25, 1))

    local ttrpc_headerfield_data
    if buf_len > 26 then
        ttrpc_headerfield_data = buf(26, 1)
    else
        ttrpc_headerfield_data = buf(26)
    end
    -- print("ttrpc_headerfield_data", ttrpc_headerfield_data, type(ttrpc_headerfield_data))
    subtree:add(ttrpc_headerfield, ttrpc_headerfield_data)
    subtree:add(ttrpc_data_field, buf(26))

    -- 读取二进制数据
    -- local binaryData = buf(26)
    -- print("buf", buf(26))
    -- 将userdata对象打包成字节串
    -- local packedBytes = tostring(buf(26))
    local packedBytes = buf(26):tvb():bytes():raw()
    -- 打印解包后的字符串
    -- print("pkg", packedBytes)

    -- local buffer = ByteArray.new(buf(26):tvb():bytes())

    -- 解析二进制数据
    local parsedData
    if msg_type_int == 1 then 
        messageType = "ttrpc.Request"
        parsedData = parseBinaryData(messageType, packedBytes)
    elseif msg_type_int == 2 then 
        messageType = "ttrpc.Response"
        parsedData = parseBinaryData(messageType, packedBytes)
    else
        return
    end

    local stream_id_map = loadMapFromFile()
    local method_name
    local req
    local resp
    -- showMap(stream_id_map)
    if parsedData.method ~= nil and parsedData.method ~= "" then
        -- print(parsedData.method)
        method_name = parsedData.method
        stream_id_map[stream_id_str] = method_name
        -- print("req", stream_id_str, method_name)

        -- print("stream_id_map", stream_id_map)
        subtree:add(ttrpc_method_field, method_name)
        -- -- messageType = parsedData.service
        -- print(parsedData.service)
        -- messageType = "task." ..  parsedData.method .. "Request"
        messageType = req_map[parsedData.method]
        if messageType ~= nil then
            messageType = "task." .. messageType
            local parsedData = parseBinaryData(messageType, parsedData.payload)
            -- print(messageType, "===>")
            -- printTable(parsedData)
            req = printJson(parsedData)
            subtree:add(ttrpc_req_field, req)
        end
    else
        -- print(stream_id_str, type(stream_id_str))
        method_name = stream_id_map[stream_id_str]
        -- print("resp", stream_id_str, method_name)
        if method_name ~= nil and method_name ~= "" then
            subtree:add(ttrpc_method_field, method_name)
            messageType = resp_map[method_name]
            if messageType ~= nil then
                messageType = "task." .. messageType
                local parsedData = parseBinaryData(messageType, parsedData.payload)
                -- print(messageType, "===>")
                -- printTable(parsedData)
                resp = printJson(parsedData)
                -- print(resp)
                subtree:add(ttrpc_resp_field, resp)
            end
        end
    end
    updateMapToFile(stream_id_map)


    -- 使用命名占位符
    local formattedString = string.format(
        "%s, StreamId: %s, %s -> %s,\t Method: %6s, req: %s, resp: %s, stream: %s",
        formatTimestamp(pinfo.abs_ts), stream_id_str, src, dst, method_name, req, resp, ""
    )
    print(formattedString)

end


-- print(package.path)

-- package.path = package.path .. ";/opt/homebrew//Cellar/protobuf/27.1/include/?.proto"
-- package.path = package.path .. ";/opt/homebrew//Cellar/protobuf/27.1/include/google/protobuf/?.proto"
-- package.cpath = package.cpath .. ";/opt/homebrew//Cellar/protobuf/27.1/include/?.proto"
-- package.cpath = package.cpath .. ";/opt/homebrew//Cellar/protobuf/27.1/include/google/protobuf/?.proto"

-- protoc:addpath("/opt/homebrew//Cellar/protobuf/27.1/include/")
-- protoc:addpath("/opt/homebrew//Cellar/protobuf/27.1/include/google/protobuf")

-- 加载 proto 文件
loadProto("/Users/admin/workspace/code/github/sockdump/wireshark/request.proto")
loadProto("/Users/admin/workspace/code/github/sockdump/containerd/runtime/v2/task/shim.proto")

local wtap_encap_table = DissectorTable.get("wtap_encap")
wtap_encap_table:add(wtap.USER0, dummy_proto)
