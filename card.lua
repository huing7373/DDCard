-- 卡牌模块
-- 定义卡牌数据结构和绘制方法

local Config = require("config")

local Card = {}
Card.__index = Card

-- 卡牌类型
Card.TYPE = {
    PLAYER = "player",
    ENEMY = "enemy"
}

-- 创建新卡牌
function Card.new(params)
    local self = setmetatable({}, Card)

    self.name = params.name or "Unknown"
    self.type = params.type or Card.TYPE.ENEMY
    self.hp = params.hp or 10
    self.maxHp = params.maxHp or self.hp

    -- 8方向攻击力 (上、右上、右、右下、下、左下、左、左上)
    self.attack = params.attack or {
        n = 0,   -- 上
        ne = 0,  -- 右上
        e = 0,   -- 右
        se = 0,  -- 右下
        s = 0,   -- 下
        sw = 0,  -- 左下
        w = 0,   -- 左
        nw = 0   -- 左上
    }

    -- 网格位置
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1

    -- 技能列表
    self.skills = params.skills

    -- Movement properties
    self.moveType = params.moveType or Config.MOVE_TYPE.EIGHT_WAY  -- 移动类型
    self.moveRange = params.moveRange or 1                          -- 移动范围(格数)
    self.moveMinRange = params.moveMinRange or 0                    -- 最小移动距离(跳跃类型用)

    -- Visual effect state
    self.flashTimer = 0  -- Flash when hit
    self.shield = params.shield or 0  -- Shield amount

    return self
end

-- Update card visual effects
function Card:update(dt)
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        if self.flashTimer < 0 then
            self.flashTimer = 0
        end
    end
end

-- Trigger hit flash effect
function Card:triggerFlash(duration)
    self.flashTimer = duration or 0.15
end

-- 绘制卡牌
function Card:draw(cellX, cellY, cellSize)
    local padding = 5
    local cardX = cellX + padding
    local cardY = cellY + padding
    local cardW = cellSize - padding * 2
    local cardH = cellSize - padding * 2

    -- Draw shield glow border if has shield
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

    -- Flash overlay when hit
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

    -- 绘制HP（名称下方）
    self:drawHP(cardX, cardY, cardW)

    -- 绘制8方向攻击力
    self:drawAttackDirections(cardX, cardY, cardW, cardH)

    -- Draw shield value if present
    if self.shield and self.shield > 0 then
        local font = love.graphics.getFont()
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
    local centerY = cardY + cardH / 2 + 12  -- 稍微下移以避开HP条
    local radius = 22  -- 攻击数字距离中心的半径

    -- 8个方向的偏移 (相对于中心)
    local directions = {
        { key = "n",  dx = 0,      dy = -radius },
        { key = "ne", dx = radius * 0.7, dy = -radius * 0.7 },
        { key = "e",  dx = radius, dy = 0 },
        { key = "se", dx = radius * 0.7, dy = radius * 0.7 },
        { key = "s",  dx = 0,      dy = radius },
        { key = "sw", dx = -radius * 0.7, dy = radius * 0.7 },
        { key = "w",  dx = -radius, dy = 0 },
        { key = "nw", dx = -radius * 0.7, dy = -radius * 0.7 },
    }

    local font = love.graphics.getFont()

    for _, dir in ipairs(directions) do
        local atk = self.attack[dir.key]
        if atk > 0 then
            -- 攻击力大于0时显示
            love.graphics.setColor(Config.COLORS.ATTACK_GOLD)
            local atkText = tostring(atk)
            local textW = font:getWidth(atkText)
            local textH = font:getHeight()
            love.graphics.print(atkText, centerX + dir.dx - textW / 2, centerY + dir.dy - textH / 2)
        else
            -- 攻击力为0时显示灰色点
            love.graphics.setColor(Config.COLORS.ATTACK_ZERO)
            love.graphics.circle("fill", centerX + dir.dx, centerY + dir.dy, 2)
        end
    end
end

return Card
