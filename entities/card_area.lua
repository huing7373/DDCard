-- entities/card_area.lua
-- 卡牌区域容器类
-- 管理一组卡牌的容器

local Moveable = require("engine.moveable")

local CardArea = Moveable:extend()
CardArea.__type = "CardArea"

function CardArea:init(args)
    args = args or {}

    -- 调用父类初始化
    Moveable.init(self, args)

    -- 卡牌列表
    self.cards = {}

    -- 区域属性
    self.card_limit = args.card_limit or math.huge  -- 卡牌数量上限
    self.card_width = args.card_width or 90         -- 卡牌宽度
    self.card_height = args.card_height or 90       -- 卡牌高度
    self.card_spacing = args.card_spacing or 10     -- 卡牌间距

    -- 布局类型
    self.layout = args.layout or "horizontal"  -- horizontal, vertical, grid
end

-- 添加卡牌到区域
function CardArea:add_card(card, index)
    if #self.cards >= self.card_limit then
        return false, "Area is full"
    end

    -- 设置卡牌的所属区域
    card.area = self

    if index then
        table.insert(self.cards, index, card)
    else
        table.insert(self.cards, card)
    end

    -- 重新计算卡牌位置
    self:realign()

    return true
end

-- 从区域移除卡牌
function CardArea:remove_card(card)
    for i, c in ipairs(self.cards) do
        if c == card then
            table.remove(self.cards, i)
            card.area = nil
            self:realign()
            return true
        end
    end
    return false
end

-- 根据索引移除卡牌
function CardArea:remove_card_at(index)
    if index < 1 or index > #self.cards then
        return nil
    end

    local card = table.remove(self.cards, index)
    if card then
        card.area = nil
        self:realign()
    end
    return card
end

-- 获取卡牌数量
function CardArea:count()
    return #self.cards
end

-- 检查是否为空
function CardArea:is_empty()
    return #self.cards == 0
end

-- 检查是否已满
function CardArea:is_full()
    return #self.cards >= self.card_limit
end

-- 获取指定索引的卡牌
function CardArea:get_card(index)
    return self.cards[index]
end

-- 查找卡牌索引
function CardArea:find_card(card)
    for i, c in ipairs(self.cards) do
        if c == card then
            return i
        end
    end
    return nil
end

-- 遍历所有卡牌
function CardArea:foreach(func)
    for i, card in ipairs(self.cards) do
        func(card, i)
    end
end

-- 筛选卡牌
function CardArea:filter(predicate)
    local result = {}
    for _, card in ipairs(self.cards) do
        if predicate(card) then
            table.insert(result, card)
        end
    end
    return result
end

-- 重新排列卡牌位置
function CardArea:realign()
    local count = #self.cards

    if count == 0 then return end

    if self.layout == "horizontal" then
        self:realign_horizontal()
    elseif self.layout == "vertical" then
        self:realign_vertical()
    elseif self.layout == "grid" then
        self:realign_grid()
    end
end

-- 水平布局
function CardArea:realign_horizontal()
    local total_width = #self.cards * self.card_width + (#self.cards - 1) * self.card_spacing
    local start_x = self.T.x - total_width / 2 + self.card_width / 2

    for i, card in ipairs(self.cards) do
        local x = start_x + (i - 1) * (self.card_width + self.card_spacing)
        card:set_T({x = x, y = self.T.y})
    end
end

-- 垂直布局
function CardArea:realign_vertical()
    local total_height = #self.cards * self.card_height + (#self.cards - 1) * self.card_spacing
    local start_y = self.T.y - total_height / 2 + self.card_height / 2

    for i, card in ipairs(self.cards) do
        local y = start_y + (i - 1) * (self.card_height + self.card_spacing)
        card:set_T({x = self.T.x, y = y})
    end
end

-- 网格布局
function CardArea:realign_grid()
    local cols = self.cols or 5
    local rows = math.ceil(#self.cards / cols)

    local total_width = cols * self.card_width + (cols - 1) * self.card_spacing
    local total_height = rows * self.card_height + (rows - 1) * self.card_spacing
    local start_x = self.T.x - total_width / 2 + self.card_width / 2
    local start_y = self.T.y - total_height / 2 + self.card_height / 2

    for i, card in ipairs(self.cards) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = start_x + col * (self.card_width + self.card_spacing)
        local y = start_y + row * (self.card_height + self.card_spacing)
        card:set_T({x = x, y = y})
    end
end

-- 更新区域和所有卡牌
function CardArea:update(dt)
    -- 更新自身位置
    self:move(dt)

    -- 更新所有卡牌
    for _, card in ipairs(self.cards) do
        card:update(dt)
    end
end

-- 绘制区域和所有卡牌
function CardArea:draw()
    -- 可选：绘制区域背景
    -- love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
    -- love.graphics.rectangle("fill", self.VT.x, self.VT.y, width, height)

    -- 绘制所有卡牌
    for _, card in ipairs(self.cards) do
        card:draw()
    end
end

-- 清空区域
function CardArea:clear()
    for _, card in ipairs(self.cards) do
        card.area = nil
    end
    self.cards = {}
end

-- 清理
function CardArea:remove()
    self:clear()
    Moveable.remove(self)
end

return CardArea
