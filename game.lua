-- game.lua
-- Game 单例类
-- 管理游戏生命周期和全局状态

local Object = require("engine.object")
local EventModule = require("engine.event")
local CardArea = require("entities.card_area")

local Game = Object:extend()
Game.__type = "Game"

-- 单例实例
local instance = nil

function Game:init()
    -- 防止多次实例化
    if instance then
        error("Game is a singleton, use Game.getInstance()")
    end

    self.initialized = false
    self.state = nil
    self.event_manager = EventModule.EventManager()

    -- 字体缓存
    self.FONT = {}

    -- 帧计数器
    self.frame = 0

    -- 卡牌区域管理
    self.card_areas = {}

    -- 游戏实体引用
    self.player = nil
    self.enemies = {}
    self.grid = nil
end

-- 获取单例实例
function Game.getInstance()
    if not instance then
        instance = Game()
    end
    return instance
end

-- 设置全局配置
function Game:set_globals()
    -- 加载全局配置 (globals.lua 会设置 G 表)
    require("globals")

    -- 确保 G 表存在
    if not G then
        G = {}
    end

    -- 绑定 Game 实例到全局
    G.GAME = self
    G.E = self.event_manager

    print("[Game] Globals initialized")
end

-- 加载字体
function Game:load_fonts()
    local font_path = "resources/fonts/msyh.ttc"

    -- 检查字体文件是否存在
    local info = love.filesystem.getInfo(font_path)
    if info then
        self.FONT.SMALL = love.graphics.newFont(font_path, 12)
        self.FONT.NORMAL = love.graphics.newFont(font_path, 14)
        self.FONT.LARGE = love.graphics.newFont(font_path, 18)
        self.FONT.TITLE = love.graphics.newFont(font_path, 24)
        print("[Game] Fonts loaded from: " .. font_path)
    else
        -- 回退到默认字体
        self.FONT.SMALL = love.graphics.newFont(12)
        self.FONT.NORMAL = love.graphics.newFont(14)
        self.FONT.LARGE = love.graphics.newFont(18)
        self.FONT.TITLE = love.graphics.newFont(24)
        print("[Game] Warning: Font not found, using default")
    end

    -- 绑定到全局
    G.FONT = self.FONT
end

-- 游戏启动
function Game:start_up()
    print("[Game] Starting up...")

    -- 初始化全局配置
    self:set_globals()

    -- 加载字体
    self:load_fonts()

    -- 标记初始化完成
    self.initialized = true

    print("[Game] Startup complete")
end

-- 更新循环
function Game:update(dt)
    if not self.initialized then return end

    -- 更新全局计时器
    G.TIMERS.REAL = G.TIMERS.REAL + dt
    G.TIMERS.TOTAL = G.TIMERS.TOTAL + dt

    -- 更新事件队列
    self.event_manager:update(dt)

    -- 更新所有可移动实体
    for _, moveable in ipairs(G.I.MOVEABLE) do
        moveable:move(dt)
    end

    -- 更新帧计数
    self.frame = self.frame + 1
end

-- 渲染循环
function Game:draw()
    if not self.initialized then return end

    -- 子类或外部代码负责实际渲染
    -- 这里仅提供框架调用点
end

-- 状态转换
function Game:set_state(new_state)
    local old_state = self.state
    self.state = new_state

    if G.STATE_NAMES then
        local old_name = old_state and G.STATE_NAMES[old_state] or "nil"
        local new_name = G.STATE_NAMES[new_state] or "UNKNOWN"
        print(string.format("[Game] State: %s -> %s", old_name, new_name))
    end
end

-- 获取当前状态
function Game:get_state()
    return self.state
end

-- 检查状态
function Game:is_state(state)
    return self.state == state
end

-- 添加即时事件
function Game:add_event(args, queue_name)
    return self.event_manager:add(args, queue_name)
end

-- 添加延迟事件
function Game:add_event_after(delay, func, queue_name)
    return self.event_manager:add_after(delay, func, queue_name)
end

-- 创建卡牌区域
function Game:create_card_area(name, args)
    local area = CardArea(args)
    self.card_areas[name] = area
    return area
end

-- 获取卡牌区域
function Game:get_card_area(name)
    return self.card_areas[name]
end

-- 移除卡牌区域
function Game:remove_card_area(name)
    local area = self.card_areas[name]
    if area then
        area:remove()
        self.card_areas[name] = nil
    end
end

-- 设置玩家
function Game:set_player(player)
    self.player = player
end

-- 添加敌人
function Game:add_enemy(enemy)
    table.insert(self.enemies, enemy)
end

-- 移除敌人
function Game:remove_enemy(enemy)
    for i, e in ipairs(self.enemies) do
        if e == enemy then
            table.remove(self.enemies, i)
            return true
        end
    end
    return false
end

-- 清空所有敌人
function Game:clear_enemies()
    self.enemies = {}
end

-- 获取所有敌人
function Game:get_enemies()
    return self.enemies
end

-- 更新所有卡牌区域
function Game:update_card_areas(dt)
    for _, area in pairs(self.card_areas) do
        area:update(dt)
    end
end

-- 绘制所有卡牌区域
function Game:draw_card_areas()
    for _, area in pairs(self.card_areas) do
        area:draw()
    end
end

-- 清理
function Game:cleanup()
    -- 清空事件队列
    self.event_manager:clear_all()

    -- 清理卡牌区域
    for name, area in pairs(self.card_areas) do
        area:remove()
    end
    self.card_areas = {}

    -- 清理实体引用
    self.player = nil
    self.enemies = {}
    self.grid = nil

    -- 重置实例追踪
    if G.reset_instances then
        G.reset_instances()
    end

    print("[Game] Cleanup complete")
end

return Game
