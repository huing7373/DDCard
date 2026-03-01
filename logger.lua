-- logger.lua
-- 简单日志模块，将输出写入文件

local Logger = {}

local logFile = nil
local originalPrint = print

function Logger.init()
    -- 打开日志文件 (覆盖模式)
    logFile = io.open("game.log", "w")
    if logFile then
        logFile:write("=== Game Log Started ===\n")
        logFile:flush()
    end

    -- 重定向 print
    print = function(...)
        local args = {...}
        local str = ""
        for i, v in ipairs(args) do
            if i > 1 then str = str .. "\t" end
            str = str .. tostring(v)
        end

        -- 输出到原始控制台
        originalPrint(str)

        -- 写入文件
        if logFile then
            logFile:write(str .. "\n")
            logFile:flush()
        end
    end
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
