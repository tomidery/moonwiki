---
-- MoonWiki HTTP request handling

-- whole lua code is located in 'script' directory
LUA_PATH="script/?.lua"

require("config")
require("WikiEngine")
require("WikiExporter")

        
-- Global functions accessed from C code.
        
--- 
-- Processes HTTP request.
-- Function is accessible from C code.
-- @return response content and length.
function processRequest()
    local server = WikiEngine:new()   
    local response = server:handleRequest()
    print("RESPONSE", response)
    return response, string.len(response)         
end



local function printUsage()
    print ([[
usage:
    MoonWiki.exe [-p <port>] [-l <logfile>] [-c]    
    MoonWiki.exe -e <exportdir> [-r]
parameters:
    -p <port>      - port number (0 - 65535) for HTTP server;
    -l <logfile>   - log file name (defaults to stdout);
    -c             - clear log file before using it.
    -e <exportdir> - export all pages to static HTML files
    -r             - create reverse link pages
    Those and other options could be specified in "config.lua" file.
]])
    return false
end


---
-- Checks command line arguments.
-- Function is accessible from C code. 
-- @param ... list of command line arguments passed to program.
-- @return true if arguments were valid, false if there was any error.
function parseCommandLineArgs(...)
    local index = 1;
    local argument = arg[1]
    repeat
        if argument == "-e" then
            index = index + 1
            if arg[index] == nil then
                return printUsage()
            end
            serverConfig.exportDir = arg[index]
        elseif argument == "-r" then
            serverConfig.exportReverseLink = true
        elseif argument == "-c" then
            serverConfig.clearLog = true
        elseif argument == "-l" then
            index = index + 1
            if arg[index] == nil then
                return printUsage()
            end
            serverConfig.logFile = arg[index]        
        elseif argument == "-p" then
            index = index + 1
            if arg[index] == nil then
                return printUsage()
            end
            local port = tonumber(arg[index])
            if (port < 0) or (port > 65535) then
                return printUsage()
            end
            serverConfig.port = tonumber(port)
         else
            return printUsage()
        end
        index = index + 1
        argument = arg[index]
    until argument == nil
    return true
end
        
--- 
-- Return current server config.
-- Function is accessible from C code. 
-- @return port, logFile and clearLog flag.
function getServerConfig()
    return serverConfig.exportDir, serverConfig.port, serverConfig.clearLog, serverConfig.logFile
end


---
-- Export all pages to serverConfig.exportDir as HTML files
function doExport()
    local exporter = WikiExporter:new()   
    exporter:setFormatter()
    exporter:exportAllPages(serverConfig.exportDir)
    exporter:exportSpecialPages(serverConfig.exportDir)
    exporter:copyAdditionalFiles(serverConfig.exportDir)    
end