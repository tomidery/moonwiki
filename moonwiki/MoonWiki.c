/* 
 * HTTP server with built in wiki engine.
 * whole HTTP and wiki logic is written in lua language.
 *
 * Documentation for this file could be generated using 
 * 'doxygen' tool http://www.doxygen.org
 *
 * Documentation for lua code could be generated using
 * 'LuaDoc' tool http://www.tecgraf.puc-rio.br/~tomas/luadoc/
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <winsock2.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

/** HTTP server port. */
static int port = 80;   
/** Log file descriptor. */
static FILE* logfd = NULL;   
/** Socket for HTTP connection. */
static SOCKET connectionSocket;
/** Lua interpreter state. */
static lua_State* L;            
/** Directory for exported HTML files. */
static const char* exportDir = NULL;

static void initLua();
static void closeLua();
static int doCall (int inArgs, int outArgs);
static void toLog(char* fmt, ...);
static void createAcceptSocket(SOCKET* s);
static int writeToSocket(const char* dbuf, int dlen);
static void readConfiguration(int argc, char** argv);
static void doExport();


/** 
 * Puts formatted message to log file.
 * Use prameters the same way as for printf() function.
 */
static void toLog(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(logfd, fmt, args);
    va_end(args);
    fflush(logfd);
}

/** 
 * Function for handling fatal errors.
 * Puts formatted message to standard error stream,
 * closes lua state and exits application.
 * Use prameters the same way as for printf() function.
 */
static void fatalError(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fflush(stderr);
    closeLua();
    exit(1);
}

/**
 * Function creates socket and starts listening. Port number is taken
 * from configuration and is in global 'port' variable.
 */
static void createAcceptSocket(SOCKET* s) {
    // begin Windows sockets
    WORD wVersionRequested = MAKEWORD(2, 0);
    WSADATA wsaData;
    if (WSAStartup(wVersionRequested, &wsaData)) {
        fatalError("Can't initialize WinSock\n");
    }
    // create socket
    struct sockaddr_in inaddr;
    memset(&inaddr, 0, sizeof(inaddr));
    inaddr.sin_family       = AF_INET;
    inaddr.sin_addr.s_addr  = INADDR_ANY;
    inaddr.sin_port         = htons(port);
    *s = socket(AF_INET, SOCK_STREAM, 0);
    if (*s == INVALID_SOCKET) {
        fatalError("Can't open socket\n");
    }
    // bind socket
    if (bind(*s, (struct sockaddr *)&inaddr, sizeof(inaddr)) == SOCKET_ERROR) {
        closesocket(*s);
        if (WSAGetLastError() == WSAEADDRINUSE) {
            fatalError("Address in use\n");  
        } else {
            fatalError("Can't open socket\n");
        }
    }
    // listen
    while (listen(*s, 5) == SOCKET_ERROR) {
        if (WSAGetLastError() != WSAEINTR) {
            closesocket(*s);
            fatalError("Can't open socket\n");
        }
    }
    // set to non-blocking mode (should be the default)
    u_long zero = 0;
    ioctlsocket(*s, FIONBIO, &zero);
}


/**
 * Sends specified buffer 'dbuf' of 'dlen' length to socket.
 * Socket is created in 'runServer' function and is stored in 'connectionSocket' variable.
 */
static int writeToSocket(const char* dbuf, int dlen) {
    int olen = dlen;
    int slen;

    for (;;) {
        if (dlen < 65536) {
            slen = send(connectionSocket, dbuf, dlen, 0);
            if (slen != SOCKET_ERROR) {
                if (slen == dlen) {
                    return olen;
                }
                dbuf += slen;
                dlen -= slen;
            } else {
                int err = WSAGetLastError();
                if (err != WSAEWOULDBLOCK)  {
                    break;  // proper error
                }
            }
            Sleep(0);
        } else {
            slen = send(connectionSocket, dbuf, 65536, 0);
            if (slen != SOCKET_ERROR){
                dbuf += 65536;
                dlen -= 65536;
            } else {
                int err = WSAGetLastError();
                if (err != WSAEWOULDBLOCK) {
                    break;  // proper error
                }
            }
            Sleep(0);
        }
    }
    return SOCKET_ERROR;
}

/**
 * Main fuction: creates socket and starts listening. While connection is
 * accepted new 'connectionSocket' is created and 'processRequest' Lua function is called.
 */
static void runServer() {
    SOCKET s;
    createAcceptSocket(&s);
    toLog("Server init OK\n--------------\n");
    // serve
    for (;;) {
        struct sockaddr raddr;
        struct sockaddr_in *rap = (struct sockaddr_in *)&raddr;
        int raddrlen = sizeof(raddr);
        // accept connection
        for (;;) {
            connectionSocket = accept(s, &raddr, &raddrlen);
            if (connectionSocket != INVALID_SOCKET) {
                break;      // connected
            }
            if (WSAGetLastError() == WSAEINTR) {
                continue;   // harmless - try again
            }
            if (WSAGetLastError() != WSAEWOULDBLOCK) {
                break;      // actual error
            }
            Sleep(0);
        }
        if (connectionSocket == INVALID_SOCKET) {
            toLog("Accept failed\n");
            continue;
        }
        toLog("Accept: %s:%d\n", inet_ntoa(rap->sin_addr), port);
        // set new socket to non-blocking
        u_long  one = 1;
        if (ioctlsocket(connectionSocket, FIONBIO, &one) == SOCKET_ERROR) {
            toLog("Setting socket to non-blocking mode failed\n");
            closesocket(connectionSocket);
            continue;
        }
        // call lua script for request processing
        lua_getglobal(L, "processRequest"); 
        doCall(0, 2);
        // get header and page content and lenght
        const char* result = lua_tostring(L, -2);
        int len = (int) lua_tonumber(L, -1);
        if (len > 0) {
            writeToSocket(result, len);
        }
        // remove values from stack
        lua_pop(L, 2);
        closesocket(connectionSocket);
        toLog("-----\n");
    }
}

/**
 * Function called from Lua code.
 */
static int findMatchingFiles(lua_State *L) {
    int quantity = 0;
    const char* path = lua_tostring(L, 1);
    WIN32_FIND_DATA fdata;
    HANDLE hnd = FindFirstFile(path, &fdata);
    if (hnd == INVALID_HANDLE_VALUE) {
        return 0;
    } 
    do {
        lua_pushstring(L, fdata.cFileName);
        quantity++;    
    } while (FindNextFile(hnd, &fdata));
    return quantity;
}

/**
 * Function called from Lua code.
 */
static int findRecentFiles(lua_State *L) {
    int quantity = 0;
    const char* path = lua_tostring(L, 1);
    WIN32_FIND_DATA fdata;
    HANDLE hnd = FindFirstFile(path, &fdata);
    if (hnd == INVALID_HANDLE_VALUE) {
        return 0;
    } 
    // buffer for date string "YYYY-MM-DD  HH:MM\0"
    char buffer[18] = {'\0'};
    SYSTEMTIME stUTC, stLocal;
    do {
        // convert the last-write time to local time.
        FileTimeToSystemTime(&(fdata.ftLastWriteTime), &stUTC);
        SystemTimeToTzSpecificLocalTime(NULL, &stUTC, &stLocal);
        // bBuild a string showing the date and time.
        wsprintf(buffer, TEXT("%4d-%02d-%02d  %02d:%02d"),
            stLocal.wYear, stLocal.wMonth, stLocal.wDay, stLocal.wHour, stLocal.wMinute);
        // list of tables of (key, value) pairs is returned
        lua_newtable(L);
        // key = date
        lua_pushstring(L, buffer);   
        // value = push file name        
        lua_pushstring(L, fdata.cFileName);     
        lua_settable(L, -3);
        quantity++;    
    } while (FindNextFile(hnd, &fdata));
    return quantity;
}

/**
 * Function called from Lua code.
 */
static int readFromSocket(lua_State *L) {
    size_t size = (size_t)lua_tonumber(L,1);
    char* buf = (char*) malloc(size);
    if (buf == NULL) {
        lua_pushstring(L,"");
        lua_pushnumber(L,-1); // malloc error
        return 2;
    }
    int rc = 0;
    for (;;) {
        rc = recv(connectionSocket, buf, size, 0);
        if (rc == 0) {
            rc = SOCKET_ERROR; // connection is closed
            break;
        } 
        if (rc != SOCKET_ERROR) {
            break;              // recv finished
        }
        if (WSAGetLastError() != WSAEWOULDBLOCK) {
            rc = SOCKET_ERROR; // real error
            break;
        }
        Sleep(0);
    }
    if (rc == SOCKET_ERROR) {
        lua_pushstring(L,"");
        lua_pushnumber(L,-1);   // socket reading error
    } else {
        lua_pushlstring(L, buf, rc);
        lua_pushnumber(L, rc);
    }
    free((void*) buf);        
    return 2;
}

/**
 * Function called from Lua code.
 */
static int copyFile(lua_State *L) {
    const char* from = lua_tostring(L,1);    
    const char* to = lua_tostring(L,2); 
    BOOL failIfExists = (BOOL) lua_toboolean(L,3);   
    BOOL result = CopyFile(from, to, failIfExists);    
    if (result) {
        lua_pushnumber(L,0);    
    } else {
        DWORD errorCode = GetLastError();
        if (errorCode == ERROR_FILE_NOT_FOUND) {
            lua_pushnumber(L,-1);
        } else if (errorCode == ERROR_ACCESS_DENIED) {
            lua_pushnumber(L,-2);
        } else {
            lua_pushnumber(L,-3);
        }
    }
    return 1;
}
    
/**
 * Initialize Lua interpreter.
 */
static void initLua() {
    L = lua_open();
    if (L == NULL) {
        fatalError("Couldn't initialize Lua\n");
    }
    // load libraries
    luaopen_base(L);
    luaopen_io(L);
    luaopen_string(L);
    luaopen_math(L);
    luaopen_table(L);
    // register C functions
    lua_register(L,"findMatchingFiles",findMatchingFiles);
    lua_register(L,"findRecentFiles",findRecentFiles);
    lua_register(L,"readFromSocket",readFromSocket);
    lua_register(L,"copyFile",copyFile);
    // load code files
    if (lua_dofile(L, "script/main.lua") != 0) {
        fatalError("Can't load lua code\n");
    }    
}

/**
 * Close Lua interpreter.
 */
static void closeLua() {
    if (L != NULL) {
        lua_close(L);
        L = NULL;
    }
}


static int doCall(int inArgs, int outArgs) {
    int status;
    const char *msg;
    status = lua_pcall(L, inArgs, outArgs, 0);
    if (status) {
        msg = lua_tostring(L, -1);
        if (msg == NULL) {
            msg = "Lua error with no message";
        }
        fatalError("%s\n", msg);
    }
    return status;
}


static void readConfiguration(int argc, char** argv) {
    if (argc > 1) {
        // call function for parsing command line argument
        lua_getglobal(L, "parseCommandLineArgs"); 
        int i = 1; // ignore first argumet - program name
        do {
            lua_pushstring(L, argv[i]);
            i++;
        } while (i < argc);
        doCall(argc - 1, 1);
        // get status
        int status = lua_toboolean(L, -1);
        lua_pop(L, 1);
        if (! status) {
            fatalError("Can't parse command line arguments\n");
        }            
    }
    // get server config
    lua_getglobal(L, "getServerConfig"); 
    doCall(0, 4);
    exportDir = lua_tostring(L, -4);
    if (exportDir == NULL) {
        port = (int)lua_tonumber(L, -3);
        int clearLog = lua_toboolean(L, -2);
        if (lua_isnil(L, -1)) {
            logfd = stdout;
        } else {
            const char* logFile = lua_tostring(L, -1);
            logfd = fopen(logFile, clearLog ? "w" : "a");
            if (!logfd) {
                lua_pop(L, 4);
                fatalError("Can't open logfile %s\n", logFile);
            }
            FreeConsole();
        }
    }
    lua_pop(L, 4);
}



/**
 * Create exportDir and call Lua function which does the rest.
 */
static void doExport() {
    BOOL result = CreateDirectory(exportDir, NULL);
    if (!result) {
        DWORD errorCode = GetLastError();    
        if (errorCode == ERROR_PATH_NOT_FOUND) {
            fatalError("Can't create %s direcotry\n", exportDir);
        }
    }
    lua_getglobal(L, "doExport"); 
    doCall(0, 0);
}
    

/**
 * Main program entry point.
 */
int main(int argc, char** argv) {
    // disable retry dialog
    SetProcessShutdownParameters(0x100, SHUTDOWN_NORETRY);
    // init Lua interpreter
    initLua();
    // get command-line and config file parameters 
    readConfiguration(argc, argv);
    // invoke main action
    if (exportDir != NULL) {
        doExport();
    } else {
        runServer();
    }
    return 1;
}
