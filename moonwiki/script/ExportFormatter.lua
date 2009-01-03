---
-- ExportFormatter class
-- Extends [[WikiFormatter]] class and changes some methods. It is used for rendering pages for exporting
-- to static HTML files. 
-- This class is used by [[WikiExporter]]. 

require("config")
require("htk")
require("WikiFormatter")

ExportFormatter = class("ExportFormatter", WikiFormatter)

---
function ExportFormatter.new(class, store)
    local newObject = ExportFormatter.super.new(class, store)
    return newObject
end

function ExportFormatter.methods:specialPageHeader(title)
    local actions = HTK.P {
        wiki.menuStart,        
        HTK.A { href = "IndexPage" .. serverConfig.exportSuffix, "Index page" }, wiki.menuSeparator,
        HTK.A { href = "RecentChanges" .. serverConfig.exportSuffix, "Recent changes" },
        wiki.menuEnd
    }
    return self:pageHeaderTable(title, actions, true)    
end

function ExportFormatter.methods:standardPageHeader(title)
    local actions = HTK.P {
        wiki.menuStart,        
        HTK.A { href = "IndexPage" .. serverConfig.exportSuffix, "Index page" }, wiki.menuSeparator,
        HTK.A { href = "RecentChanges" .. serverConfig.exportSuffix, "Recent changes" },
        wiki.menuEnd
    }
    return self:pageHeaderTable(title, actions, false)        
end


function ExportFormatter.methods:pageHeaderTable(title, actions, isSpecial)
    if (not serverConfig.exportReverseLink) or isSpecial then
        return self:pageHeaderTemplate(title, actions)
    else 
        return self:pageHeaderTemplate(HTK.A { href = title .. "-ReverseLink" .. serverConfig.exportSuffix, title }, actions)
    end
end


function ExportFormatter.methods:existentPageLink(theTopic, theText)
    return HTK.A {class="twikiLink", href = theTopic .. serverConfig.exportSuffix, theText}
end


function ExportFormatter.methods:nonExistentPageLink(theTopic, theText)
    return theText    
end

