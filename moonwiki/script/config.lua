-- MoonWiki configuration

--- Configuration of MoonWiki server.
-- Some options could be changed using command line parameters:
-- -c to clear log
-- -l log_file to specify log file
-- -p port to specify HTTP server's port
serverConfig = {
    rootDir = "htdocs",     -- root dir where all pages are
    logoFile = "moon.jpg",  -- name of logo file
    cssStyles = "style.css", -- name of CSS file
    suffix = ".txt",        -- suffix of wiki pages
    clearLog = false,       -- if set to true log file will be cleared durring every start
    logFile = nil,          -- name of log file or nil (logging to console)
    port = 8080,            -- default port to start HTTP server
    version = "0.2",        -- version of MoonWiki server
    recentChangesListSize = 20,  -- size of list of recently changed pages
    -- export to HTML options
    exportSuffix = ".html", -- suffix of exported pages
    exportDir = nil,        -- if it is set then all pages are exported as HTML files
    exportReverseLink = false -- whether reverse links pages should be created 
}

--- Definition of content types supported by MoonWiki.
-- This is mapping between file suffix and its content type.
-- This mapping could be extended if other file types are needed.
contentTypes = {
    txt  = "text/plain",
    htm  = "text/html",
    html = "text/html",
    css  = "text/css",
    jpg  = "image/jpeg",
    jpeg = "image/jpeg",
    gif  = "image/gif",
    png  = "image/png",
    au   = "audio/basic",
    wav  = "audio/wav",
    midi = "audio/midi",
    mid  = "audio/midi",
    mp3  = "audio/mpeg",
    avi  = "video/x-msvideo",
    mov  = "video/quicktime",
    qt   = "video/quicktime",
    mpeg = "video/mpeg",
    mpe  = "video/mpeg",
    vrml = "model/vrml",
    wrl  = "model/vrml",
    lua  = "text/plain"
}

