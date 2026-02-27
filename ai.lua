-- AI Module
-- Enemy AI decision logic with state machine

local Config = require("config")
local Combat = require("combat")
local Grid = require("grid")

local AI = {}

-- AI State Machine states
local STATE = Config.AI_STATE

-- Calculate Manhattan distance
function AI.manhattanDistance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

-- Evaluate combat outcome for AI
function AI.evaluateCombat(attacker, defender, direction)
    return Combat.evaluateCombat(attacker, defender, direction, Config.DIRECTIONS)
end

-- Get direction from position to target
function AI.getDirectionFromTo(fromX, fromY, toX, toY)
    local dx = toX - fromX
    local dy = toY - fromY

    -- Normalize to direction
    if dx > 0 then dx = 1 elseif dx < 0 then dx = -1 end
    if dy > 0 then dy = 1 elseif dy < 0 then dy = -1 end

    -- Map to direction key
    for dirKey, dir in pairs(Config.DIRECTIONS) do
        if dir.dx == dx and dir.dy == dy then
            return dirKey
        end
    end
    return nil
end

-- Get player's highest and lowest attack directions
function AI.getPlayerAttackExtremes(player)
    local maxDir, maxAtk = nil, -1
    local minDir, minAtk = nil, 999

    for dirKey, atk in pairs(player.attack) do
        if atk > maxAtk then
            maxAtk = atk
            maxDir = dirKey
        end
        if atk < minAtk then
            minAtk = atk
            minDir = dirKey
        end
    end

    return maxDir, maxAtk, minDir, minAtk
end

-- Get opposite direction
function AI.getOppositeDirection(dirKey)
    local dir = Config.DIRECTIONS[dirKey]
    return dir and dir.opposite or nil
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

    for dirKey, dir in pairs(DIRECTIONS) do
        local newX = enemy.gridX + dir.dx
        local newY = enemy.gridY + dir.dy

        if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
            local targetCell = game.grid[newY][newX]
            if targetCell.card and targetCell.card.type == Card.TYPE.PLAYER then
                -- Check if we have attack power in this direction
                local attackPower = enemy.attack[dirKey] or 0
                if attackPower > 0 then
                    return true, dirKey, targetCell.card
                end
            end
        end
    end

    return false, nil, nil
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

-- EVALUATE_SKILL: Check if any skill should be used
function AI.evaluateSkill(enemy, game, Card)
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

-- EVALUATE_ATTACK: Find attack targets
function AI.evaluateAttack(enemy, game, Card)
    local attacks = {}
    local DIRECTIONS = Config.DIRECTIONS
    local gridSize = game.gridSize or Config.GRID.SIZE

    for dirKey, dir in pairs(DIRECTIONS) do
        local newX = enemy.gridX + dir.dx
        local newY = enemy.gridY + dir.dy
        local attackPower = enemy.attack[dirKey] or 0

        if newX >= 1 and newX <= gridSize and newY >= 1 and newY <= gridSize then
            local targetCell = game.grid[newY][newX]
            if targetCell.card and targetCell.card.type == Card.TYPE.PLAYER and attackPower > 0 then
                table.insert(attacks, {
                    x = newX,
                    y = newY,
                    direction = dirKey,
                    target = targetCell.card,
                    attackPower = attackPower
                })
            end
        end
    end

    -- Return best attack (highest damage)
    if #attacks > 0 then
        table.sort(attacks, function(a, b) return a.attackPower > b.attackPower end)
        return attacks[1]
    end

    return nil
end

-- EVALUATE_SURVIVAL: Check if attack would be suicidal
-- Returns true if safe to attack, false if attack would kill us
function AI.evaluateSurvival(enemy, player, attackDirection)
    if not player or not attackDirection then
        return true  -- Safe by default
    end

    -- Get the opposite direction (player's counter-attack direction)
    local counterDirection = AI.getOppositeDirection(attackDirection)
    if not counterDirection then
        return true  -- No valid counter direction, safe
    end

    -- Calculate player's counter damage
    local counterDamage = player.attack[counterDirection] or 0

    -- Consider shield absorption
    local effectiveDamage = counterDamage
    if enemy.shield and enemy.shield > 0 then
        effectiveDamage = math.max(0, counterDamage - enemy.shield)
    end

    -- Check if counter damage would kill us
    return effectiveDamage < enemy.hp
end

-- EXECUTE_APPROACH: Find best move toward player while avoiding high attack directions
function AI.executeApproach(enemy, game, Card)
    local player = game.player
    if not player or player.hp <= 0 then
        return nil
    end

    -- Get available moves based on movement type
    local moveTargets, _ = Grid.findTargetsWithMoveType(
        game.grid, enemy, Config.DIRECTIONS, game.gridSize or Config.GRID.SIZE, Config
    )

    if #moveTargets == 0 then
        return nil
    end

    -- Get player's highest attack direction
    local maxDir, _, _, _ = AI.getPlayerAttackExtremes(player)
    local safeApproachDir = maxDir and AI.getOppositeDirection(maxDir) or nil

    local bestMove = nil
    local bestScore = -9999

    for _, move in ipairs(moveTargets) do
        -- Calculate approach score
        local distToPlayer = AI.manhattanDistance(move.x, move.y, player.gridX, player.gridY)
        local approachScore = -distToPlayer * Config.AI.APPROACH_DISTANCE_WEIGHT

        -- Get direction of this move relative to player
        local moveDir = AI.getDirectionFromTo(move.x, move.y, player.gridX, player.gridY)

        -- Safety bonus: prefer approaching from opposite of player's strongest attack
        local safetyScore = 0
        if safeApproachDir and moveDir == safeApproachDir then
            safetyScore = Config.AI.APPROACH_SAFETY_BONUS
        end

        local totalScore = approachScore + safetyScore

        if totalScore > bestScore then
            bestScore = totalScore
            bestMove = move
        end
    end

    return bestMove
end

-- EXECUTE_ESCAPE: Find best escape move away from player
function AI.executeEscape(enemy, game, Card)
    local player = game.player
    if not player then
        return nil
    end

    -- Get available moves based on movement type
    local moveTargets, _ = Grid.findTargetsWithMoveType(
        game.grid, enemy, Config.DIRECTIONS, game.gridSize or Config.GRID.SIZE, Config
    )

    if #moveTargets == 0 then
        return nil
    end

    -- Get player's lowest attack direction (safest to escape toward)
    local _, _, minDir, _ = AI.getPlayerAttackExtremes(player)

    local bestMove = nil
    local bestScore = -9999

    for _, move in ipairs(moveTargets) do
        -- Calculate escape score (prefer farther from player)
        local distToPlayer = AI.manhattanDistance(move.x, move.y, player.gridX, player.gridY)
        local escapeScore = distToPlayer * Config.AI.ESCAPE_DISTANCE_WEIGHT

        -- Get direction from player to this move
        local escapeDir = AI.getDirectionFromTo(player.gridX, player.gridY, move.x, move.y)

        -- Safety bonus: prefer escaping toward player's weakest attack direction
        local safetyScore = 0
        if minDir and escapeDir == minDir then
            safetyScore = Config.AI.ESCAPE_SAFETY_BONUS
        end

        local totalScore = escapeScore + safetyScore

        if totalScore > bestScore then
            bestScore = totalScore
            bestMove = move
        end
    end

    return bestMove
end

-- Main AI decision function using state machine
-- Returns: { type = "attack"/"move"/"skill"/"wait", data = ... }
function AI.decideAction(enemy, game, Card)
    local state = STATE.IDLE
    local result = { type = "wait" }

    -- State machine loop
    while true do
        if state == STATE.IDLE then
            -- Transition to skill evaluation
            state = STATE.EVALUATE_SKILL

        elseif state == STATE.EVALUATE_SKILL then
            local skillResult = AI.evaluateSkill(enemy, game, Card)
            if skillResult then
                result = { type = "skill", data = skillResult }
                state = STATE.EXECUTE_SKILL
            else
                state = STATE.EVALUATE_ATTACK
            end

        elseif state == STATE.EXECUTE_SKILL then
            -- Skill decision made, exit
            break

        elseif state == STATE.EVALUATE_ATTACK then
            local attackResult = AI.evaluateAttack(enemy, game, Card)
            if attackResult then
                -- We can attack, check survival first
                state = STATE.EVALUATE_SURVIVAL
                result.attackData = attackResult  -- Temporary store
            else
                -- No attack possible, try to approach
                state = STATE.EXECUTE_APPROACH
            end

        elseif state == STATE.EVALUATE_SURVIVAL then
            local attackData = result.attackData
            local isSafe = AI.evaluateSurvival(enemy, attackData.target, attackData.direction)

            if isSafe then
                result = { type = "attack", data = attackData }
                state = STATE.EXECUTE_ATTACK
            else
                -- Attack would be suicidal, escape instead
                state = STATE.EXECUTE_ESCAPE
            end

        elseif state == STATE.EXECUTE_ATTACK then
            -- Attack decision made, exit
            break

        elseif state == STATE.EXECUTE_ESCAPE then
            local escapeMove = AI.executeEscape(enemy, game, Card)
            if escapeMove then
                result = { type = "move", data = escapeMove }
            else
                result = { type = "wait" }
            end
            break

        elseif state == STATE.EXECUTE_APPROACH then
            local approachMove = AI.executeApproach(enemy, game, Card)
            if approachMove then
                result = { type = "move", data = approachMove }
            else
                result = { type = "wait" }
            end
            break

        else
            -- STATE.WAIT or unknown state
            result = { type = "wait" }
            break
        end
    end

    return result
end

-- Legacy compatibility: Get best attack option
function AI.getBestAttack(enemy, attacks)
    if #attacks == 0 then return nil end

    local bestAttack = nil
    local bestScore = -999

    for _, attack in ipairs(attacks) do
        local score = AI.evaluateCombat(enemy, attack.target, attack.direction)
        local damage = enemy.attack[attack.direction] or 0
        score = score + damage
        if score > bestScore then
            bestScore = score
            bestAttack = attack
        end
    end

    if bestAttack then
        local damage = enemy.attack[bestAttack.direction] or 0
        if damage > 0 then
            return bestAttack
        end
    end

    return nil
end

-- Legacy compatibility: Get best move toward player
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

-- Legacy compatibility: Get best skill for enemy
function AI.getBestSkill(enemy, game, Card)
    return AI.evaluateSkill(enemy, game, Card)
end

return AI
