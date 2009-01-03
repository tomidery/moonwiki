---
-- HttpServer class

require("config")
require("htk")
require("Object")

HttpServer = class("HttpServer", Object)

---
-- constants
local httpErrors = {
    [100] = "Continue",
    [101] = "Switching Protocols",
    
    [200] = "OK",
    [201] = "Created",
    [202] = "Accepted",
    [203] = "Non-Authoritative Information",
    [204] = "No Content",
    [205] = "Reset Content",
    [206] = "Partial Content",
    
    [300] = "Multiple Choices",
    [301] = "Moved Permanently",
    [302] = "Found",
    [303] = "See Other",
    [304] = "Not Modified",
    [305] = "Use Proxy",
    [307] = "Temporary Redirect",
    
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [402] = "Payment Required",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [406] = "Not Acceptable",
    [407] = "Proxy Authentication Required",
    [408] = "Request Time-out",
    [409] = "Conflict",
    [410] = "Gone",
    [411] = "Length Required",
    [412] = "Precondition Failed",
    [413] = "Request Entity Too Large",
    [414] = "Request-URI Too Large",
    [415] = "Unsupported Media Type",
    [416] = "Requested Range Not Satisfiable",
    [417] = "Expectation Failed",
              
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [502] = "Bad Gateway", 
    [503] = "Service Unavailable",
    [504] = "Gateway Time-out",
    [505] = "HTTP Version not supported"
}
   
---
-- new                 
function HttpServer.new(class, ...)
    local newObject = HttpServer.super.new(class, {
        request = {
            header = "",     -- whole header (for debug)
            postData = "",   -- whole POST data (for debug)
            method = "",     -- HTTP method
            uri = "",        -- whole URI
            url = "",        -- URL
            protocol = "",   -- HTTP version
            options = {},    -- request options
            parameters = {}, -- parameters from URL
            form = {}        -- parameters from POST data
        },
        response = {
            status = 200,              -- status of response
            contentType = "text/html", -- content type of returned data
            location = nil,            -- new page location for redirection
            header = "",               -- HTTP header
            content = ""               -- response content
        },
        -- If given HTTP method is supported by server its field
        -- should be set to true. If not supported - set to false.
        httpMethods = { 
            OPTIONS = false,
            GET = true,
            HEAD = true, 
            POST = true,
            PUT = false,
            DELETE = false, 
            TRACE = false,
            CONNECT = false
        }
    }, unpack(arg))
    return newObject
end

-- HTTP request processing

function HttpServer.methods:handleRequest()
    if not self:parseHttpRequest() then
        self:prepareErrorResponse()
    else    
        local httpMethod = string.upper(self.request.method)
        local result = false
        if httpMethod == "GET" then
            result = self:handleGetRequest()
        elseif httpMethod == "POST" then
            result = self:handlePostRequest()
        elseif httpMethod == "HEAD" then
            result = self:handleHeadRequest()
        else
            assert(false)
        end
        if not result then
            self:prepareErrorResponse()        
        end
    end
    local responseData = self.response.header .. "\r\n" .. self.response.content
    return responseData    
end

---
-- Function reads and parses HTTP request header.
-- It uses [[readFromSocket]] registered C function
-- As a result it fills [[self.request]] table.
-- If an error occures [[self.response.status]] is set and
-- function returns false.
-- @return true if header was processed without errors,
-- false if there was an error.
function HttpServer.methods:parseHttpRequest() 
    local buffer = ""
    local headerSeparatorFound = false
    while not headerSeparatorFound do
        local readBytes, readCount = readFromSocket(512)
        if readCount == -1 then
            self.response.status = 500  -- socket reading error
            return false
        end 
        buffer = buffer .. readBytes
        -- check if whole header is read, if not reread data
        local beginPos, endPos, capture = string.find(buffer, "(\r\n\r\n)")
        if beginPos ~= nil then
            headerSeparatorFound = true
        end
    end
    string.gsub(buffer,"(.*\r\n\r\n)(.*)",function(header,data)
        self.request.header = header
        self.request.postData = data
    end)
    --print("REQUEST", self.request.header)
    string.gsub(self.request.header,"(%u+)%s+([^%s]+)%s+(HTTP/%d%.%d)%s+",function(method,uri,protocol)
        self.request.method = method
        self.request.uri = uri
        self.request.protocol = protocol        
    end)
    local isValidMethod = self.httpMethods[string.upper(self.request.method)]
    if isValidMethod == nil then
        self.response.status = 400 -- invalid method
        return false
    elseif isValidMethod == false then
        self.response.status = 501 -- method not supported     
        return false
    end    
    self.request.url = string.gsub(self.request.uri,"(%?.*)", function(parameters)
        string.gsub(parameters,"([^=?&;]+)=([^;&%s]*)", function(field, value)
	    self.request.parameters[string.lower(field)] = self:unescapeHttp(value)
        end)    
    end)
    string.gsub(self.request.header,"([%a-_]+)%s*:%s*([^\r\n]+)", function(field,value)
        self.request.options[string.lower(field)] = value
     end)
    -- check Content-Length option
    local contentLength = self.request.options["content-length"]
    if contentLength == nil then
        return true
    end
    toRead = contentLength-string.len(self.request.postData)
    if toRead ~= 0 then
        local readBytes, readCount = readFromSocket(toRead)
        if readCount == -1 then
            self.response.status = 500  -- socket reading error
            return false
        end    
        self.request.postData = self.request.postData .. readBytes
    end
    string.gsub(self.request.postData,"([^=?&;]+)=([^;&%s]*)", function(field, value)
        self.request.form[string.lower(field)] = self:unescapeHttp(value)
    end)
    return true
end

function HttpServer.methods:unescapeHttp(parameter)
    parameter = string.gsub(parameter, "%+", " ")
    parameter = string.gsub(parameter, "%%(%x%x)", function(hexString)
        return string.char(tonumber(hexString, 16));                
    end)
    return parameter
end

function HttpServer.methods:escapeHttp(parameter)
    parameter = string.gsub(parameter, " ", "%+")    
    parameter = string.gsub(parameter, "[^A-Za-z0-9]", function(character)
        return string.format("%%%02x", string.byte(character))
    end)
    return parameter
end


-- HTTP headers and error pages

function HttpServer.methods:createHttpHeader(status, contentType, length)
    local statusString = httpErrors[status]
    if statusString == nil then
        -- force internal error status
        status = 500
        statusString = httpErrors[500]; 
    end    
    local header = "HTTP/1.1 " .. status .. " " .. statusString .. "\r\n" ..
        "Server:MoonWiki " .. serverConfig.version .. "\n\r" ..
        "Content-Type:" .. contentType .."\r\n" ..
        "Content-Length:" .. length .. "\r\n"
    return header
end

function HttpServer.methods:getCSS()
    return nil
end

function HttpServer.methods:createHtmlHeader(title)
    local header = HTK.HEAD {HTK.TITLE {title},
--        '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso-8859-2">'        
        '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=windows-1250">',        
        self:getCSS()
    }
    return header
end



function HttpServer.methods:createHttpErrorPage(status)
    local statusString = httpErrors[status]
    assert(statusString ~= nil)
    local errorPage = HTK.HTML {self:createHtmlHeader(statusString),
        HTK.BODY {
            HTK.H1 { "Error&nbsp;" .. status },
            HTK.P {statusString}
        }
    }
    return errorPage    
end


--- 
-- Prepares error response - HTTP header with status and page content.
-- Function uses value of [[self.response.status]] as an error status.
-- If [[self.response.location]] is set then additional header line is generated
-- using value of this field - it makes redirection header.
-- Generated HTTP header and page content are inserted into [[self.response]] table.
function HttpServer.methods:prepareErrorResponse()
    local errorPage = self:createHttpErrorPage(self.response.status)
    local header = self:createHttpHeader(self.response.status, "text/html", string.len(errorPage))
    if self.response.location ~= nil then
        header = header .. "Location:" .. self.response.location .. "\r\n"
    end
    self.response.header =  header
    self.response.content = errorPage 
end


-- raw page handling

function HttpServer.methods:getFileSuffix(fileName)
    local beginPos, endPos, capture = string.find(fileName, "\.([%a%d]+)$")
    return capture
end

 
function HttpServer.methods:checkContentType(fileName)
    local suffix = self:getFileSuffix(fileName)
    if suffix == nil then
        return "application/unknown"
    end
    local contentType = contentTypes[suffix]
    if contentType == nil then
        return "application/unknown"
    end
    return contentType
end

function HttpServer.methods:processRawFile(fileName)
    local filePath = serverConfig.rootDir .. fileName
    local file = io.open(filePath, "rb")
    if file == nil then
        self.response.status = 404
        return nil
    end
    local size = file:seek("end")
    file:seek("set")
    local content = file:read(size)
    self.request.contentType = self:checkContentType(fileName)
    file:close()
    return content
end


function HttpServer.methods:redirectToPage(newPage)
    -- we have to redirect browser to specified page
    -- force error (by returning 'false') and set page title as redirection location 
    self.response.status = 303      -- see other
    self.response.location = newPage
    return false
end

-- HTTP methods handler

--- 
-- Function processes GET HTTP request.
function HttpServer.methods:handleGetRequest()    
    --print("HttpServer:get")
    page = self:processRawFile(self.request.url)
    if page == nil then
        return false
    end
    self.response.header = self:createHttpHeader(self.response.status, self.response.contentType, string.len(page))
    self.response.content = page
    return true
end


--- 
-- Function processes HEAD HTTP request.
function HttpServer.methods:handleHeadRequest()   
    local result = self:processGetRequest()
    -- remove content, only header is returned
    self.response.content = ""
    return result
end



        
