-- 卡牌模块
-- 定义卡牌数据结构和绘制方法

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

    return self
end

-- 绘制卡牌
function Card:draw(cellX, cellY, cellSize)
    local padding = 5
    local cardX = cellX + padding
    local cardY = cellY + padding
    local cardW = cellSize - padding * 2
    local cardH = cellSize - padding * 2

    -- 根据类型选择颜色
    if self.type == Card.TYPE.PLAYER then
        love.graphics.setColor(0.2, 0.4, 0.8)  -- 蓝色-玩家
    else
        love.graphics.setColor(0.7, 0.2, 0.2)  -- 红色-敌人
    end

    -- 绘制卡牌背景
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 5, 5)

    -- 绘制边框
    if self.type == Card.TYPE.PLAYER then
        love.graphics.setColor(0.3, 0.6, 1)
    else
        love.graphics.setColor(1, 0.3, 0.3)
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
end

-- 绘制HP条和数值
function Card:drawHP(cardX, cardY, cardW)
    local hpBarY = cardY + 20
    local hpBarW = cardW - 10
    local hpBarH = 8
    local hpBarX = cardX + 5

    -- HP条背景
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", hpBarX, hpBarY, hpBarW, hpBarH, 2, 2)

    -- HP条前景
    local hpPercent = self.hp / self.maxHp
    if hpPercent > 0.5 then
        love.graphics.setColor(0.2, 0.8, 0.2)  -- 绿色
    elseif hpPercent > 0.25 then
        love.graphics.setColor(0.8, 0.8, 0.2)  -- 黄色
    else
        love.graphics.setColor(0.8, 0.2, 0.2)  -- 红色
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
            love.graphics.setColor(1, 0.9, 0.3)  -- 金色
            local atkText = tostring(atk)
            local textW = font:getWidth(atkText)
            local textH = font:getHeight()
            love.graphics.print(atkText, centerX + dir.dx - textW / 2, centerY + dir.dy - textH / 2)
        else
            -- 攻击力为0时显示灰色点
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.circle("fill", centerX + dir.dx, centerY + dir.dy, 2)
        end
    end
end

return Card
