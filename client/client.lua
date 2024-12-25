local URL = "http://will-al.gl.at.ply.gg:17637"

local json = require("jsonl")


-- oc libs
local fs = require("filesystem")
local io = require("io")
local colors = require("colors")
local component = require("component")


-- Debug utils
local term = require "term"
local unicode = require "unicode"

local gpu = component.gpu
local function dump(o)
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

local function URLEncode(url)
    if url == nil then
        return
    end
    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w ])", char_to_hex)
    url = url:gsub(" ", "+")
    return url
end


--- @return string
--- @param url string
local function doRequest(url)
    local internet = require("internet")
    local handle = internet.request(url)
    local result = ""
    for chunk in handle do
        result = result .. chunk
    end
    return result
end

--- @return string
--- @param data string bytes
local function toHex(data)
    return (data:gsub('.', function(c)
        return string.format('%02X', string.byte(c))
    end))
end

local remoteFiles = {}

local function excludeMismatchMD5recursive(dir_path)
    local iterator = fs.list(dir_path)
    if not iterator then
        print("Error listing directory: " .. dir_path)
        return
    end

    for entry in iterator do
        local full_path = fs.concat(dir_path, entry)
        if fs.isDirectory(full_path) then
            excludeMismatchMD5recursive(full_path)
        else
            local no_slash_path = fs.canonical(full_path)
            full_path = "/" .. fs.canonical(full_path)

            -- print("Hash check in progress\n local hash is: ",
            --     localHash, ", remote is: ", remoteFiles[no_slash_path], ", match?: ", localHash ==
            --     remoteFiles[no_slash_path], ", filecontent = ", content, "endofdebugmsg")

            if remoteFiles[no_slash_path] ~= nil then
                local file = io.open(full_path, "r")
                if file == nil then
                    return
                end
                local content = file:read("*a")
                local localHash = toHex(component.data.md5(content))
                if localHash ~= remoteFiles[no_slash_path] then
                    -- print("Hash mismatch in file: ", no_slash_path,
                    --     ", local: " .. localHash .. ", remote: " .. remoteFiles[no_slash_path])
                    fs.remove(full_path)
                end
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
            findMissingRecursive(full_path)
        else
            local no_slash_path = full_path
            full_path = "/" .. fs.canonical(full_path)
            if remoteFilesToBeConsumed[no_slash_path] ~= nil then
                remoteFilesToBeConsumed[no_slash_path] = nil
            else
                table.insert(localFilesToBeRemoved, full_path)
            end
        end
    end
end

local function getPath(str)
    return str:match("(.*[/\\])")
end

local function fetchMissing(missingFiles)
    for path, hash in pairs(missingFiles) do
        if hash ~= nil then
            path = "/" .. path
            print("Now requesting: ", path)
            local dirpath = getPath(path)
            fs.makeDirectory(dirpath)
            local f = fs.open(path, "w")
            f:write(doRequest(URL .. "/fetchfile" .. path))
            f:close()
        end
    end
end

--- @param files table
local function remove(files)
    for i, path in pairs(files) do
        fs.remove(path)
        print("Removing: ", path)
    end
end

local color = {}

function color.red()
    gpu.setForeground(0xff1111)
end

function color.green()
    gpu.setForeground(0x11ff11)
end

function color.blue()
    gpu.setForeground(0x1111ff)
end

function color.clear()
    gpu.setForeground(0xffffff)
end

local function workFiles()
    fs.makeDirectory("./sync")
    local response = json.parse(doRequest(URL .. "/filelist"))
    for path, rHash in pairs(response) do
        remoteFiles[path] = rHash
    end
    excludeMismatchMD5recursive("./sync")


    remoteFilesToBeConsumed = remoteFiles
    localFilesToBeRemoved = {}
    findMissingRecursive("./sync")


    print("Fetching...")
    fetchMissing(remoteFilesToBeConsumed)
    print("Deleting stale...")
    remove(localFilesToBeRemoved)


    print("Operation finished, executing main.lua")
    os.sleep(0.2)
    term.clear()
    local iterator = fs.list("./sync")
    if iterator then
        package.path =
        "/lib/?.lua;/usr/lib/?.lua;/home/lib/?.lua;./?.lua;/lib/?/init.lua;/usr/lib/?/init.lua;/home/lib/?/init.lua;./?/init.lua;/?.lua"
        for entry in iterator do
            full_path = fs.concat("./sync", entry)
            if full_path == "sync/main.lua" then
                status, err = pcall(dofile, "/" .. full_path)
                color.blue()
                if status then
                    print("Excecution Finished")
                else
                    print("Error occurred during execution!")
                    io.write(err)
                    print("")
                end
                return
            end
        end
    end
    color.red()
    print("main.lua not found!!!")
    color.clear()
end

local function pressAnyToContinue()
    print("Press enter to continue...")
    local _ = io.read()
end

while true do
    term.clear()
    local status, res = pcall(doRequest, URL .. "/ping")
    if status then
        print("Bound to server:", URL)
    else
        print("Error while testing connection, err:", res)
        return
    end
    print("Press 'e' to fetch and execute program")
    local s = io.read()
    if s == "e" or s == "E" then
        workFiles()
        pressAnyToContinue()
        color.clear()
    end
end
