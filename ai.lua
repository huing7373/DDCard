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
        -- Prefer attacks with higher damage output
        local damage = enemy.attack[attack.direction] or 0
        score = score + damage  -- Bonus for dealing damage
        if score > bestScore then
            bestScore = score
            bestAttack = attack
        end
    end

    -- Always attack if we can deal damage, be more aggressive
    if bestAttack then
        local damage = enemy.attack[bestAttack.direction] or 0
        if damage > 0 then
            return bestAttack
        end
    end

    return nil
end

-- Count adjacent enemies (targets) for skill evaluation
function AI.countAdjacentTargets(enemy, game, Card)
    local count = 0
    local DIRECTIONS = Config.DIRECTIONS
    local gridSize = game.gridSize or Config.GRID.SIZE

    for _, dir in pairs(DIRECTIONS) do
        local newX = enemy.gridX + dir.dx
        local newY = enemy.gridY + dir.dy

        if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
            local targetCell = game.grid[newY][newX]
            if targetCell.card and targetCell.card.type == Card.TYPE.PLAYER then
                count = count + 1
            end
        end
    end

    return count
end

-- Check if enemy can attack player directly
function AI.canAttackPlayerDirectly(enemy, game, Card)
    local DIRECTIONS = Config.DIRECTIONS
    local gridSize = game.gridSize or Config.GRID.SIZE

    for _, dir in pairs(DIRECTIONS) do
        local newX = enemy.gridX + dir.dx
        local newY = enemy.gridY + dir.dy

        if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
            local targetCell = game.grid[newY][newX]
            if targetCell.card and targetCell.card.type == Card.TYPE.PLAYER then
                return true
            end
        end
    end

    return false
end

-- Check if charge can reach player (2 tiles away in a direction)
function AI.canChargeToPlayer(enemy, game, Card)
    local DIRECTIONS = Config.DIRECTIONS
    local gridSize = game.gridSize or Config.GRID.SIZE

    for dirKey, dir in pairs(DIRECTIONS) do
        -- Check 2 tiles in this direction
        local x1 = enemy.gridX + dir.dx
        local y1 = enemy.gridY + dir.dy
        local x2 = enemy.gridX + dir.dx * 2
        local y2 = enemy.gridY + dir.dy * 2

        -- First tile must be empty, second tile must have player
        if x1 >= 1 and x1 <= gridSize and y1 >= 1 and y1 <= gridSize and
           x2 >= 1 and x2 <= gridSize and y2 >= 1 and y2 <= gridSize then
            local cell1 = game.grid[y1][x1]
            local cell2 = game.grid[y2][x2]
            if cell1.card == nil and cell2.card and cell2.card.type == Card.TYPE.PLAYER then
                return true, dirKey
            end
        end
    end

    return false, nil
end

-- Get best skill for enemy to use
-- Returns: { skill = skillInstance, direction = dirKey } or nil
function AI.getBestSkill(enemy, game, Card)
    if not enemy.skills then return nil end

    local hpPercent = enemy.hp / enemy.maxHp
    local adjacentTargets = AI.countAdjacentTargets(enemy, game, Card)
    local canAttackDirectly = AI.canAttackPlayerDirectly(enemy, game, Card)

    for _, skill in ipairs(enemy.skills) do
        if skill.currentCooldown == 0 then
            -- Shield: use when HP below threshold
            if skill.id == "shield" and hpPercent < Config.AI.SHIELD_HP_THRESHOLD then
                return { skill = skill, direction = nil }
            end

            -- Whirlwind: use when adjacent to player (counts as 1+ target)
            if skill.id == "whirlwind" and adjacentTargets >= 1 then
                return { skill = skill, direction = nil }
            end

            -- Charge: use when can't attack directly but can charge to reach
            if skill.id == "charge" and not canAttackDirectly then
                local canCharge, chargeDir = AI.canChargeToPlayer(enemy, game, Card)
                if canCharge then
                    return { skill = skill, direction = chargeDir }
                end
            end

            -- Lifesteal: use when HP below threshold and adjacent to player
            if skill.id == "lifesteal" and hpPercent < Config.AI.LIFESTEAL_HP_THRESHOLD and adjacentTargets >= 1 then
                -- Find direction to player
                local DIRECTIONS = Config.DIRECTIONS
                local gridSize = game.gridSize or Config.GRID.SIZE
                for dirKey, dir in pairs(DIRECTIONS) do
                    local newX = enemy.gridX + dir.dx
                    local newY = enemy.gridY + dir.dy
                    if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
                        local targetCell = game.grid[newY][newX]
                        if targetCell.card and targetCell.card.type == Card.TYPE.PLAYER then
                            return { skill = skill, direction = dirKey }
                        end
                    end
                end
            end
        end
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

    -- Priority 1: Check for skill usage (emergency skills like shield, or high-value skills)
    local bestSkill = AI.getBestSkill(enemy, game, Card)
    if bestSkill then
        return { type = "skill", data = bestSkill }
    end

    -- Priority 2: Good attack opportunity
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
