local json = require("jsonl")


-- oc libs
local fs = require("filesystem")
local io = require("io")
local component = require("component")


-- Debug utils
local term = require "term"
local unicode = require "unicode"

local gpu = component.gpu
function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local char_to_hex = function(c)
    return string.format("%%%02X", string.byte(c))
end

local function urlencode(url)
    if url == nil then
        return
    end
    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w ])", char_to_hex)
    url = url:gsub(" ", "+")
    return url
end

local hex_to_char = function(x)
    return string.char(tonumber(x, 16))
end

local urldecode = function(url)
    if url == nil then
        return
    end
    url = url:gsub("+", " ")
    url = url:gsub("%%(%x%x)", hex_to_char)
    return url
end



local URL = "http://will-al.gl.at.ply.gg:17637"
--- @return string
--- @param url string
local function doRequest(url)
    -- print("Doing request on: " .. url)
    local internet = require("internet")

    local handle = internet.request(url)
    local result = ""

    for chunk in handle do
        result = result .. chunk
    end
    -- print(result)

    return result
end

function toHex(data)
    return (data:gsub('.', function(c)
        return string.format('%02X', string.byte(c))
    end))
end

local remoteFiles = {}

-- --- @param path string
-- function fetchAndWriteFile(path)
--     print("Requesting: ", path)
--     fileContent = doRequest(URL .. "/fetchfile" .. path)
--     print(fileContent)
--     remoteFiles[path] = nil
-- end


function replaceLineBreak(input_str)
    -- Decode %0D%0A into \\r\\n (CRLF)
    input_str = input_str:gsub("%%0D%%0A", "\n")

    -- Decode %0D into \\r (CR)
    input_str = input_str:gsub("%%0D", "\n")

    -- Decode %0A into \\n (LF)
    input_str = input_str:gsub("%%0A", "\n")

    return input_str
end

local function excludeMismatchMD5recursive(dir_path)
    local iterator = fs.list(dir_path)
    if not iterator then
        -- print("Error listing directory: " .. dir_path)
        return
    end

    for entry in iterator do
        local full_path = fs.concat(dir_path, entry)
        if fs.isDirectory(full_path) then
            excludeMismatchMD5recursive(full_path) -- Recursive call for directories
        else
            no_slash_path = fs.canonical(full_path)
            full_path = "/" .. fs.canonical(full_path)
            content = ""
            -- for line in io.open(full_path) do
            --     content = content .. line
            -- end
            local file = io.open(full_path, "r")
            local content = file:read("*a")
            local localHash = toHex(component.data.md5(content))
            local localHashTrailingEnter = toHex(component.data.md5(content .. "\r")) -- THIS exsists because CRLF is garbage
            -- print("Hash check in progress\n local hash is: ",
            --     localHash, ", remote is: ", remoteFiles[no_slash_path], ", match?: ", localHash ==
            --     remoteFiles[no_slash_path], ", filecontent = ", content, "endofdebugmsg")

            if remoteFiles[no_slash_path] ~= nil then
                if localHash ~= remoteFiles[no_slash_path] and localHashTrailingEnter ~= remoteFiles[no_slash_path] then
                    print("Hash mismatch in file: ", no_slash_path,
                        ", local: " .. localHash .. ", remote: " .. remoteFiles[no_slash_path])
                    fs.remove(full_path)
                end
            end
            if full_path == "/sync/lua.lua" then
                print("start", (urlencode(content)), "<=>",
                    (urlencode((doRequest(URL .. "/fetchfile/sync/lua.lua")))), "end")
            end
        end
    end
end

local remoteFilesToBeConsumed
local localFilesToBeRemoved = {}


local function findMissingRecursive(dir_path)
    local iterator = fs.list(dir_path)
    if not iterator then
        -- print("Error listing directory: " .. dir_path)
        return
    end

    for entry in iterator do
        local full_path = fs.concat(dir_path, entry)
        if fs.isDirectory(full_path) then
            findMissingRecursive(full_path) -- Recursive call for directories
        else
            local no_slash_path = full_path
            full_path = "/" .. fs.canonical(full_path)
            if remoteFilesToBeConsumed[no_slash_path] ~= nil then
                print("File missing: " .. no_slash_path)
                remoteFilesToBeConsumed[no_slash_path] = nil
            else
                localFilesToBeRemoved[no_slash_path] = 1
            end
        end
    end
end

function getPath(str)
    return str:match("(.*[/\\])")
end

local function fetchMissing(missingFiles)
    for path, hash in pairs(missingFiles) do
        print("Checking: ", path, ", hash: ", hash)
        if hash ~= nil then
            path = "/" .. path
            print("Now requesting: ", path, "with hash: ", hash)
            local dirpath = getPath(path)
            -- print("Making dir ", dirpath)
            fs.makeDirectory(dirpath)
            local f = fs.open(path, "w")
            f:write(doRequest(URL .. "/fetchfile" .. path))
            f:close()
        end
    end
end


--Main loop
while true do
    fs.makeDirectory("./sync")
    local response = json.parse(doRequest(URL .. "/filelist"))
    for path, rHash in pairs(response) do
        remoteFiles[path] = rHash
    end
    excludeMismatchMD5recursive("./sync")


    remoteFilesToBeConsumed = remoteFiles
    print("Before consume:")
    print(dump(remoteFilesToBeConsumed))
    findMissingRecursive("./sync")

    print("Housekeeping Done.")
    print("After consume:")
    print(dump(remoteFilesToBeConsumed))
    print("Files to be deleted")
    print(dump(localFilesToBeRemoved))

    print("Fetching...")
    fetchMissing(remoteFilesToBeConsumed)

    -- TODO: implement delete, fetch


    print("--- Next loop ---")
    os.sleep(5)
end
