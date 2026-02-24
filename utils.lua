-- Utility Functions Module
-- Common helper functions used across the game

local Utils = {}

-- Find an element in a list using a predicate function
-- Returns the item and its index, or nil if not found
function Utils.findInList(list, predicate)
    for i, item in ipairs(list) do
        if predicate(item) then
            return item, i
        end
    end
    return nil
end

-- Check if coordinates exist in a target list
-- Returns true/false and the target if found
function Utils.isInTargetList(x, y, targetList)
    for _, target in ipairs(targetList) do
        if target.x == x and target.y == y then
            return true, target
        end
    end
    return false
end

-- Check if coordinates are within grid bounds
function Utils.isValidGridPosition(x, y, gridSize)
    return x >= 1 and x <= gridSize and y >= 1 and y <= gridSize
end

-- Check if a point is inside a rectangle
function Utils.isPointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Remove an element from a list by value
-- Returns true if element was removed
function Utils.removeFromList(list, element)
    for i, item in ipairs(list) do
        if item == element then
            table.remove(list, i)
            return true
        end
    end
    return false
end

-- Deep copy a table (for copying attack tables, etc.)
function Utils.deepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for key, value in pairs(orig) do
            copy[Utils.deepCopy(key)] = Utils.deepCopy(value)
        end
    else
        copy = orig
    end
    return copy
end

-- Clamp a value between min and max
function Utils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- Calculate screen coordinates from grid position
function Utils.gridToScreen(gridX, gridY, offsetX, offsetY, cellSize)
    local screenX = offsetX + (gridX - 1) * cellSize
    local screenY = offsetY + (gridY - 1) * cellSize
    return screenX, screenY
end

-- Calculate grid position from screen coordinates
-- Returns nil if outside grid
function Utils.screenToGrid(screenX, screenY, offsetX, offsetY, cellSize, gridSize)
    local gridX = math.floor((screenX - offsetX) / cellSize) + 1
    local gridY = math.floor((screenY - offsetY) / cellSize) + 1

    if Utils.isValidGridPosition(gridX, gridY, gridSize) then
        return gridX, gridY
    end
    return nil
end

-- Get center screen position of a grid cell
function Utils.getGridCellCenter(gridX, gridY, offsetX, offsetY, cellSize)
    local screenX = offsetX + (gridX - 1) * cellSize + cellSize / 2
    local screenY = offsetY + (gridY - 1) * cellSize + cellSize / 2
    return screenX, screenY
end

-- Pick a random element from a list
function Utils.randomChoice(list)
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

-- Pick a random key from DIRECTION_KEYS
function Utils.randomDirection(directionKeys)
    return directionKeys[math.random(#directionKeys)]
end

return Utils
