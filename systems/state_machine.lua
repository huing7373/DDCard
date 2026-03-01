-- systems/state_machine.lua
-- 状态机系统
-- 管理游戏状态转换和回调

local Object = require("engine.object")

local StateMachine = Object:extend()
StateMachine.__type = "StateMachine"

function StateMachine:init(args)
    args = args or {}

    -- 当前状态
    self.current_state = args.initial_state

    -- 状态定义表
    -- 格式: { STATE_NAME = { on_enter = func, on_exit = func, on_update = func } }
    self.states = {}

    -- 状态转换规则
    -- 格式: { from_state = { to_state = condition_func or true } }
    self.transitions = {}

    -- 状态改变回调
    self.on_state_change = args.on_state_change

    -- 是否记录状态历史
    self.history_enabled = args.history_enabled or false
    self.history = {}
    self.history_limit = args.history_limit or 10
end

-- 定义状态
function StateMachine:define_state(name, config)
    self.states[name] = {
        on_enter = config.on_enter,
        on_exit = config.on_exit,
        on_update = config.on_update,
        data = config.data or {},
    }
    return self
end

-- 定义转换规则
function StateMachine:define_transition(from, to, condition)
    if not self.transitions[from] then
        self.transitions[from] = {}
    end
    self.transitions[from][to] = condition or true
    return self
end

-- 检查是否可以转换到目标状态
function StateMachine:can_transition(to_state)
    local from_state = self.current_state

    -- 如果没有定义转换规则，允许任意转换
    if not self.transitions[from_state] then
        return true
    end

    local rule = self.transitions[from_state][to_state]
    if rule == nil then
        return false
    end

    if type(rule) == "function" then
        return rule(self)
    end

    return rule == true
end

-- 转换到新状态
function StateMachine:transition(new_state, data)
    local old_state = self.current_state

    -- 检查是否可以转换
    if old_state and not self:can_transition(new_state) then
        print(string.format("[StateMachine] Transition blocked: %s -> %s",
            tostring(old_state), tostring(new_state)))
        return false
    end

    -- 执行旧状态的 on_exit
    if old_state and self.states[old_state] then
        local state_def = self.states[old_state]
        if state_def.on_exit then
            state_def.on_exit(self, new_state, data)
        end
    end

    -- 记录历史
    if self.history_enabled and old_state then
        table.insert(self.history, {
            from = old_state,
            to = new_state,
            time = os.time(),
        })
        -- 限制历史长度
        while #self.history > self.history_limit do
            table.remove(self.history, 1)
        end
    end

    -- 更新当前状态
    self.current_state = new_state

    -- 执行新状态的 on_enter
    if self.states[new_state] then
        local state_def = self.states[new_state]
        if state_def.on_enter then
            state_def.on_enter(self, old_state, data)
        end
    end

    -- 触发状态改变回调
    if self.on_state_change then
        self.on_state_change(old_state, new_state, data)
    end

    return true
end

-- 强制设置状态 (跳过转换规则检查)
function StateMachine:force_state(new_state, data)
    local old_state = self.current_state
    self.current_state = new_state

    -- 执行回调
    if self.states[new_state] and self.states[new_state].on_enter then
        self.states[new_state].on_enter(self, old_state, data)
    end

    if self.on_state_change then
        self.on_state_change(old_state, new_state, data)
    end
end

-- 更新当前状态
function StateMachine:update(dt, ...)
    if self.current_state and self.states[self.current_state] then
        local state_def = self.states[self.current_state]
        if state_def.on_update then
            state_def.on_update(self, dt, ...)
        end
    end
end

-- 获取当前状态
function StateMachine:get_state()
    return self.current_state
end

-- 检查是否处于指定状态
function StateMachine:is_state(state)
    return self.current_state == state
end

-- 检查是否处于多个状态之一
function StateMachine:is_any_state(...)
    local states = {...}
    for _, state in ipairs(states) do
        if self.current_state == state then
            return true
        end
    end
    return false
end

-- 获取状态数据
function StateMachine:get_state_data(state_name)
    state_name = state_name or self.current_state
    if self.states[state_name] then
        return self.states[state_name].data
    end
    return nil
end

-- 设置状态数据
function StateMachine:set_state_data(state_name, key, value)
    if self.states[state_name] then
        self.states[state_name].data[key] = value
    end
end

-- 获取状态历史
function StateMachine:get_history()
    return self.history
end

-- 获取上一个状态
function StateMachine:get_previous_state()
    if #self.history > 0 then
        return self.history[#self.history].from
    end
    return nil
end

-- 重置状态机
function StateMachine:reset(initial_state)
    self.current_state = initial_state
    self.history = {}
end

return StateMachine
