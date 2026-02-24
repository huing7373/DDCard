-- AI Module
-- Enemy AI decision logic

local Config = require("config")
local Combat = require("combat")

local AI = {}

-- Calculate Manhattan distance
function AI.manhattanDistance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

-- Evaluate combat outcome for AI
function AI.evaluateCombat(attacker, defender, direction)
    return Combat.evaluateCombat(attacker, defender, direction, Config.DIRECTIONS)
end

-- Get best attack option
function AI.getBestAttack(enemy, attacks)
    if #attacks == 0 then return nil end

    local bestAttack = nil
    local bestScore = -999

    for _, attack in ipairs(attacks) do
        local score = AI.evaluateCombat(enemy, attack.target, attack.direction)
        if score > bestScore then
            bestScore = score
            bestAttack = attack
        end
    end

    -- Only attack if net damage is positive or can kill
    if bestScore >= 0 or (bestAttack and bestAttack.target.hp <= (enemy.attack[bestAttack.direction] or 0)) then
        return bestAttack
    end

    return nil
end

-- Get best move toward player
function AI.getBestMove(enemy, moves, playerX, playerY)
    if #moves == 0 then return nil end

    local bestMove = nil
    local bestDistance = 999

    for _, move in ipairs(moves) do
        local dist = AI.manhattanDistance(move.x, move.y, playerX, playerY)
        if dist < bestDistance then
            bestDistance = dist
            bestMove = move
        end
    end

    return bestMove
end

-- Decide enemy action
-- Returns: { type = "attack"/"move"/"wait", data = ... }
function AI.decideAction(enemy, game, Card)
    local moves = {}
    local attacks = {}
    local DIRECTIONS = Config.DIRECTIONS
    local gridSize = game.gridSize or Config.GRID.SIZE

    -- Collect available actions
    for dirKey, dir in pairs(DIRECTIONS) do
        local newX = enemy.gridX + dir.dx
        local newY = enemy.gridY + dir.dy

        if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
            local targetCell = game.grid[newY][newX]
            if targetCell.card == nil then
                table.insert(moves, { x = newX, y = newY, direction = dirKey })
            elseif targetCell.card.type == Card.TYPE.PLAYER then
                table.insert(attacks, {
                    x = newX,
                    y = newY,
                    direction = dirKey,
                    target = targetCell.card
                })
            end
        end
    end

    -- Priority: good attack opportunity
    local bestAttack = AI.getBestAttack(enemy, attacks)
    if bestAttack then
        return { type = "attack", data = bestAttack }
    end

    -- No good attack - try moving toward player
    if game.player and game.player.hp > 0 then
        local bestMove = AI.getBestMove(enemy, moves, game.player.gridX, game.player.gridY)
        if bestMove then
            return { type = "move", data = bestMove }
        end
    end

    -- Can't act
    return { type = "wait" }
end

return AI
