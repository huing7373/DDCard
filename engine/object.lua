-- Object.lua
-- 轻量级 OOP 基类系统
-- 参考 Balatro 架构实现

local Object = {}
Object.__index = Object
Object.__type = "Object"

-- 创建子类
function Object:extend()
    local cls = {}
    for k, v in pairs(self) do
        if k:find("__") == 1 then
            cls[k] = v
        end
    end
    cls.__index = cls
    cls.__super = self
    setmetatable(cls, {
        __index = self,
        __call = function(c, ...)
            return c:new(...)
        end
    })
    return cls
end

-- 创建实例
function Object:new(...)
    local instance = setmetatable({}, self)
    instance:init(...)
    return instance
end

-- 构造函数 (子类重写)
function Object:init()
end

-- 类型检查
function Object:is(T)
    local mt = getmetatable(self)
    while mt do
        if mt == T then return true end
        mt = mt.__super
    end
    return false
end

-- 实例化语法糖
setmetatable(Object, {
    __call = function(cls, ...)
        return cls:new(...)
    end
})

return Object
