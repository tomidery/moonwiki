---
-- WikiFormatter class
-- Responsible for processing wiki pages. It supports TWiki like syntax.
-- It also defines 'templates' for wiki page headers.
-- This class is used by [[WikiEngine]]. It calls methods of [[WikiEngine]]
-- class to check if particular page exists or is special page.
-- [[WikiEngine]] instance is defined in [[new]] method.

require("htk")
require("StringBuffer")
require("Object")

WikiFormatter = class("WikiFormatter", Object)

---
-- Constants used in regular expressions and for page 'templates'.
wiki = {
    transToken = "~$~",
    wikiWordPattern = "(%u+%l+%u+[%a%d]*)",
    menuSeparator = "&nbsp;|&nbsp;",
    menuStart = "&nbsp;(&nbsp;",
    menuEnd = "&nbsp;)&nbsp;",
    menuColor = "#AAAAFF"
}
    
---
function WikiFormatter.new(class, store)
    --print("store", store)
    local newObject = WikiFormatter.super.new(class, {
        insideTable = false,
        insidePre = false,
        insideNoAutoLink = false,
        isList = false,
        listTypes = {},
        listElements = {},
        store = store ,
        engine = nil,  -- reference to WikiEngine
        result = {},        
    })
    return newObject
end

function WikiFormatter.methods:setWikiEngine(engine)
    self.engine = engine    
end


---
-- page templates
function WikiFormatter.methods:pageHeaderTemplate(title, additions)
    local header =
        HTK.TABLE {
            width = "100%",
            cellspacing = 0,
            cellpadding = 0,
            border = 0,
            HTK.TR {
                HTK.TD { 
                    rowspan = 2,
                    align = "center",
                    valign = "bottom",
                    width = "0%", 
                    self:existentPageLink("StartPage", 
                        HTK.IMG { 
                            border = 0,
                            src = serverConfig.logoFile
                        }
                    )
                },
                HTK.TD { 
                    rowspan = 2,
                    width = "0%",
                    "&nbsp;"
                },
                HTK.TD { 
                    width = "100%",
                    valign = "center",
                    HTK.H1 { "&nbsp;" ..title }    
                }
            },            
            HTK.TR { 
--                bgcolor = wiki.menuColor,
                HTK.TD { additions }
            }    
        } .. HTK.HR {}
    return header   
end


function WikiFormatter.methods:pageHeaderTable(title, actions, isSpecial)
    if isSpecial then
        return self:pageHeaderTemplate(title, actions)
    else
        return self:pageHeaderTemplate(self:reversePageLink(title), actions)
    end
end

---
-- template for regular wiki page
function WikiFormatter.methods:wikiPageTemplate(title, content)
    return HTK.BODY {
                self:standardPageHeader(title),
                self:formatWikiPage(content)
            } 
end


---
-- template for regular not found wiki page
function WikiFormatter.methods:notFoundPageTemplate(title)
    return HTK.BODY {
                self:specialPageHeader(title),
                HTK.P {
                    "The specifed page was not found.", HTK.BR {},
                    "Try to find it using:&nbsp;" , self:existentPageLink("SearchPage", "Search") , 
                    "&nbsp;or&nbsp;", self:existentPageLink("IndexPage", "Index page"), ".", HTK.BR {},
                    "You can also create new page:&nbsp;" , self:existentPageLink("EditPage?page=" .. title, title), "."
                } 
            } 
end


---
-- template for special page: IndexPage
function WikiFormatter.methods:specialIndexPageTemplate(pages)
    local list = ""
    for i, pageTitle in ipairs(pages) do
        list = list .. HTK.LI { self:internalLink(pageTitle, nil, pageTitle) } .. "\n"
    end 
    return HTK.BODY {
        self:specialPageHeader("Index page") ,    
        HTK.P {"The following is a complete list of pages on this server:"},
        HTK.UL {list}
    } 
end

            
---
-- template for special page: RecentChanges
function WikiFormatter.methods:specialRecentChangesTemplate(pages)
    local list = ""
    for i, page in ipairs(pages) do
        local filedate = page[1]
        local pageTitle = page[2]
        list = list .. HTK.LI { HTK.B {filedate}, " - ", self:internalLink(pageTitle, nil, pageTitle) } .. "\n"
    end 
    return HTK.BODY {
        self:specialPageHeader("Recent changes") ,    
        HTK.P {"The following is a list of recently changed pages on this server:"},
        HTK.UL {list}
    } 
end


---
-- template for special page: ReverseLink
function WikiFormatter.methods:specialReverseLinkTemplate(pageName, pages)
    if pages ~= nil then
        message = "The following is a complete list of pages with links to " .. self:internalLink(pageName, nil, pageName) .. " page:"
        list = ""
        for i, pageTitle in ipairs(pages) do
            list = list .. HTK.LI { self:internalLink(pageTitle, nil, pageTitle) } .. "\n"                            
        end 
    else
        message = "There are no pages with links to " .. self:internalLink(pageName, nil, pageName) .. " page."     
        list = nil
    end
    return HTK.BODY {
        self:specialPageHeader("Reverse links for " .. pageName) ,    
        HTK.P {message},
        HTK.UL {list}
    } 
end

---
-- functions for creating page headers
function WikiFormatter.methods:specialPageHeader(title)
    local actions = HTK.P {
        wiki.menuStart,        
        self:existentPageLink("SearchPage", "Search"), wiki.menuSeparator,
        self:existentPageLink("IndexPage", "Index page"), wiki.menuSeparator,
        self:existentPageLink("RecentChanges", "Recent changes"),
        wiki.menuEnd
    }
    return self:pageHeaderTable(title, actions, true)   
end

function WikiFormatter.methods:standardPageHeader(title)
    local actions = HTK.P { 
        wiki.menuStart,
        self:existentPageLink("EditPage?page=" .. title, "Edit"), wiki.menuSeparator,
        self:existentPageLink(title .. "?view=printable" , "Printable"), wiki.menuSeparator,
        self:existentPageLink("SearchPage", "Search"), wiki.menuSeparator,
        self:existentPageLink("IndexPage", "Index page"), wiki.menuSeparator,
        self:existentPageLink("RecentChanges", "Recent changes"),
        wiki.menuEnd
    }
    return self:pageHeaderTable(title, actions, false)    
end

---
-- function for creating back link
function WikiFormatter.methods:reversePageLink(theTopic)
    return HTK.A { href = "ReverseLink?page=" .. theTopic, theTopic }
end

---
-- function for creating regular link to other wiki page
function WikiFormatter.methods:existentPageLink(theTopic, theText)
    return HTK.A {class="twikiLink", href = theTopic, theText}
end

---
-- function for creating link to non existend wiki page
function WikiFormatter.methods:nonExistentPageLink(theTopic, theText)
    return HTK.SPAN { class="twikiNewLink", style = "background : #FFFFCE;", 
        HTK.FONT { color = "#0000FF", theText }, 
        HTK.A {href = "EditPage?page=" .. theTopic, HTK.SUP {"?"} }
    }
end


function WikiFormatter.methods:processTableLine(line)
    -- check if this is table definition
    local beginPos, endPos, capture = string.find(line, "^%s*(|.*|)%s*$")
    if capture == nil then
        -- check if table needs to be closed
        if self.insideTable then
            self.insideTable = false
            self.result:addString("</TABLE>\n")
        end
        return line  -- return line for further processing
    else
        line = capture    
    end
    -- process table
    local result = ""
    if not self.insideTable then
        result = '<TABLE border="1">\n'
        self.insideTable = true
    end
    local row = ""
    for cell, span in string.gfind(line, "([^|]+)(|+)") do
        local colSpan = string.len(span)
        local beginPos, endPos, capture = string.find(cell, "^%s*%*(.*)%*%s*$")
        local cellContent = ""
        if beginPos ~= nil then
            if colSpan == 1 then
                cellContent = HTK.TH {capture}
            else 
                cellContent = HTK.TH {colspan = colSpan, capture}
            end
        else
            if colSpan == 1 then
                cellContent = HTK.TD {cell}
            else 
                cellContent = HTK.TD {colspan = colSpan, cell}
            end
        end            
        row = row .. cellContent
    end    
    result = result .. HTK.TR {row}
    return result
end         


--- Render bulleted and numbered lists, including nesting.
-- Called from several places.  Accumulates listTypes and istElements
-- to track nested lists.
function WikiFormatter.methods:emitList(theType, theElement, theDepth, theOlType)
    local result = StringBuffer:new()
    self.isList = true

    -- ordered list type
    if theOlType == nil then
        theOlType = ""
    else
        theOlType = string.gsub (theOlType, "^(.).*" ,"$1")
        if theOlType == "1" then
            theOlType = "" 
        end
    end

    -- print("LIST", table.getn(self.listElements), self.listElements[table.getn(self.listElements)],
    --    table.getn(self.listTypes), self.listTypes[table.getn(self.listTypes)])
    if table.getn(self.listTypes) < theDepth then
        local firstTime = true
        while table.getn(self.listTypes) < theDepth do
            table.insert(self.listTypes, theType)
            table.insert(self.listElements, theElement)            
            if not firstTime then
                result:addString("<" .. theElement .. ">\n")
            end
            if theOlType ~= "" then
                result:addString("<" .. theType .. " type=\"" .. theOlType .. "\">\n")
            else 
                result:addString("<" .. theType .. ">\n")
            end
            firstTime = false;
        end
    elseif table.getn(self.listTypes) > theDepth then
        while table.getn(self.listTypes) > theDepth do
            local element = table.remove(self.listElements)
            result:addString("</" .. element .. ">\n")
            local type = table.remove(self.listTypes)
            result:addString("</" .. type .. ">\n")
        end
        if table.getn(self.listElements) > 0 then
            result:addString("</" .. self.listElements[table.getn(self.listElements)] .. ">\n")
        end
    elseif table.getn(self.listElements) > 0 then
        result:addString("</" .. self.listElements[table.getn(self.listElements)] .. ">\n")    
    end
    if (table.getn(self.listTypes) > 0) and (self.listTypes[table.getn(self.listTypes)] ~= theType) then
        local lastType = table.remove(self.listTypes)
        result:addString("</" .. lastType .. ">\n<" .. theType .. ">\n")
        table.insert(self.listTypes, theType)
        table.remove(self.listElements)
        table.insert(self.listElements, theElement)
    end
    return result:toString()
end

function WikiFormatter.methods:calculateListLevel(header)
    local level = string.len(header)
    if math.mod(level, 3) == 0 then
        level = level / 3
    end
    return level
end

function WikiFormatter.methods:specificLink(theLink, theText)
    -- Strip leading/trailing spaces
    theLink = string.gsub(theLink, "^%s*", "")
    theLink = string.gsub(theLink, "%s*$", "")
    
    if string.find(theLink, "^%w+:") ~= nil then
        -- External link: add <nop> before WikiWord
	-- inside link text, to prevent double links
	theText = string.gsub(theText, "([*s%(])(%u+%l+)", "%1<nop>%2")
        return HTK.A { class="twikiLink", href = theLink, theText }
    else
        -- Internal link
	-- Extract '#anchor'
	local anchor = nil
        theLink = string.gsub(theLink, "#" .. wiki.wikiWordPattern, function(text)
            anchor = text
        end)
        return self:internalLink(theLink, anchor, theText)
    end
end

function WikiFormatter.methods:internalLink(theTopic, theAnchor, theText)
    -- check if given page is special one
    if self.engine:isSpecialPage(theTopic) then
        return HTK.A { class="twikiLink", href = theTopic, theTopic }
    end
    
    local originalTopic = theTopic   
    local exists = self.store:topicExists(theTopic)
    -- is plural ?
    if (not exists) and (string.sub(theTopic, -1) == "s") then
        -- Topic name is plural in form and doesn't exist as written
        local tmp = theTopic
        tmp = string.gsub(tmp, "ies$" ,"y")             -- plurals like policy / policies
        tmp = string.gsub(tmp, "sses$" , "ss")          -- plurals like address / addresses
        tmp = string.gsub(tmp, "([Xx])es$", "%1")       -- plurals like box / boxes
        tmp = string.gsub(tmp, "([A-Za-rt-z])s$", "%1") -- others, excluding ending ss like address(es)
        if self.store:topicExists(tmp) then
            exists = true            
        end
        theTopic = tmp
    end
    if exists then
        local link = theTopic
        if theAnchor ~= nil then
            link = theTopic .. "#" .. theAnchor
        end
        local text = theText
        if theText == nil then
            if theAnchor ~= nil then
                text = originalTopic .. "#" .. theAnchor
            else 
                text = originalTopic
            end    
        end
        return self:existentPageLink(link, text)
    else
        local text = theText
        if theText == nil then
            text = originalTopic
        end
        return self:nonExistentPageLink(originalTopic, text)
    end
end


function WikiFormatter.methods:processUrl(urlType, urlAddress)
    local url = urlType .. ":" .. urlAddress
    if (urlType == "http")
        or (urlType == "ftp")
        or (urlType == "gopher")
        or (urlType == "mailto")
        or (urlType == "file") 
        or (urlType == "news") 
        or (urlType == "telnet")
        or (urlType == "https") then
        return HTK.A { href = url, url }  
    else
        return url
    end    
end

function WikiFormatter.methods:isValidTitle(title)
    local beginPos, endPos, captured = string.find(title, wiki.wikiWordPattern)
    if captured ~= title then
        return false
    else
        return true
    end
end


function WikiFormatter.methods:formatWikiLine(line)
    -- blockquote email (indented with '> ')
    line = string.gsub(line, "^>(.*)$", HTK.CITE {"%1"} .. HTK.BR {})
    
    -- embedded HTML
    line = string.gsub(line, "<!%-%-", wiki.transToken .. "!--")
    line = string.gsub(line, "%-%->", "--" .. wiki.transToken)
    line = string.gsub(line, "(<<+)", string.rep("&lt;", string.len("%1")))
    line = string.gsub(line, "(>>+)", string.rep("&gt;", string.len("%1")))
    line = string.gsub(line, "<nop>", "nopTOKEN")
    line = string.gsub(line, "<(%S.-)>", wiki.transToken .. "%1" .. wiki.transToken)
    line = string.gsub(line, "<", "&lt;")
    line = string.gsub(line, ">", "&gt;")
    line = string.gsub(line, wiki.transToken .. "(%S.-)" .. wiki.transToken, "<%1>")
    line = string.gsub(line, "nopTOKEN", "<nop>")
    line = string.gsub(line, wiki.transToken .. "!%-%-", "<!--")
    line = string.gsub(line, "%-%-" .. wiki.transToken, "-->")
    
    -- handle embedded URLs
    line = string.gsub(line, '([^%[])(%w+):([^%s<>"]+[^%s\.,!?;:)<=_*])([^%]])', function(charBefore, urlType, urlAddress, charAfter)
        return charBefore .. self:processUrl(urlType, urlAddress) .. charAfter
    end)
    
    -- entities
    line = string.gsub(line, "&(%w%w-);", wiki.transToken .. "%1;");  -- "&abc;"
    line = string.gsub(line, "&#(%d+);", wiki.transToken .. "#%1;");  -- "&#123;"
    line = string.gsub(line, "&", "&amp;");           -- escape standalone "&"
    line = string.gsub(line, wiki.transToken, "&")
    
    -- headings         ---+
    line = string.gsub(line, "^(%-%-%-%++ )(.*)$", function(header, restOfLine)
        local level = string.len(header) - 4; -- decrease for 3 dashes and 1 space
        if level <= 6 then
            return "<H" .. level .. ">" .. restOfLine .. "</H" .. level .. ">"
        else
            return header .. restOfLine; -- no processing, there was syntax error
        end
    end)
    
    -- horizontal rule  ----
    line = string.gsub(line, "^%-%-%-%-+", HTK.HR {})
    
    -- table            | cell | cell  | cell |
    line = self:processTableLine(line)
    
    -- paragraphs
    local matches = 0
    line, matches = string.gsub(line, "^%s*$", HTK.P {})
    if (matches > 0) or (string.find(line, "^%S+" ) ~= nil) then
        self.isList = false
    end
    
    -- lists
    --[[# Definition list
            s/^(\t+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $2 <\/dt><dd> /o && ( $result .= &emitList( "dl", "dd", length $1 ) );
            s/^(\t+)(\S+?):\s/<dt> $2<\/dt><dd> /o && ( $result .= &emitList( "dl", "dd", length $1 ) );

    --]]        
    -- unnumbered list
    line = string.gsub(line, "^([ ]+)%* ", function(header)
        self.result:addString(self:emitList("UL", "LI", self:calculateListLevel(header)))
        return "<LI> "
    end)
    -- numbered list
    line = string.gsub(line, "^([ ]+)(%d+%.?) ?", function(header, listType)
        self.result:addString(self:emitList("OL", "LI", self:calculateListLevel(header), listType))
        return "<LI> "
    end)
    -- special numbering list
    line = string.gsub(line, "^([ ]+)([1AaIi]%.) ?", function(header, listType)
        self.result:addString(self:emitList("OL", "LI", self:calculateListLevel(header), listType))
        return "<LI> "
    end)
    -- finish the list
    if not self.isList then
        self.result:addString(self:emitList("", "", 0))
        self.isList = false
    end
    
    -- '#WikiName' anchors
    line = string.gsub(line, "^(#)" ..  wiki.wikiWordPattern .. "", HTK.A {name = "%2"})

    -- add spaces for better processing for the following patterns
    line = " " .. line .. " "
    
    -- emphasizing
    -- bold monospaced  ==ble ble==
    line = string.gsub(line, "([%s(])==([^%s].-[^%s])==([%s,.;:!?])", "%1" .. HTK.TT { HTK.STRONG {"%2"} } .. "%3")
    line = string.gsub(line, "([%s(])==([^%s]-)==([%s,.;:!?])", "%1" .. HTK.TT { HTK.STRONG {"%2"} } .. "%3")
    -- bold italic      __ble ble__
    line = string.gsub(line, "([%s(])__([^%s].-[^%s])__([%s,.;:!?])", "%1" .. HTK.STRONG { HTK.EM {"%2"} } .. "%3")
    line = string.gsub(line, "([%s(])__([^%s]-)__([%s,.;:!?])", "%1" .. HTK.STRONG { HTK.EM {"%2"} } .. "%3")
    -- bold             *ble ble*
    line = string.gsub(line, "([%s(])%*([^%s].-[^%s])%*([%s,.;:!?])", "%1" .. HTK.STRONG {"%2"} .. "%3")
    line = string.gsub(line, "([%s(])%*([^%s]-)%*([%s,.;:!?])", "%1" .. HTK.STRONG {"%2"} .. "%3")
    -- italic           _ble ble_
    line = string.gsub(line, "([%s(])_([^%s].-[^%s])_([%s,.;:!?])", "%1" .. HTK.EM {"%2"} .. "%3")
    line = string.gsub(line, "([%s(])_([^%s]-)_([%s,.;:!?])", "%1" .. HTK.EM {"%2"} .. "%3")
    -- monospaced       =ble ble=
    line = string.gsub(line, "([%s(])=([^%s].-[^%s])=([%s,.;:!?])", "%1" .. HTK.TT {"%2"} .. "%3")         
    line = string.gsub(line, "([%s(])=([^%s]-)=([%s,.;:!?])", "%1" .. HTK.TT {"%2"} .. "%3")         
    
    -- Make internal links
    -- hyper links      [[http://ble.ble][Ble ble ble]]
    -- or               [[WikiName][Ble ble]]
    line = string.gsub(line, "%[%[([^%]]+)%]%[([^%]]+)%]%]", function(link, text)
        return self:specificLink(link, text)
    end)   

    -- WikiWords
    if (not self.insideNoAutoLink ) then
        -- TopicName#anchor link:
        line = string.gsub(line, "([%s(])" .. wiki.wikiWordPattern .. "#" .. wiki.wikiWordPattern , function(prefix, title, anchor)
            return prefix .. self:internalLink(title, anchor)
        end)         
        -- s/([\s\(])($regex{wikiWordRegex})($regex{anchorRegex})/&internalLink($1,$theWeb,$2,"$TranslationToken$2$3$TranslationToken",$3,1)/geo;
    
        -- TopicName link:
        line = string.gsub(line, "([%s(])" .. wiki.wikiWordPattern, function(prefix, title)
            return prefix .. self:internalLink(title)
        end)   
    end
    
    -- process strings like %BR%
    line = string.gsub(line, "%%(%S+)%%", function(text)
        return self:processDefinedVariables(text)
    end)     
    return line
end

-- TODO write more rules for %xx% strings
-- define them in configuration table?
function WikiFormatter.methods:processDefinedVariables(text)
    if text == "BR" then
       return HTK.BR {}
    else
       return line 
    end
end

function WikiFormatter.methods:takeOutVerbatim(text)
    local verbatimList = {}
    local verbatimIndex = 1
    local processedText = string.gsub(text, "<verbatim>(.-)</verbatim>", function(verbatimText)
        verbatimList[verbatimIndex] = verbatimText
        local substitution = "VERBATIM(" .. verbatimIndex .. ")VERBATIM"
        verbatimIndex = verbatimIndex + 1
        return substitution
    end)
    return processedText, verbatimList
end


function WikiFormatter.methods:putBackVerbatim(text, verbatimList)
    local processedText = string.gsub(text, "VERBATIM%((%d+)%)VERBATIM", function(verbatimIndex)
        local verbatimText = verbatimList[tonumber(verbatimIndex)]
        local substitution = HTK.PRE { verbatimText }
        return substitution
    end)
    return processedText; 
end


function WikiFormatter.methods:formatWikiPage(content)
    
    -- initial cleanup
    content = string.gsub(content, "\r", "")
    -- clutch to enforce correct rendering at end of doc
    content = string.gsub(content, "(\n?)$", "\n<nop>\n")
   
    local verbatimList = {}
    -- remove <verbatim> .. </verbatim> sections
    content, verbatimList = self:takeOutVerbatim(content)
    -- join lines ending in "\"
    content = string.gsub(content, "\\\n", ""); 
    -- list test
    self.isList = false
    -- spliting into lines ignores last line if it doesn't end with \n
    -- so add \n just for a case
    -- content = content .. "\n"; 
    self.result = StringBuffer:new()
    for line in string.gfind(content, "([^\n]*)\n") do
        if string.find(string.lower(line), "<pre>", 1, true) ~= nil then
            self.insidePre = true
        elseif string.find(string.lower(line), "</pre>", 1, true) ~= nil then
            self.insidePre = false
        end   
        if string.find(string.lower(line), "<noautolink>", 1, true) ~= nil then
            self.insideNoAutoLink = true
        elseif string.find(string.lower(line), "</noautolink>", 1, true) ~= nil then
            self.insideNoAutoLink = false
        end
        
        -- in TWiki at this place tabs are converted to 3 spaces
        -- I decided not to do that - it enables editing files
        -- in text editor and no preprocessing is needed
        -- Also saving edited page is simpler - no need to change 
        -- 3 spaces to tabs
        if self.insidePre then
            -- process line inside <PRE> tags
            -- close list tags if any
            if table.getn(self.listTypes) > 0 then
                self.result:addString(self:emitList( "", "", 0 ))
                self.isList = false
            end
            self.result:addString(line .. "\n")
        else
            -- normal state, do wiki rendering
            self.result:addString(self:formatWikiLine(line))
        end
    end
    -- close started tags
    if self.insideTable then
        self.result:addString("</table>\n")
    end
    -- close list tags
    self.result:addString(self:emitList( "", "", 0 ))
    if self.insidePre then
        self.result:addString("</pre>\n")
    end
    local processedLines = self.result:toString()
    -- insert removed <verbatim> .. </verbatim> sections
    processedLines = self:putBackVerbatim(processedLines, verbatimList)
    -- clean up clutch
    processedLines = string.gsub(processedLines, "\n?<nop>\n$", "")
    return processedLines
end


