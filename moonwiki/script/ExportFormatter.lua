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

---
-- overwritten function from [[WikiExporter]]
function ExportFormatter.methods:specialPageHeader(title)
    local actions = HTK.P {
        wiki.menuStart,        
        self:existentPageLink("IndexPage", "Index page"), wiki.menuSeparator,
        self:existentPageLink("RecentChanges", "Recent changes"),
        wiki.menuEnd
    }
    return self:pageHeaderTable(title, actions, true)    
end

---
-- overwritten function from [[WikiExporter]]
function ExportFormatter.methods:standardPageHeader(title)
    local actions = HTK.P {
        wiki.menuStart,        
        self:existentPageLink("IndexPage", "Index page"), wiki.menuSeparator,
        self:existentPageLink("RecentChanges", "Recent changes"),
        wiki.menuEnd
    }
    return self:pageHeaderTable(title, actions, false)        
end

---
-- overwritten function from [[WikiExporter]]
function ExportFormatter.methods:reversePageLink(theTopic)
    return HTK.A { href = theTopic .. "-ReverseLink" .. serverConfig.exportSuffix, theTopic }
end

---
-- overwritten function from [[WikiExporter]]
function ExportFormatter.methods:existentPageLink(theTopic, theText)
    return HTK.A {class="twikiLink", href = theTopic .. serverConfig.exportSuffix, theText}
end

---
-- overwritten function from [[WikiExporter]]
function ExportFormatter.methods:nonExistentPageLink(theTopic, theText)
    return theText    
end

