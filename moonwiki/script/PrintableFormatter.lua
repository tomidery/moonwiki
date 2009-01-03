---
-- PrintableFormatter class
-- Extends [[WikiFormatter]] class and changes some methods. It is used for rendering pages for printing,
-- eg. links are removed and WikiNames are not hyperlinks. 
-- This class is used by [[WikiEngine]]. 

require("WikiFormatter")

PrintableFormatter = class("PrintableFormatter", WikiFormatter)

---
function PrintableFormatter.new(class, store)
    local newObject = PrintableFormatter.super.new(class, store)
    return newObject
end



function PrintableFormatter.methods:pageHeaderTable(title, actions, isSpecial)
    return self:pageHeaderTemplate(title, " ")  
end


function PrintableFormatter.methods:processUrl(urlType, urlAddress)
    local url = urlType .. ":" .. urlAddress
    return url
end

function PrintableFormatter.methods:internalLink(theTopic, theAnchor, theText)
    if theText ~= nil then
        return theText
    else
        return theTopic
    end
end

