---
-- WikiEngine class

require("htk")
require("WikiFormatter")
require("PrintableFormatter")
require("WikiStore")
require("HttpServer")
require("Object")

WikiEngine = class("WikiEngine", HttpServer)

---
-- Creates new [[WikiEngine]].  
function WikiEngine.new(class,...)
    local newStore = WikiStore:new()
    local newObject =  WikiEngine.super.new(class, {
        store = newStore,                        -- set store used by this engine
        formatter = WikiFormatter:new(newStore)  -- set formatter used by this engine        
    }, unpack(arg))
    newObject.formatter:setWikiEngine(newObject) -- update reference to WikiEngine in WikiFormatter
    return newObject
end

-- sets formatter - normal or printable
function WikiEngine.methods:setFormatter()
    local viewType = self.request.parameters["view"]
    -- create PrintableFormatter if "printable" parameter is set
    if viewType == "printable" then
        if self.formatter:instanceof(PrintableFormatter) then
            return
        end
        self.formatter = PrintableFormatter:new(self.store)
    else
        if self.formatter:instanceof(WikiFormatter) then
            return
        end
        self.formatter = WikiFormatter:new(self.store)
    end
    self.formatter:setWikiEngine(self) -- update reference to WikiEngine in formatter    
end


function WikiEngine.methods:processRequest()
    self:setFormatter()
    local url = self.request.url
    if url == "/" then
	-- StartPage is the default if nothing else was specified
        url = "StartPage"
    else 
        url = string.sub(url, 2, -1)
    end
    -- check title
    if not self.formatter:isValidTitle(url) then
        return nil
    end
    local page = nil
    -- check special page
    if self:isSpecialPage(url) then
        page = self:processSpecialPage(url)
    elseif self.store:topicExists(url) then
        -- process wiki page            
        local content =  self.store:loadPage(url)
        page = self:createHtmlPage(url, self.formatter:wikiPageTemplate(url, content))          
    else 
        -- page not found
        page = self:createHtmlPage("Not found " .. url, self.formatter:notFoundPageTemplate(url)) 
    end
    return page
end    


function WikiEngine.methods:createHtmlPage(title, body)
    return HTK.HTML {
            self:createHtmlHeader(title),
            body 
        }
end

function WikiEngine.methods:isValidPage(title)
    if title == nil then
        return false
    end
    local result = self.formatter:isValidTitle(title) and self.store:topicExists(title)
    return result
end

function WikiEngine.methods:getNameWithoutSuffix(fileName)
    local beginPos, endPos, capture = string.find(fileName, "(%w+)\.%w+$")
    return capture
end


function WikiEngine.methods:getCSS()
    return [[
<style type="text/css" media="all">
  /* Default TWiki layout 
  @import url("layout.css"); */
  /* Default TWiki style */
  @import url("style.css");  
</style>
]]
end


function WikiEngine.methods:createSpecialEditPage(title)
    -- check if parameters "page" is defined, if not return error page
    local pageName = self.request.parameters["page"]
    if pageName == nil then
        self.response.status = 400
        return nil
    end
    if not self.formatter:isValidTitle(pageName) then
        self.response.status = 400
        return nil
    end
    local actions = HTK.P {
        HTK.INPUT { type="submit", name="action", value=" Save " }, "&nbsp;",
        HTK.INPUT { type="submit", name="action", value=" Checkpoint " }, "&nbsp;",
        HTK.INPUT { type="reset", value=" Reset " }, "&nbsp;",
        HTK.INPUT { type="submit", name="action", value=" Cancel Editing " }, "&nbsp;",        
    }
    local content = self.store:loadPage(pageName)
    -- new page is created
    if content == nil then
        content = ""
    end
    -- handle special characters
    content = string.gsub(content, "&", "&amp;")
    content = string.gsub(content, "<", "&lt;")
    content = string.gsub(content, ">", "&gt;")
    -- content = string.gsub(content, "\t", "   ")
    local formatted =
        HTK.HTML {self:createHtmlHeader("Edit " .. pageName),            
            HTK.BODY {
                HTK.DIV {
                    class = "twikiEditPage",
                    HTK.FORM {
                        method = "POST",
                        action = "/",
                        self.formatter:pageHeaderTable(pageName, actions),
                        HTK.BLOCKQUOTE {
                            HTK.TEXTAREA {
                                name="text", wrap="virtual", rows="30", 
                                content
                            }
                        },
                        HTK.INPUT { type="hidden", name="page", value=pageName },
                    }
                }
            } 
        }
    return formatted
end

-- displays index page with names of all pages
function WikiEngine.methods:createSpecialIndexPage(title)
    local files = {findFiles(serverConfig.rootDir .. "/*" .. serverConfig.suffix)}    
    local pages = {}
    for i, file in ipairs(files) do 
        local filedate, name = next(file)
        local pageTitle = self:getNameWithoutSuffix(name)
        if self.formatter:isValidTitle(pageTitle) then
            table.insert(pages, pageTitle)
        end
    end    
    -- sort alphabeticaly by page name
    table.sort(pages)
    return self:createHtmlPage("Index page", self.formatter:specialIndexPageTemplate(pages))
end

-- displays index page with names of all pages which was modified 
function WikiEngine.methods:createSpecialRecentChanges(title)
    local files = {findFiles(serverConfig.rootDir .. "/*" .. serverConfig.suffix)}    
    -- sort by file date in reverse order    
    table.sort(files, function(tab1, tab2) 
        date1, name1 = next(tab1)
        date2, name2 = next(tab2)
        return date1>date2
    end)   
    
    local pages = {}
    for i, file in ipairs(files) do 
        local filedate, name = next(file)
        local pageTitle = self:getNameWithoutSuffix(name)
        if self.formatter:isValidTitle(pageTitle) then
            table.insert(pages, {filedate,pageTitle})
        end
        if i == serverConfig.recentChangesListSize then
            break
        end
    end    
    return self:createHtmlPage("Recent changes", self.formatter:specialRecentChangesTemplate(pages))    
end

function WikiEngine.methods:createSpecialSearchPage(title)    
    local search = self.request.parameters["search"]
    print("Search text", search)
    if search == nil then
        search = ""
    end
    local table =    
        HTK.TABLE {
            cellspacing = 2,
            cellpadding = 0,
            border = 0,
            HTK.TR {
                HTK.TD { "Find text:" },
                HTK.TD {
                    HTK.INPUT { type="text", name="search", size="40", value=search }, "&nbsp;",        
                    HTK.INPUT { type="submit", name="action", value=" Search " }
                }
            },
            HTK.TR {
                HTK.TD { "Search in:" },
                HTK.TD { HTK.INPUT { type="radio", class="twikiRadioButton", name="scope", value="text", checked="checked"}, "Text body" }
            }, 
            HTK.TR {
                HTK.TD {},
                HTK.TD { HTK.INPUT { type="radio", class="twikiRadioButton", name="scope", value="topictitle" }, "Topic title" }
            }, 
            HTK.TR {
                HTK.TD {},
                HTK.TD { HTK.INPUT { type="radio", class="twikiRadioButton", name="scope", value="both" }, "Both body and title" }
            }
        }    
    local results = ""
    local formatted =
        HTK.HTML {self:createHtmlHeader("Search"),            
            HTK.BODY {
                self.formatter:specialPageHeader("Search"),
                HTK.FORM {
                    method = "POST",
                    action = "SearchPage",
                    table
                } ,
                HTK.HR {},
                results                
            } 
        }        
    return formatted
end


function WikiEngine.methods:createSpecialReverseLink(title)
    local pageName = self.request.parameters["page"]
    if not self:isValidPage(pageName) then
        self.response.status = 404
        return nil
    end
    files = {findFiles(serverConfig.rootDir .. "/*" .. serverConfig.suffix)} 
    local pages = {}
    local pattern = "[^%w]" .. pageName .. "[^%w]"
    for i, file in ipairs(files) do 
        local filedate, name = next(file)
        local pageTitle = self:getNameWithoutSuffix(name)
        local content = self.store:loadPage(pageTitle)
        if content ~= nil then
            local beginPos, endPos = string.find(content, pattern)
            if beginPos ~= nil then
                table.insert(pages, pageTitle)
            end        
        end        
    end
     -- sort alphabeticaly by page name
    table.sort(pages)
    if table.getn(pages) == 0 then
        pages = nil
    end   
    return self:createHtmlPage("Reverse links for " .. pageName, self.formatter:specialReverseLinkTemplate(pageName, pages))       
end


function WikiEngine.methods:isSpecialPage(title)
    local specialPageCreator = "createSpecial" .. title
    if self[specialPageCreator] == nil then
        return false
    else 
        return true
    end
end


function WikiEngine.methods:processSpecialPage(title)
    local specialPageCreator = "createSpecial" .. title
    local creator = self[specialPageCreator]
    assert (creator ~= nil)
    -- call page creation method
    local page = creator(self, title)
    if page == nil then
        
    end
    return page
end

-- HTTP methods handler

--- 
-- Function processes GET HTTP request.
function WikiEngine.methods:handleGetRequest()  
    --print("WikiEngine:get")  
    --print("store", self.store, self.formatter.store)
    -- check if it is wiki page
    local page = self:processRequest()
    if page == nil then
        -- not wiki page so try to find file and check its content type
        page = self:processRawFile(self.request.url)
    end
    if page == nil then
        return false
    end
    self.response.header = self:createHttpHeader(self.response.status, self.response.contentType, string.len(page))
    self.response.content = page
    return true
end

--- 
-- Function processes POST HTTP request.
function WikiEngine.methods:handlePostRequest()
    local action = self.request.form["action"]
    action = string.gsub(action, " ", "")
    local postActionHandler = self["postHandler" .. action]
    if (action == nil) or (postActionHandler == nil) then
        self.response.status = 400    -- bad request 
        return false
    end
    return postActionHandler(self)
end

function WikiEngine.methods:doSaveAfterEditing()
    local content = self.request.form["text"]
    local title = self.request.form["page"]
    if (content == nil) or (title == nil) then
        self.response.status = 400  -- bad request
        return false 
    end
    if not self.store:savePage(title, content) then
        self.response.status = 500  -- internal error
        return false 
    end 
    return true
end


-- POST method actions' handlers
function WikiEngine.methods:postHandlerSave()
    if not self:doSaveAfterEditing() then
        return false
    end
    -- we have to redirect browser to real page
    return self:redirectToPage("/" .. self.request.form["page"])
end


function WikiEngine.methods:postHandlerCheckpoint()
    if not self:doSaveAfterEditing() then
        return false
    end
    -- we have to redirect browser to edit page
    return self:redirectToPage("EditPage?page=" .. self.request.form["page"])
end


function WikiEngine.methods:postHandlerCancelEditing()
    -- we have to redirect browser to unchanged page
    return self:redirectToPage("/" .. self.request.form["page"])
end

function WikiEngine.methods:postHandlerSearch()
    local search = self.request.form["search"]
    print("Search POST text", search)
    if search == nil then
        search = ""
    end
    search = self:escapeHttp(search)
    print("Escaped POST text", search)    
    -- we have to redirect browser to search page
    return self:redirectToPage("SearchPage?search=" .. search)
end