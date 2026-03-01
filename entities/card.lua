-- entities/card.lua
-- 卡牌实体类
-- 继承 Moveable 获得 T/VT 变换系统

local Moveable = require("engine.moveable")
local Config = require("config")

local Card = Moveable:extend()
Card.__type = "Card"

-- 卡牌类型
Card.TYPE = {
    PLAYER = "player",
    ENEMY = "enemy"
}

-- 网格位置转屏幕坐标
function Card.gridToScreen(gridX, gridY)
    local cellSize = Config.GRID.CELL_SIZE
    local offsetX = Config.GRID.OFFSET_X
    local offsetY = Config.GRID.OFFSET_Y
    return offsetX + (gridX - 1) * cellSize,
           offsetY + (gridY - 1) * cellSize
end

-- 创建新卡牌
function Card:init(params)
    params = params or {}

    -- 网格位置
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1

    -- 计算屏幕位置
    local screenX, screenY = Card.gridToScreen(self.gridX, self.gridY)

    -- 调用父类初始化 (设置 T/VT)
    Moveable.init(self, {
        x = screenX,
        y = screenY,
        lerp_speed = params.lerp_speed or 12
    })

    -- 基本属性
    self.name = params.name or "Unknown"
    self.type = params.type or Card.TYPE.ENEMY
    self.hp = params.hp or 10
    self.maxHp = params.maxHp or self.hp

    -- 8方向攻击力
    self.attack = params.attack or {
        n = 0, ne = 0, e = 0, se = 0,
        s = 0, sw = 0, w = 0, nw = 0
    }

    -- 技能列表
    self.skills = params.skills

    -- 移动属性
    self.moveType = params.moveType or Config.MOVE_TYPE.EIGHT_WAY
    self.moveRange = params.moveRange or 1
    self.moveMinRange = params.moveMinRange or 0

    -- 视觉效果状态
    self.flashTimer = 0
    self.shield = params.shield or 0

    -- 注册到全局卡牌追踪
    if G and G.I and G.I.CARD then
        table.insert(G.I.CARD, self)
    end
end

-- 设置网格位置 (触发平滑移动动画)
function Card:set_grid_pos(gridX, gridY)
    self.gridX = gridX
    self.gridY = gridY

    local screenX, screenY = Card.gridToScreen(gridX, gridY)
    self:set_T({x = screenX, y = screenY})
end

-- 立即设置网格位置 (无动画)
function Card:hard_set_grid_pos(gridX, gridY)
    self.gridX = gridX
    self.gridY = gridY

    local screenX, screenY = Card.gridToScreen(gridX, gridY)
    self:hard_set_T({x = screenX, y = screenY})
end

-- 更新卡牌 (包括动画和视觉效果)
function Card:update(dt)
    -- 更新位置插值
    self:move(dt)

    -- 更新闪烁效果
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        if self.flashTimer < 0 then
            self.flashTimer = 0
        end
    end
end

-- 触发受击闪烁
function Card:triggerFlash(duration)
    self.flashTimer = duration or 0.15
end

-- 绘制卡牌 (使用 VT 可见位置)
function Card:draw(cellX, cellY, cellSize)
    -- 如果提供了 cellX/cellY 就使用它们 (向后兼容)
    -- 否则使用 VT 位置
    local drawX = cellX or self.VT.x
    local drawY = cellY or self.VT.y
    local size = cellSize or Config.GRID.CELL_SIZE

    local padding = 5
    local cardX = drawX + padding
    local cardY = drawY + padding
    local cardW = size - padding * 2
    local cardH = size - padding * 2

    -- 绘制护盾光环边框
    if self.shield and self.shield > 0 then
        local time = love.timer.getTime()
        local glowIntensity = 0.5 + 0.3 * math.sin(time * Config.EFFECTS.SHIELD_GLOW_SPEED)
        local c = Config.COLORS.SHIELD_GLOW
        love.graphics.setColor(c[1], c[2], c[3], glowIntensity)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", cardX - 2, cardY - 2, cardW + 4, cardH + 4, 7, 7)
        love.graphics.setLineWidth(1)
    end

    -- 根据类型选择颜色
    if self.type == Card.TYPE.PLAYER then
        love.graphics.setColor(Config.COLORS.PLAYER_BG)
    else
        love.graphics.setColor(Config.COLORS.ENEMY_BG)
    end

    -- 绘制卡牌背景
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 5, 5)

    -- 受击闪烁覆盖层
    if self.flashTimer > 0 then
        love.graphics.setColor(1, 1, 1, self.flashTimer / 0.15 * 0.7)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 5, 5)
    end

    -- 绘制边框
    if self.type == Card.TYPE.PLAYER then
        love.graphics.setColor(Config.COLORS.PLAYER_BORDER)
    else
        love.graphics.setColor(Config.COLORS.ENEMY_BORDER)
    end
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 5, 5)

    -- 绘制名称（顶部居中）
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local nameX = cardX + cardW / 2 - font:getWidth(self.name) / 2
    love.graphics.print(self.name, nameX, cardY + 3)

    -- 绘制HP
    self:drawHP(cardX, cardY, cardW)

    -- 绘制8方向攻击力
    self:drawAttackDirections(cardX, cardY, cardW, cardH)

    -- 绘制护盾值
    if self.shield and self.shield > 0 then
        local shieldText = tostring(self.shield)
        love.graphics.setColor(Config.COLORS.SHIELD_GLOW)
        love.graphics.print(shieldText, cardX + cardW - font:getWidth(shieldText) - 3, cardY + 3)
    end
end

-- 绘制HP条和数值
function Card:drawHP(cardX, cardY, cardW)
    local hpBarY = cardY + 20
    local hpBarW = cardW - 10
    local hpBarH = 8
    local hpBarX = cardX + 5

    -- HP条背景
    love.graphics.setColor(Config.COLORS.HP_BAR_BG)
    love.graphics.rectangle("fill", hpBarX, hpBarY, hpBarW, hpBarH, 2, 2)

    -- HP条前景
    local hpPercent = self.hp / self.maxHp
    if hpPercent > 0.5 then
        love.graphics.setColor(Config.COLORS.HP_HIGH)
    elseif hpPercent > 0.25 then
        love.graphics.setColor(Config.COLORS.HP_MED)
    else
        love.graphics.setColor(Config.COLORS.HP_LOW)
    end
    love.graphics.rectangle("fill", hpBarX, hpBarY, hpBarW * hpPercent, hpBarH, 2, 2)

    -- HP数值
    love.graphics.setColor(1, 1, 1)
    local hpText = string.format("%d/%d", self.hp, self.maxHp)
    local font = love.graphics.getFont()
    local textX = cardX + cardW / 2 - font:getWidth(hpText) / 2
    love.graphics.print(hpText, textX, hpBarY + hpBarH + 2)
end

-- 绘制8方向攻击力
function Card:drawAttackDirections(cardX, cardY, cardW, cardH)
    local centerX = cardX + cardW / 2
    local centerY = cardY + cardH / 2 + 12
    local radius = 22

    local directions = {
        { key = "n",  dx = 0,              dy = -radius },
        { key = "ne", dx = radius * 0.7,   dy = -radius * 0.7 },
        { key = "e",  dx = radius,         dy = 0 },
        { key = "se", dx = radius * 0.7,   dy = radius * 0.7 },
        { key = "s",  dx = 0,              dy = radius },
        { key = "sw", dx = -radius * 0.7,  dy = radius * 0.7 },
        { key = "w",  dx = -radius,        dy = 0 },
        { key = "nw", dx = -radius * 0.7,  dy = -radius * 0.7 },
    }

    local font = love.graphics.getFont()

    for _, dir in ipairs(directions) do
        local atk = self.attack[dir.key]
        if atk > 0 then
            love.graphics.setColor(Config.COLORS.ATTACK_GOLD)
            local atkText = tostring(atk)
            local textW = font:getWidth(atkText)
            local textH = font:getHeight()
            love.graphics.print(atkText, centerX + dir.dx - textW / 2, centerY + dir.dy - textH / 2)
        else
            love.graphics.setColor(Config.COLORS.ATTACK_ZERO)
            love.graphics.circle("fill", centerX + dir.dx, centerY + dir.dy, 2)
        end
    end
end

-- 清理 (从全局追踪中移除)
function Card:remove()
    -- 调用父类移除
    Moveable.remove(self)

    -- 从卡牌追踪中移除
    if G and G.I and G.I.CARD then
        for i, v in ipairs(G.I.CARD) do
            if v == self then
                table.remove(G.I.CARD, i)
                break
            end
        end
    end
end

return Card
