---
-- WikiExporter class

require("ExportFormatter")
require("WikiStore")
require("WikiEngine")

WikiExporter = class("WikiExporter", WikiEngine)

---
-- Creates new [[WikiExporter]].  
function WikiExporter.new(class,...)
    local newStore = WikiStore:new()
    local newObject =  WikiExporter.super.new(class, {}, unpack(arg))
    return newObject
end

-- sets formatter - normal or printable
function WikiExporter.methods:setFormatter()
    self.formatter = ExportFormatter:new(self.store)
    self.formatter:setWikiEngine(self) -- update reference to WikiExporter in formatter    
end


---
-- exports all pages
function WikiExporter.methods:exportAllPages(dir)
    files = {findMatchingFiles(serverConfig.rootDir .. "/*" .. serverConfig.suffix)}
    for file in files do
        local pageTitle = self:getNameWithoutSuffix(files[file])
        if self:isValidPage(pageTitle) then
            -- regular page
            local page = self:processWikiPage(pageTitle, self.store:loadPage(pageTitle))    
            self:saveHtmlFile(dir, pageTitle, page)
            if serverConfig.exportReverseLink then
                -- reverse links page
                self.request.parameters["page"] = pageTitle
                local reverseLinkPage = self:createSpecialReverseLink("ReverseLink")
                self:saveHtmlFile(dir, pageTitle .. "-ReverseLink", reverseLinkPage)            
            end
        end
    end
end

---
-- exports all pages
function WikiExporter.methods:exportSpecialPages(dir)
    local page = self:createSpecialIndexPage("IndexPage")    
    self:saveHtmlFile(dir, "IndexPage", page)
    page = self:createSpecialRecentChanges("RecentChanges")  
    self:saveHtmlFile(dir, "RecentChanges", page)        
end
 

---
-- copy additional files (images, CSS, etc.)
function WikiExporter.methods:copyAdditionalFiles(dir)
    self:copyToExportDir(serverConfig.logoFile, dir)
    self:copyToExportDir(serverConfig.cssStyles, dir)
end

---
-- helper function, copies file from 'rootDir' to specified export directory
function WikiExporter.methods:copyToExportDir(file, dir)
    local result = copyFile(serverConfig.rootDir .. "/" .. file, dir .. "/" .. file, false)
    if result == 0 then
        print(file .. " copied to " .. dir)     
    else 
        print("Can't copy " .. file .. " error: " .. result)
    end
end

 
function WikiExporter.methods:saveHtmlFile(dir, title, content)
    local filePath = dir .. "/" .. title .. serverConfig.exportSuffix
    local file = io.open(filePath, "w")
    if file == nil then
        print("Can't open file for write: " .. filePath)
        return false
    end
    local content = file:write(content)
    file:close()
    print(title .. " exported") 
    return true
end