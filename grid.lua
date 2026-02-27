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

-- Find valid moves for a card based on movement type configuration
-- Supports: eight_way, cross, diagonal, cross_jump, diagonal_jump
-- Returns list of move targets with x, y, direction, attackPower, and distance
function Grid.findTargetsWithMoveType(grid, card, allDirections, gridSize, Config)
    local moveTargets = {}
    local attackTargets = {}

    local moveType = card.moveType or Config.MOVE_TYPE.EIGHT_WAY
    local moveRange = card.moveRange or 1
    local moveMinRange = card.moveMinRange or 0

    -- Get direction set for this move type
    local directionKeys
    if moveType == Config.MOVE_TYPE.EIGHT_WAY then
        directionKeys = Config.DIRECTION_SETS.eight_way
    elseif moveType == Config.MOVE_TYPE.CROSS or moveType == Config.MOVE_TYPE.CROSS_JUMP then
        directionKeys = Config.DIRECTION_SETS.cross
    elseif moveType == Config.MOVE_TYPE.DIAGONAL or moveType == Config.MOVE_TYPE.DIAGONAL_JUMP then
        directionKeys = Config.DIRECTION_SETS.diagonal
    else
        directionKeys = Config.DIRECTION_SETS.eight_way
    end

    -- Check if this is a jump type (skips adjacent cells)
    local isJumpType = (moveType == Config.MOVE_TYPE.CROSS_JUMP or moveType == Config.MOVE_TYPE.DIAGONAL_JUMP)

    -- Calculate effective min range (jump types skip at least 1 cell)
    local effectiveMinRange = moveMinRange
    if isJumpType and effectiveMinRange < 1 then
        effectiveMinRange = 1
    end

    -- Iterate through allowed directions
    for _, dirKey in ipairs(directionKeys) do
        local dir = allDirections[dirKey]
        if dir then
            -- Check each distance from min to max range
            for dist = 1, moveRange do
                local newX = card.gridX + dir.dx * dist
                local newY = card.gridY + dir.dy * dist
                local attackPower = card.attack[dirKey] or 0

                -- Check bounds
                if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
                    local targetCell = grid[newY][newX]

                    -- Check if path is blocked (for non-jump types, need clear path)
                    local pathBlocked = false
                    if not isJumpType and dist > 1 then
                        for checkDist = 1, dist - 1 do
                            local checkX = card.gridX + dir.dx * checkDist
                            local checkY = card.gridY + dir.dy * checkDist
                            if checkX >= 1 and checkX <= gridSize and checkY >= 1 and checkY <= gridSize then
                                local checkCell = grid[checkY][checkX]
                                if checkCell.card ~= nil then
                                    pathBlocked = true
                                    break
                                end
                            end
                        end
                    end

                    if not pathBlocked then
                        -- Check if distance is within allowed range (considering min range for jumps)
                        local withinRange = dist >= (effectiveMinRange + 1) or (not isJumpType and dist >= 1)

                        if isJumpType then
                            -- For jump types, only allow tiles beyond the adjacent one
                            withinRange = dist > 1
                        end

                        if withinRange then
                            if targetCell.card == nil then
                                -- Empty cell - can move
                                table.insert(moveTargets, {
                                    x = newX,
                                    y = newY,
                                    direction = dirKey,
                                    attackPower = attackPower,
                                    distance = dist
                                })
                            elseif targetCell.card.type ~= card.type then
                                -- Enemy card - can attack only if we have attack power
                                if attackPower > 0 then
                                    table.insert(attackTargets, {
                                        x = newX,
                                        y = newY,
                                        direction = dirKey,
                                        target = targetCell.card,
                                        attackPower = attackPower,
                                        distance = dist
                                    })
                                end
                            end
                        end
                    end

                    -- For non-jump types, stop at first obstacle
                    if not isJumpType and targetCell.card ~= nil then
                        break
                    end
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
