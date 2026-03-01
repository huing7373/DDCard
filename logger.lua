-- logger.lua
-- 日志模块，将输出写入文件

local Logger = {}

local logFile = nil
local originalPrint = print
local logLevel = 1  -- 0=OFF, 1=INFO, 2=DEBUG
local outputToConsole = false  -- 是否同时输出到控制台

-- 日志级别
Logger.LEVEL = {
    OFF = 0,
    INFO = 1,
    DEBUG = 2,
}

function Logger.init(options)
    options = options or {}
    logLevel = options.level or Logger.LEVEL.INFO
    outputToConsole = options.console or false

    -- 打开日志文件 (覆盖模式)
    logFile = io.open("game.log", "w")
    if logFile then
        logFile:write("=== Game Log Started ===\n")
        logFile:flush()
    end

    -- 重定向 print 到日志
    print = function(...)
        Logger.info(...)
    end
end

-- 写入日志的内部函数
local function writeLog(prefix, ...)
    local args = {...}
    local str = ""
    for i, v in ipairs(args) do
        if i > 1 then str = str .. "\t" end
        str = str .. tostring(v)
    end

    local line = prefix .. str

    -- 输出到原始控制台 (可选)
    if outputToConsole then
        originalPrint(line)
    end

    -- 写入文件
    if logFile then
        logFile:write(line .. "\n")
        logFile:flush()
    end
end

-- INFO 级别日志
function Logger.info(...)
    if logLevel >= Logger.LEVEL.INFO then
        writeLog("", ...)
    end
end

-- DEBUG 级别日志
function Logger.debug(...)
    if logLevel >= Logger.LEVEL.DEBUG then
        writeLog("[DEBUG] ", ...)
    end
end

-- 警告日志
function Logger.warn(...)
    if logLevel >= Logger.LEVEL.INFO then
        writeLog("[WARN] ", ...)
    end
end

-- 错误日志 (始终输出)
function Logger.error(...)
    writeLog("[ERROR] ", ...)
end

-- 设置日志级别
function Logger.setLevel(level)
    logLevel = level
end

function Logger.close()
    if logFile then
        logFile:write("=== Game Log Ended ===\n")
        logFile:close()
        logFile = nil
    end
    print = originalPrint
end

return Logger
