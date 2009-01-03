---
-- WikiStore class
-- Responsible for handling storage of wiki files.


require("config")
require("Object")

WikiStore = class("WikiStore", Object)

function WikiStore.methods:topicExists(theTopic)
    local filePath = serverConfig.rootDir .. "/" .. theTopic .. serverConfig.suffix
    local file = io.open(filePath, "r")
    if file == nil then
        return false
    else 
        file:close()
        return true
    end
end

function WikiStore.methods:savePage(title, content)
    local filePath = serverConfig.rootDir .. "/" .. title .. serverConfig.suffix
    local file = io.open(filePath, "w")
    if file == nil then
        return false
    end
    --content = decodeSpecialChars(content)
    --content = string.gsub(content, "   ", "\t")
    -- it was needed, I'm not sure why
    content = string.gsub(content, "\r","")
    local content = file:write(content)
    file:close()
    return true
end


function WikiStore.methods:loadPage(title)
    local filePath = serverConfig.rootDir .. "/" .. title .. serverConfig.suffix
    local file = io.open(filePath, "r")
    if file == nil then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

