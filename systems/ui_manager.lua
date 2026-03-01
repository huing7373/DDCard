-- systems/ui_manager.lua
-- UI 管理系统
-- 声明式 UI 定义和渲染

local Object = require("engine.object")
local Moveable = require("engine.moveable")

-------------------------------------------------
-- UIElement 基类
-------------------------------------------------
local UIElement = Moveable:extend()
UIElement.__type = "UIElement"

function UIElement:init(args)
    args = args or {}

    Moveable.init(self, args)

    -- 基本属性
    self.id = args.id
    self.visible = args.visible ~= false
    self.enabled = args.enabled ~= false
    self.parent = nil
    self.children = {}

    -- 尺寸
    self.width = args.width or 100
    self.height = args.height or 30

    -- 样式
    self.style = args.style or {}

    -- 事件回调
    self.on_click = args.on_click
    self.on_hover = args.on_hover
    self.on_hover_end = args.on_hover_end

    -- 状态
    self.hovered = false
    self.pressed = false

    -- 注册到全局 UI 追踪
    if G and G.I and G.I.UI then
        table.insert(G.I.UI, self)
    end
end

-- 添加子元素
function UIElement:add_child(child)
    child.parent = self
    table.insert(self.children, child)
    return child
end

-- 移除子元素
function UIElement:remove_child(child)
    for i, c in ipairs(self.children) do
        if c == child then
            table.remove(self.children, i)
            child.parent = nil
            return true
        end
    end
    return false
end

-- 获取绝对位置
function UIElement:get_absolute_pos()
    local x, y = self.VT.x, self.VT.y
    if self.parent then
        local px, py = self.parent:get_absolute_pos()
        x = x + px
        y = y + py
    end
    return x, y
end

-- 检查点是否在元素内
function UIElement:contains_point(px, py)
    local x, y = self:get_absolute_pos()
    return px >= x and px <= x + self.width and
           py >= y and py <= y + self.height
end

-- 更新元素
function UIElement:update(dt)
    self:move(dt)

    for _, child in ipairs(self.children) do
        child:update(dt)
    end
end

-- 绘制元素 (子类重写)
function UIElement:draw()
    if not self.visible then return end

    -- 绘制子元素
    for _, child in ipairs(self.children) do
        child:draw()
    end
end

-- 处理鼠标移动
function UIElement:handle_mouse_move(mx, my)
    if not self.visible or not self.enabled then return end

    local was_hovered = self.hovered
    self.hovered = self:contains_point(mx, my)

    if self.hovered and not was_hovered then
        if self.on_hover then self.on_hover(self) end
    elseif not self.hovered and was_hovered then
        if self.on_hover_end then self.on_hover_end(self) end
    end

    for _, child in ipairs(self.children) do
        child:handle_mouse_move(mx, my)
    end
end

-- 处理鼠标点击
function UIElement:handle_mouse_click(mx, my, button)
    if not self.visible or not self.enabled then return false end

    -- 先检查子元素
    for i = #self.children, 1, -1 do
        if self.children[i]:handle_mouse_click(mx, my, button) then
            return true
        end
    end

    -- 检查自身
    if self:contains_point(mx, my) then
        if self.on_click then
            self.on_click(self, button)
            return true
        end
    end

    return false
end

-- 清理
function UIElement:remove()
    -- 移除子元素
    for _, child in ipairs(self.children) do
        child:remove()
    end
    self.children = {}

    -- 从父元素移除
    if self.parent then
        self.parent:remove_child(self)
    end

    -- 从全局追踪移除
    if G and G.I and G.I.UI then
        for i, v in ipairs(G.I.UI) do
            if v == self then
                table.remove(G.I.UI, i)
                break
            end
        end
    end

    Moveable.remove(self)
end

-------------------------------------------------
-- Button 按钮组件
-------------------------------------------------
local Button = UIElement:extend()
Button.__type = "Button"

function Button:init(args)
    args = args or {}
    UIElement.init(self, args)

    self.text = args.text or ""

    -- 默认样式
    self.style = {
        bg_color = args.bg_color or {0.25, 0.25, 0.35},
        hover_color = args.hover_color or {0.4, 0.4, 0.5},
        disabled_color = args.disabled_color or {0.15, 0.15, 0.15},
        border_color = args.border_color or {0.5, 0.5, 0.6},
        text_color = args.text_color or {1, 1, 1},
        disabled_text_color = args.disabled_text_color or {0.5, 0.5, 0.5},
        corner_radius = args.corner_radius or 5,
    }
end

function Button:draw()
    if not self.visible then return end

    local x, y = self:get_absolute_pos()
    local s = self.style

    -- 背景颜色
    local bg
    if not self.enabled then
        bg = s.disabled_color
    elseif self.hovered then
        bg = s.hover_color
    else
        bg = s.bg_color
    end

    -- 绘制背景
    love.graphics.setColor(bg[1], bg[2], bg[3], bg[4] or 1)
    love.graphics.rectangle("fill", x, y, self.width, self.height, s.corner_radius, s.corner_radius)

    -- 绘制边框
    love.graphics.setColor(s.border_color[1], s.border_color[2], s.border_color[3], s.border_color[4] or 1)
    love.graphics.rectangle("line", x, y, self.width, self.height, s.corner_radius, s.corner_radius)

    -- 绘制文字
    local text_color = self.enabled and s.text_color or s.disabled_text_color
    love.graphics.setColor(text_color[1], text_color[2], text_color[3])

    local font = love.graphics.getFont()
    local text_w = font:getWidth(self.text)
    local text_h = font:getHeight()
    love.graphics.print(self.text, x + (self.width - text_w) / 2, y + (self.height - text_h) / 2)

    UIElement.draw(self)
end

-------------------------------------------------
-- Panel 面板组件
-------------------------------------------------
local Panel = UIElement:extend()
Panel.__type = "Panel"

function Panel:init(args)
    args = args or {}
    UIElement.init(self, args)

    self.style = {
        bg_color = args.bg_color or {0.1, 0.1, 0.15, 0.9},
        border_color = args.border_color or {0.3, 0.3, 0.4},
        corner_radius = args.corner_radius or 5,
    }
end

function Panel:draw()
    if not self.visible then return end

    local x, y = self:get_absolute_pos()
    local s = self.style

    -- 绘制背景
    love.graphics.setColor(s.bg_color[1], s.bg_color[2], s.bg_color[3], s.bg_color[4] or 1)
    love.graphics.rectangle("fill", x, y, self.width, self.height, s.corner_radius, s.corner_radius)

    -- 绘制边框
    if s.border_color then
        love.graphics.setColor(s.border_color[1], s.border_color[2], s.border_color[3], s.border_color[4] or 1)
        love.graphics.rectangle("line", x, y, self.width, self.height, s.corner_radius, s.corner_radius)
    end

    UIElement.draw(self)
end

-------------------------------------------------
-- Label 文本组件
-------------------------------------------------
local Label = UIElement:extend()
Label.__type = "Label"

function Label:init(args)
    args = args or {}
    UIElement.init(self, args)

    self.text = args.text or ""
    self.align = args.align or "left"  -- left, center, right

    self.style = {
        text_color = args.text_color or {1, 1, 1},
    }
end

function Label:draw()
    if not self.visible then return end

    local x, y = self:get_absolute_pos()
    local s = self.style

    love.graphics.setColor(s.text_color[1], s.text_color[2], s.text_color[3], s.text_color[4] or 1)

    local font = love.graphics.getFont()
    local text_w = font:getWidth(self.text)

    local draw_x = x
    if self.align == "center" then
        draw_x = x + (self.width - text_w) / 2
    elseif self.align == "right" then
        draw_x = x + self.width - text_w
    end

    love.graphics.print(self.text, draw_x, y)

    UIElement.draw(self)
end

-------------------------------------------------
-- ProgressBar 进度条组件
-------------------------------------------------
local ProgressBar = UIElement:extend()
ProgressBar.__type = "ProgressBar"

function ProgressBar:init(args)
    args = args or {}
    UIElement.init(self, args)

    self.value = args.value or 0      -- 当前值
    self.max_value = args.max_value or 100  -- 最大值

    self.style = {
        bg_color = args.bg_color or {0.3, 0.3, 0.3},
        fg_color = args.fg_color or {0.2, 0.8, 0.2},
        border_color = args.border_color,
        corner_radius = args.corner_radius or 2,
    }
end

function ProgressBar:get_percent()
    if self.max_value == 0 then return 0 end
    return math.max(0, math.min(1, self.value / self.max_value))
end

function ProgressBar:draw()
    if not self.visible then return end

    local x, y = self:get_absolute_pos()
    local s = self.style
    local percent = self:get_percent()

    -- 背景
    love.graphics.setColor(s.bg_color[1], s.bg_color[2], s.bg_color[3], s.bg_color[4] or 1)
    love.graphics.rectangle("fill", x, y, self.width, self.height, s.corner_radius, s.corner_radius)

    -- 前景 (进度)
    if percent > 0 then
        love.graphics.setColor(s.fg_color[1], s.fg_color[2], s.fg_color[3], s.fg_color[4] or 1)
        love.graphics.rectangle("fill", x, y, self.width * percent, self.height, s.corner_radius, s.corner_radius)
    end

    -- 边框
    if s.border_color then
        love.graphics.setColor(s.border_color[1], s.border_color[2], s.border_color[3], s.border_color[4] or 1)
        love.graphics.rectangle("line", x, y, self.width, self.height, s.corner_radius, s.corner_radius)
    end

    UIElement.draw(self)
end

-------------------------------------------------
-- UIManager 管理器
-------------------------------------------------
local UIManager = Object:extend()
UIManager.__type = "UIManager"

local instance = nil

function UIManager:init()
    if instance then
        error("UIManager is a singleton, use UIManager.getInstance()")
    end

    self.root = Panel({
        x = 0, y = 0,
        width = 800, height = 600,
        bg_color = {0, 0, 0, 0},
        border_color = nil,
    })

    self.layers = {}  -- 命名层
end

function UIManager.getInstance()
    if not instance then
        instance = UIManager()
    end
    return instance
end

-- 创建层
function UIManager:create_layer(name)
    local layer = Panel({
        x = 0, y = 0,
        width = 800, height = 600,
        bg_color = {0, 0, 0, 0},
        border_color = nil,
    })
    self.layers[name] = layer
    self.root:add_child(layer)
    return layer
end

-- 获取层
function UIManager:get_layer(name)
    return self.layers[name]
end

-- 添加元素到层
function UIManager:add_to_layer(layer_name, element)
    local layer = self.layers[layer_name]
    if layer then
        layer:add_child(element)
    end
    return element
end

-- 创建按钮
function UIManager:create_button(args)
    return Button(args)
end

-- 创建面板
function UIManager:create_panel(args)
    return Panel(args)
end

-- 创建标签
function UIManager:create_label(args)
    return Label(args)
end

-- 创建进度条
function UIManager:create_progress_bar(args)
    return ProgressBar(args)
end

-- 更新所有 UI
function UIManager:update(dt)
    self.root:update(dt)
end

-- 绘制所有 UI
function UIManager:draw()
    self.root:draw()
end

-- 处理鼠标移动
function UIManager:handle_mouse_move(mx, my)
    self.root:handle_mouse_move(mx, my)
end

-- 处理鼠标点击
function UIManager:handle_mouse_click(mx, my, button)
    return self.root:handle_mouse_click(mx, my, button)
end

-- 清空所有 UI
function UIManager:clear()
    self.root:remove()
    self.root = Panel({
        x = 0, y = 0,
        width = 800, height = 600,
        bg_color = {0, 0, 0, 0},
        border_color = nil,
    })
    self.layers = {}
end

return {
    UIElement = UIElement,
    Button = Button,
    Panel = Panel,
    Label = Label,
    ProgressBar = ProgressBar,
    UIManager = UIManager,
}
