-- systems/animation.lua
-- 动画系统
-- 使用事件队列管理动画效果

local Object = require("engine.object")
local EventModule = require("engine.event")

local Animation = Object:extend()
Animation.__type = "Animation"

-- 单例实例
local instance = nil

function Animation:init()
    if instance then
        error("Animation is a singleton, use Animation.getInstance()")
    end

    -- 独立的事件管理器用于动画
    self.event_manager = EventModule.EventManager()

    -- 伤害文字列表
    self.damage_texts = {}

    -- 屏幕震动
    self.screen_shake = {
        intensity = 0,
        timer = 0,
        offset_x = 0,
        offset_y = 0,
    }

    -- 技能特效列表
    self.skill_effects = {}

    -- 缓存配置
    self.config = {
        damage_text_duration = 1.5,
        damage_text_speed = 30,
        shake_duration = 0.1,
        shake_intensity = 3,
        skill_shake_intensity = 5,
    }
end

-- 获取单例
function Animation.getInstance()
    if not instance then
        instance = Animation()
    end
    return instance
end

-- 设置配置
function Animation:set_config(config)
    for k, v in pairs(config) do
        self.config[k] = v
    end
end

-------------------------------------------------
-- 伤害文字
-------------------------------------------------

-- 添加伤害文字
function Animation:add_damage_text(args)
    local text = {
        x = args.x,
        y = args.y,
        text = args.text,
        color = args.color or {1, 0.3, 0.3},
        timer = 0,
        duration = args.duration or self.config.damage_text_duration,
        speed = args.speed or self.config.damage_text_speed,
        alpha = 1,
        scale = args.scale or 1.5,  -- 初始放大
    }
    table.insert(self.damage_texts, text)
    return text
end

-- 更新伤害文字
function Animation:update_damage_texts(dt)
    for i = #self.damage_texts, 1, -1 do
        local dmg = self.damage_texts[i]
        dmg.timer = dmg.timer + dt
        dmg.y = dmg.y - dmg.speed * dt

        -- 淡出和缩放
        local progress = dmg.timer / dmg.duration
        dmg.alpha = 1 - progress
        dmg.scale = 1 + 0.5 * (1 - progress)  -- 从1.5缩小到1

        if dmg.timer >= dmg.duration then
            table.remove(self.damage_texts, i)
        end
    end
end

-- 绘制伤害文字
function Animation:draw_damage_texts()
    local font = love.graphics.getFont()
    for _, dmg in ipairs(self.damage_texts) do
        love.graphics.setColor(dmg.color[1], dmg.color[2], dmg.color[3], dmg.alpha)

        -- 居中绘制
        local text_width = font:getWidth(dmg.text)
        love.graphics.print(
            dmg.text,
            dmg.x - text_width / 2,
            dmg.y
        )
    end
end

-- 清空伤害文字
function Animation:clear_damage_texts()
    self.damage_texts = {}
end

-------------------------------------------------
-- 屏幕震动
-------------------------------------------------

-- 触发屏幕震动
function Animation:shake(intensity, duration)
    self.screen_shake.intensity = intensity or self.config.shake_intensity
    self.screen_shake.timer = duration or self.config.shake_duration
end

-- 触发技能屏幕震动 (更强)
function Animation:shake_skill()
    self:shake(self.config.skill_shake_intensity, self.config.shake_duration)
end

-- 更新屏幕震动
function Animation:update_screen_shake(dt)
    local shake = self.screen_shake
    if shake.timer > 0 then
        shake.timer = shake.timer - dt
        local intensity = shake.intensity * (shake.timer / self.config.shake_duration)
        shake.offset_x = (math.random() - 0.5) * 2 * intensity
        shake.offset_y = (math.random() - 0.5) * 2 * intensity
    else
        shake.offset_x = 0
        shake.offset_y = 0
    end
end

-- 获取震动偏移
function Animation:get_shake_offset()
    return self.screen_shake.offset_x, self.screen_shake.offset_y
end

-- 应用震动变换 (调用 love.graphics.push/translate)
function Animation:apply_shake()
    love.graphics.push()
    love.graphics.translate(self.screen_shake.offset_x, self.screen_shake.offset_y)
end

-- 结束震动变换 (调用 love.graphics.pop)
function Animation:end_shake()
    love.graphics.pop()
end

-------------------------------------------------
-- 技能特效
-------------------------------------------------

-- 添加技能特效
function Animation:add_skill_effect(args)
    local effect = {
        type = args.type or "whirlwind",
        center_x = args.center_x,
        center_y = args.center_y,
        timer = 0,
        duration = args.duration or 0.3,
        data = args.data or {},
    }
    table.insert(self.skill_effects, effect)
    return effect
end

-- 更新技能特效
function Animation:update_skill_effects(dt)
    for i = #self.skill_effects, 1, -1 do
        local effect = self.skill_effects[i]
        effect.timer = effect.timer + dt
        if effect.timer >= effect.duration then
            table.remove(self.skill_effects, i)
        end
    end
end

-- 绘制技能特效
function Animation:draw_skill_effects(cell_size)
    cell_size = cell_size or 100

    for _, effect in ipairs(self.skill_effects) do
        local progress = effect.timer / effect.duration

        if effect.type == "whirlwind" then
            self:draw_whirlwind_effect(effect, progress, cell_size)
        elseif effect.type == "charge" then
            self:draw_charge_effect(effect, progress, cell_size)
        elseif effect.type == "shield" then
            self:draw_shield_effect(effect, progress, cell_size)
        elseif effect.type == "lifesteal" then
            self:draw_lifesteal_effect(effect, progress, cell_size)
        end
    end
end

-- 旋风特效
function Animation:draw_whirlwind_effect(effect, progress, cell_size)
    local alpha = 1 - progress
    local rotation = progress * math.pi * 4  -- 两圈旋转

    -- 8方向放射线
    local directions = {
        {dx = 0, dy = -1}, {dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1},
        {dx = 0, dy = 1}, {dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}
    }

    for _, dir in ipairs(directions) do
        local cell_x = effect.center_x + dir.dx * cell_size
        local cell_y = effect.center_y + dir.dy * cell_size
        love.graphics.setColor(1, 0.3, 0.3, alpha * 0.5)
        love.graphics.rectangle("fill", cell_x, cell_y, cell_size, cell_size)
    end

    -- 中心旋转指示器
    love.graphics.setColor(1, 0.5, 0.3, alpha)
    local cx = effect.center_x + cell_size / 2
    local cy = effect.center_y + cell_size / 2
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(rotation)
    love.graphics.line(-20, 0, 20, 0)
    love.graphics.line(0, -20, 0, 20)
    love.graphics.pop()
end

-- 冲锋特效
function Animation:draw_charge_effect(effect, progress, cell_size)
    local alpha = 1 - progress
    love.graphics.setColor(1, 0.8, 0.2, alpha * 0.7)

    -- 拖尾效果
    if effect.data.from_x and effect.data.from_y then
        local fx = effect.data.from_x + cell_size / 2
        local fy = effect.data.from_y + cell_size / 2
        local tx = effect.center_x + cell_size / 2
        local ty = effect.center_y + cell_size / 2

        love.graphics.setLineWidth(3)
        love.graphics.line(fx, fy, tx, ty)
        love.graphics.setLineWidth(1)
    end
end

-- 护盾特效
function Animation:draw_shield_effect(effect, progress, cell_size)
    local alpha = 1 - progress
    local scale = 1 + progress * 0.3

    love.graphics.setColor(0.3, 0.6, 1, alpha * 0.6)
    love.graphics.setLineWidth(3)

    local cx = effect.center_x + cell_size / 2
    local cy = effect.center_y + cell_size / 2
    local radius = cell_size / 2 * scale

    love.graphics.circle("line", cx, cy, radius)
    love.graphics.setLineWidth(1)
end

-- 吸血特效
function Animation:draw_lifesteal_effect(effect, progress, cell_size)
    local alpha = 1 - progress

    love.graphics.setColor(0.8, 0.2, 0.2, alpha * 0.5)

    local cx = effect.center_x + cell_size / 2
    local cy = effect.center_y + cell_size / 2

    -- 粒子向中心汇聚
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local dist = cell_size * (1 - progress)
        local px = cx + math.cos(angle) * dist
        local py = cy + math.sin(angle) * dist
        love.graphics.circle("fill", px, py, 3)
    end
end

-- 清空技能特效
function Animation:clear_skill_effects()
    self.skill_effects = {}
end

-------------------------------------------------
-- 事件系统集成
-------------------------------------------------

-- 添加延迟执行
function Animation:after(delay, func)
    return self.event_manager:add_after(delay, func)
end

-- 添加缓动动画
function Animation:ease(args)
    return self.event_manager:add_ease(args)
end

-- 添加条件等待
function Animation:wait_until(condition, func)
    return self.event_manager:add_condition(condition, func)
end

-------------------------------------------------
-- 主更新和绘制
-------------------------------------------------

-- 更新所有动画
function Animation:update(dt)
    -- 更新事件队列
    self.event_manager:update(dt)

    -- 更新各类动画
    self:update_damage_texts(dt)
    self:update_screen_shake(dt)
    self:update_skill_effects(dt)
end

-- 清空所有动画
function Animation:clear_all()
    self.event_manager:clear_all()
    self:clear_damage_texts()
    self:clear_skill_effects()
    self.screen_shake = {
        intensity = 0,
        timer = 0,
        offset_x = 0,
        offset_y = 0,
    }
end

return Animation
