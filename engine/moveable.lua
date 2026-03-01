-- Moveable.lua
-- 可移动实体基类
-- 实现 T/VT 变换系统用于平滑动画

local Object = require("engine.object")

local Moveable = Object:extend()
Moveable.__type = "Moveable"

-- 默认插值速度
Moveable.LERP_SPEED = 10

function Moveable:init(args)
    args = args or {}

    -- T: 目标变换 (逻辑位置)
    self.T = {
        x = args.x or 0,
        y = args.y or 0,
        r = args.r or 0,      -- 旋转
        sx = args.sx or 1,    -- X缩放
        sy = args.sy or 1,    -- Y缩放
    }

    -- VT: 可见变换 (渲染位置，插值到 T)
    self.VT = {
        x = self.T.x,
        y = self.T.y,
        r = self.T.r,
        sx = self.T.sx,
        sy = self.T.sy,
    }

    -- 插值速度系数
    self.lerp_speed = args.lerp_speed or Moveable.LERP_SPEED

    -- 注册到全局实例追踪
    if G and G.I and G.I.MOVEABLE then
        table.insert(G.I.MOVEABLE, self)
        self._registered = true
    end
end

-- 更新可见位置 (平滑插值)
function Moveable:move(dt)
    local speed = self.lerp_speed * dt

    -- 限制最大插值量防止过冲
    speed = math.min(speed, 1)

    -- 对各属性进行线性插值
    self.VT.x = self:lerp(self.VT.x, self.T.x, speed)
    self.VT.y = self:lerp(self.VT.y, self.T.y, speed)
    self.VT.r = self:lerp(self.VT.r, self.T.r, speed)
    self.VT.sx = self:lerp(self.VT.sx, self.T.sx, speed)
    self.VT.sy = self:lerp(self.VT.sy, self.T.sy, speed)
end

-- 立即设置位置 (跳过插值)
function Moveable:hard_set_T(args)
    args = args or {}

    if args.x then self.T.x = args.x end
    if args.y then self.T.y = args.y end
    if args.r then self.T.r = args.r end
    if args.sx then self.T.sx = args.sx end
    if args.sy then self.T.sy = args.sy end

    -- 同步 VT 到 T
    self.VT.x = self.T.x
    self.VT.y = self.T.y
    self.VT.r = self.T.r
    self.VT.sx = self.T.sx
    self.VT.sy = self.T.sy
end

-- 设置目标位置 (会触发插值动画)
function Moveable:set_T(args)
    args = args or {}

    if args.x then self.T.x = args.x end
    if args.y then self.T.y = args.y end
    if args.r then self.T.r = args.r end
    if args.sx then self.T.sx = args.sx end
    if args.sy then self.T.sy = args.sy end
end

-- 检查是否到达目标位置
function Moveable:is_at_target(threshold)
    threshold = threshold or 0.1

    return math.abs(self.VT.x - self.T.x) < threshold
        and math.abs(self.VT.y - self.T.y) < threshold
        and math.abs(self.VT.r - self.T.r) < threshold
        and math.abs(self.VT.sx - self.T.sx) < threshold
        and math.abs(self.VT.sy - self.T.sy) < threshold
end

-- 线性插值辅助函数
function Moveable:lerp(a, b, t)
    return a + (b - a) * t
end

-- 清理 (从全局追踪中移除)
function Moveable:remove()
    if self._registered and G and G.I and G.I.MOVEABLE then
        for i, v in ipairs(G.I.MOVEABLE) do
            if v == self then
                table.remove(G.I.MOVEABLE, i)
                break
            end
        end
        self._registered = false
    end
end

return Moveable
