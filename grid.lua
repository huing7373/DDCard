-- Grid Management Module
-- Handle grid operations: creation, card placement, movement

local Grid = {}

-- Create a new empty grid
function Grid.new(size)
    local grid = {}
    for y = 1, size do
        grid[y] = {}
        for x = 1, size do
            grid[y][x] = {
                x = x,
                y = y,
                card = nil
            }
        end
    end
    return grid
end

-- Get card at position
function Grid.getCard(grid, x, y)
    if grid[y] and grid[y][x] then
        return grid[y][x].card
    end
    return nil
end

-- Get cell at position
function Grid.getCell(grid, x, y)
    if grid[y] and grid[y][x] then
        return grid[y][x]
    end
    return nil
end

-- Check if position is empty
function Grid.isEmpty(grid, x, y)
    local cell = Grid.getCell(grid, x, y)
    return cell and cell.card == nil
end

-- Place a card on the grid
function Grid.placeCard(grid, card, x, y)
    if not grid[y] or not grid[y][x] then
        return false
    end

    grid[y][x].card = card
    card.gridX = x
    card.gridY = y
    return true
end

-- Remove a card from the grid
function Grid.removeCard(grid, card)
    if grid[card.gridY] and grid[card.gridY][card.gridX] then
        grid[card.gridY][card.gridX].card = nil
        return true
    end
    return false
end

-- Move a card to a new position
function Grid.moveCard(grid, card, newX, newY)
    -- Remove from old position
    Grid.removeCard(grid, card)
    -- Place at new position
    return Grid.placeCard(grid, card, newX, newY)
end

-- Clear all cards from grid
function Grid.clear(grid, size)
    for y = 1, size do
        for x = 1, size do
            if grid[y] and grid[y][x] then
                grid[y][x].card = nil
            end
        end
    end
end

-- Get all cards in the grid
function Grid.getAllCards(grid, size)
    local cards = {}
    for y = 1, size do
        for x = 1, size do
            local card = Grid.getCard(grid, x, y)
            if card then
                table.insert(cards, card)
            end
        end
    end
    return cards
end

-- Find valid moves for a card in all directions
-- Returns two lists: moveTargets (empty cells) and attackTargets (enemy cells)
-- moveTargets includes attackPower for visual differentiation
function Grid.findTargets(grid, card, directions, gridSize)
    local moveTargets = {}
    local attackTargets = {}

    for dirKey, dir in pairs(directions) do
        local newX = card.gridX + dir.dx
        local newY = card.gridY + dir.dy
        local attackPower = card.attack[dirKey] or 0

        -- Check bounds
        if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
            local targetCell = grid[newY][newX]
            if targetCell.card == nil then
                -- Empty cell - can move (include attackPower for visual)
                table.insert(moveTargets, {
                    x = newX,
                    y = newY,
                    direction = dirKey,
                    attackPower = attackPower
                })
            elseif targetCell.card.type ~= card.type then
                -- Enemy card - can attack only if we have attack power
                if attackPower > 0 then
                    table.insert(attackTargets, {
                        x = newX,
                        y = newY,
                        direction = dirKey,
                        target = targetCell.card,
                        attackPower = attackPower
                    })
                end
            end
        end
    end

    return moveTargets, attackTargets
end

-- Check if position is valid and within bounds
function Grid.isValidPosition(x, y, gridSize)
    return x >= 1 and x <= gridSize and y >= 1 and y <= gridSize
end

-- Calculate Manhattan distance between two positions
function Grid.manhattanDistance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

return Grid
