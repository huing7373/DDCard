-- main.lua
-- 魔王 - Love2D 入口
-- 薄层：仅包含 Love2D 回调，所有逻辑委托给 Game 单例

local Logger = require("logger")
Logger.init()

local Game = require("game")

-- 游戏实例
local game = nil

-- 初始化
function love.load()
    game = Game.getInstance()
    game:start_up()
    print("魔王 - 游戏初始化完成")
end

-- 更新
function love.update(dt)
    if game then
        game:update(dt)
    end
end

-- 渲染
function love.draw()
    if game then
        game:draw()
    end
end

-- 键盘输入
function love.keypressed(key)
    if game then
        game:keypressed(key)
    end
end

-- 鼠标点击
function love.mousepressed(x, y, button)
    if game then
        game:mousepressed(x, y, button)
    end
end
