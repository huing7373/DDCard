-- Event.lua
-- 事件队列系统
-- 支持即时、延迟、缓动和条件事件

local Object = require("engine.object")

--------------------------------------------------
-- Event 类
--------------------------------------------------
local Event = Object:extend()
Event.__type = "Event"

-- 事件类型
Event.TYPE = {
    IMMEDIATE = "immediate",   -- 立即执行
    AFTER = "after",           -- 延迟执行
    EASE = "ease",             -- 缓动动画
    CONDITION = "condition",   -- 条件触发
}

function Event:init(args)
    args = args or {}

    self.event_type = args.event_type or Event.TYPE.IMMEDIATE
    self.func = args.func                -- 执行函数
    self.delay = args.delay or 0         -- 延迟时间
    self.timer = 0                       -- 计时器
    self.done = false                    -- 完成标记
    self.blocking = args.blocking ~= false  -- 是否阻塞后续事件
    self.blockable = args.blockable ~= false  -- 是否可被阻塞

    -- 缓动参数
    self.ease_func = args.ease_func      -- 缓动函数
    self.ease_target = args.ease_target  -- 目标对象
    self.ease_key = args.ease_key        -- 目标属性
    self.ease_from = args.ease_from      -- 起始值
    self.ease_to = args.ease_to          -- 目标值
    self.ease_duration = args.ease_duration or 0.3

    -- 条件参数
    self.condition = args.condition      -- 条件函数
end

-- 更新事件
function Event:update(dt)
    if self.done then return true end

    if self.event_type == Event.TYPE.IMMEDIATE then
        return self:update_immediate()

    elseif self.event_type == Event.TYPE.AFTER then
        return self:update_after(dt)

    elseif self.event_type == Event.TYPE.EASE then
        return self:update_ease(dt)

    elseif self.event_type == Event.TYPE.CONDITION then
        return self:update_condition()
    end

    return true
end

function Event:update_immediate()
    if self.func then
        self.func()
    end
    self.done = true
    return true
end

function Event:update_after(dt)
    self.timer = self.timer + dt

    if self.timer >= self.delay then
        if self.func then
            self.func()
        end
        self.done = true
        return true
    end

    return false
end

function Event:update_ease(dt)
    self.timer = self.timer + dt

    local progress = math.min(self.timer / self.ease_duration, 1)

    -- 应用缓动函数
    local eased = progress
    if self.ease_func then
        eased = self.ease_func(progress)
    end

    -- 更新目标值
    if self.ease_target and self.ease_key then
        local value = self.ease_from + (self.ease_to - self.ease_from) * eased
        self.ease_target[self.ease_key] = value
    end

    if progress >= 1 then
        if self.func then
            self.func()
        end
        self.done = true
        return true
    end

    return false
end

function Event:update_condition()
    if self.condition and self.condition() then
        if self.func then
            self.func()
        end
        self.done = true
        return true
    end

    return false
end

--------------------------------------------------
-- EventManager 类
--------------------------------------------------
local EventManager = Object:extend()
EventManager.__type = "EventManager"

function EventManager:init()
    self.queues = {}        -- 命名队列表
    self.default_queue = {} -- 默认队列
end

-- 获取或创建队列
function EventManager:get_queue(name)
    if not name then
        return self.default_queue
    end

    if not self.queues[name] then
        self.queues[name] = {}
    end

    return self.queues[name]
end

-- 添加事件到队列
function EventManager:add(args, queue_name)
    local event = Event(args)
    local queue = self:get_queue(queue_name)
    table.insert(queue, event)
    return event
end

-- 添加即时事件
function EventManager:add_immediate(func, queue_name)
    return self:add({
        event_type = Event.TYPE.IMMEDIATE,
        func = func,
    }, queue_name)
end

-- 添加延迟事件
function EventManager:add_after(delay, func, queue_name)
    return self:add({
        event_type = Event.TYPE.AFTER,
        delay = delay,
        func = func,
    }, queue_name)
end

-- 添加缓动事件
function EventManager:add_ease(args, queue_name)
    args.event_type = Event.TYPE.EASE
    return self:add(args, queue_name)
end

-- 添加条件事件
function EventManager:add_condition(condition, func, queue_name)
    return self:add({
        event_type = Event.TYPE.CONDITION,
        condition = condition,
        func = func,
    }, queue_name)
end

-- 更新所有队列
function EventManager:update(dt)
    -- 更新默认队列
    self:update_queue(self.default_queue, dt)

    -- 更新所有命名队列
    for name, queue in pairs(self.queues) do
        self:update_queue(queue, dt)
    end
end

-- 更新单个队列
function EventManager:update_queue(queue, dt)
    local i = 1
    local blocked = false

    while i <= #queue do
        local event = queue[i]

        -- 如果被阻塞且事件可被阻塞，跳过
        if blocked and event.blockable then
            i = i + 1
        else
            local done = event:update(dt)

            if done then
                table.remove(queue, i)
            else
                -- 如果事件是阻塞性的，标记后续事件被阻塞
                if event.blocking then
                    blocked = true
                end
                i = i + 1
            end
        end
    end
end

-- 清空队列
function EventManager:clear(queue_name)
    if queue_name then
        self.queues[queue_name] = {}
    else
        self.default_queue = {}
    end
end

-- 清空所有队列
function EventManager:clear_all()
    self.default_queue = {}
    self.queues = {}
end

-- 检查队列是否为空
function EventManager:is_empty(queue_name)
    local queue = self:get_queue(queue_name)
    return #queue == 0
end

-- 获取队列长度
function EventManager:queue_size(queue_name)
    local queue = self:get_queue(queue_name)
    return #queue
end

--------------------------------------------------
-- 缓动函数库
--------------------------------------------------
local Ease = {}

function Ease.linear(t)
    return t
end

function Ease.quad_in(t)
    return t * t
end

function Ease.quad_out(t)
    return t * (2 - t)
end

function Ease.quad_in_out(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

function Ease.cubic_in(t)
    return t * t * t
end

function Ease.cubic_out(t)
    local t1 = t - 1
    return t1 * t1 * t1 + 1
end

function Ease.elastic_out(t)
    if t == 0 or t == 1 then return t end
    local p = 0.3
    local s = p / 4
    return math.pow(2, -10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
end

function Ease.back_out(t)
    local s = 1.70158
    local t1 = t - 1
    return t1 * t1 * ((s + 1) * t1 + s) + 1
end

function Ease.bounce_out(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        local t1 = t - 1.5 / 2.75
        return 7.5625 * t1 * t1 + 0.75
    elseif t < 2.5 / 2.75 then
        local t1 = t - 2.25 / 2.75
        return 7.5625 * t1 * t1 + 0.9375
    else
        local t1 = t - 2.625 / 2.75
        return 7.5625 * t1 * t1 + 0.984375
    end
end

return {
    Event = Event,
    EventManager = EventManager,
    Ease = Ease,
}
