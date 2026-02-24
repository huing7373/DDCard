-- UI Components Module
-- Unified button and UI element rendering and interaction

local UI = {}

-- Create a button definition
function UI.createButton(x, y, w, h, text, action)
    return {
        x = x,
        y = y,
        w = w,
        h = h,
        text = text,
        action = action,
        enabled = true
    }
end

-- Check if mouse is hovering over a button
function UI.isButtonHovered(btn, mx, my)
    return mx >= btn.x and mx <= btn.x + btn.w and
           my >= btn.y and my <= btn.y + btn.h
end

-- Draw a single button
function UI.drawButton(btn, isHovered, isDisabled, colors)
    colors = colors or {}
    local bgColor = colors.bg or {0.25, 0.25, 0.35}
    local hoverColor = colors.hover or {0.4, 0.4, 0.5}
    local disabledColor = colors.disabled or {0.15, 0.15, 0.15}
    local borderColor = colors.border or {0.5, 0.5, 0.6}
    local textColor = colors.text or {1, 1, 1}
    local disabledTextColor = colors.disabledText or {0.5, 0.5, 0.5}
    local cornerRadius = colors.cornerRadius or 5

    -- Button background
    if isDisabled then
        love.graphics.setColor(disabledColor[1], disabledColor[2], disabledColor[3], disabledColor[4] or 1)
    elseif isHovered then
        love.graphics.setColor(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4] or 1)
    else
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, cornerRadius, cornerRadius)

    -- Button border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, cornerRadius, cornerRadius)

    -- Button text (centered)
    if isDisabled then
        love.graphics.setColor(disabledTextColor[1], disabledTextColor[2], disabledTextColor[3])
    else
        love.graphics.setColor(textColor[1], textColor[2], textColor[3])
    end

    local font = love.graphics.getFont()
    local textW = font:getWidth(btn.text)
    local textH = font:getHeight()
    love.graphics.print(btn.text, btn.x + (btn.w - textW) / 2, btn.y + (btn.h - textH) / 2)
end

-- Draw multiple buttons
function UI.drawButtons(buttons, mx, my, colors)
    for _, btn in ipairs(buttons) do
        local hovered = UI.isButtonHovered(btn, mx, my)
        local disabled = btn.enabled == false
        UI.drawButton(btn, hovered, disabled, colors)
    end
end

-- Handle button click, returns true if a button was clicked
function UI.handleButtonClick(buttons, mx, my)
    for _, btn in ipairs(buttons) do
        if btn.enabled ~= false and UI.isButtonHovered(btn, mx, my) and btn.action then
            btn.action()
            return true
        end
    end
    return false
end

-- Draw a panel background
function UI.drawPanel(x, y, w, h, bgColor, borderColor, cornerRadius)
    cornerRadius = cornerRadius or 5

    -- Background
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    love.graphics.rectangle("fill", x, y, w, h, cornerRadius, cornerRadius)

    -- Border
    if borderColor then
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
        love.graphics.rectangle("line", x, y, w, h, cornerRadius, cornerRadius)
    end
end

-- Draw centered text
function UI.drawCenteredText(text, x, y, w, color)
    if color then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    end
    local font = love.graphics.getFont()
    local textW = font:getWidth(text)
    love.graphics.print(text, x + (w - textW) / 2, y)
end

-- Draw a semi-transparent overlay
function UI.drawOverlay(alpha)
    alpha = alpha or 0.7
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
end

-- Draw a progress bar
function UI.drawProgressBar(x, y, w, h, percent, fgColor, bgColor, cornerRadius)
    cornerRadius = cornerRadius or 2

    -- Background
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    love.graphics.rectangle("fill", x, y, w, h, cornerRadius, cornerRadius)

    -- Foreground (progress)
    if percent > 0 then
        love.graphics.setColor(fgColor[1], fgColor[2], fgColor[3], fgColor[4] or 1)
        love.graphics.rectangle("fill", x, y, w * percent, h, cornerRadius, cornerRadius)
    end
end

-- Get color based on percentage (for HP bars, etc.)
function UI.getPercentColor(percent)
    if percent > 0.5 then
        return {0.2, 0.8, 0.2}  -- Green
    elseif percent > 0.25 then
        return {0.8, 0.8, 0.2}  -- Yellow
    else
        return {0.8, 0.2, 0.2}  -- Red
    end
end

return UI
