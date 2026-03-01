-- 卡牌模块
-- 兼容层：重新导出 entities/card.lua
-- 保持向后兼容 Card.new() API

local CardEntity = require("entities.card")

-- 兼容层：Card.new(params) 调用 CardEntity:new(params)
local Card = {}
setmetatable(Card, {
    __index = CardEntity,
    __call = function(_, params)
        return CardEntity:new(params)
    end
})

-- 保留 Card.new() 兼容 API
function Card.new(params)
    return CardEntity:new(params)
end

-- 复制类型常量
Card.TYPE = CardEntity.TYPE

-- 复制静态方法
Card.gridToScreen = CardEntity.gridToScreen

return Card
