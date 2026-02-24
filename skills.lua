-- Skill System Module
-- Define skill effects and management

local Config = require("config")

local Skills = {}

-- Skill definitions
Skills.SKILLS = {
    -- 1. Charge - Move 2 tiles and attack
    {
        id = "charge",
        name = "Charge",
        description = "Move 2 tiles, damage enemies in path",
        cooldown = 3,
        currentCooldown = 0,
        execute = function(user, direction, game)
            local DIRECTIONS = game.DIRECTIONS or Config.DIRECTIONS
            local GRID_SIZE = Config.GRID.SIZE
            local dir = DIRECTIONS[direction]
            if not dir then return false end

            local damage = user.attack[direction] or 0
            local moved = false

            for step = 1, 2 do
                local newX = user.gridX + dir.dx
                local newY = user.gridY + dir.dy

                if newX < 1 or newX > GRID_SIZE or newY < 1 or newY > GRID_SIZE then
                    break
                end

                local targetCell = game.grid[newY][newX]
                if targetCell.card then
                    if targetCell.card.type ~= user.type then
                        targetCell.card.hp = targetCell.card.hp - damage
                        game.createDamageText(targetCell.card, damage)
                        if targetCell.card.hp <= 0 then
                            game.removeCard(targetCell.card)
                        end
                    end
                    break
                else
                    game.moveCard(user, newX, newY)
                    moved = true
                end
            end

            return moved
        end
    },

    -- 2. Lifesteal - Damage and heal
    {
        id = "lifesteal",
        name = "Lifesteal",
        description = "Deal damage, heal 50% of damage dealt",
        cooldown = 4,
        currentCooldown = 0,
        execute = function(user, direction, game)
            local DIRECTIONS = game.DIRECTIONS or Config.DIRECTIONS
            local GRID_SIZE = Config.GRID.SIZE
            local dir = DIRECTIONS[direction]
            if not dir then return false end

            local targetX = user.gridX + dir.dx
            local targetY = user.gridY + dir.dy

            if targetX < 1 or targetX > GRID_SIZE or targetY < 1 or targetY > GRID_SIZE then
                return false
            end

            local targetCell = game.grid[targetY][targetX]
            if not targetCell.card or targetCell.card.type == user.type then
                return false
            end

            local damage = (user.attack[direction] or 0) + 2
            local heal = math.ceil(damage * 0.5)

            targetCell.card.hp = targetCell.card.hp - damage
            user.hp = math.min(user.hp + heal, user.maxHp)

            game.createDamageText(targetCell.card, damage)
            game.createHealText(user, heal)

            if targetCell.card.hp <= 0 then
                game.removeCard(targetCell.card)
            end

            return true
        end
    },

    -- 3. Whirlwind - Attack all adjacent enemies
    {
        id = "whirlwind",
        name = "Whirlwind",
        description = "Attack all 8 adjacent enemies",
        cooldown = 5,
        currentCooldown = 0,
        execute = function(user, _, game)
            local DIRECTIONS = game.DIRECTIONS or Config.DIRECTIONS
            local GRID_SIZE = Config.GRID.SIZE
            local hitAny = false

            for dirKey, dir in pairs(DIRECTIONS) do
                local targetX = user.gridX + dir.dx
                local targetY = user.gridY + dir.dy

                if targetX >= 1 and targetX <= GRID_SIZE and targetY >= 1 and targetY <= GRID_SIZE then
                    local targetCell = game.grid[targetY][targetX]
                    if targetCell.card and targetCell.card.type ~= user.type then
                        local damage = (user.attack[dirKey] or 0)
                        targetCell.card.hp = targetCell.card.hp - damage
                        game.createDamageText(targetCell.card, damage)

                        if targetCell.card.hp <= 0 then
                            game.removeCard(targetCell.card)
                        end
                        hitAny = true
                    end
                end
            end

            return hitAny
        end
    },

    -- 4. Shield - Temporary protection
    {
        id = "shield",
        name = "Shield",
        description = "Gain temporary shield",
        cooldown = 4,
        currentCooldown = 0,
        execute = function(user, _, game)
            local shieldAmount = 5
            user.shield = (user.shield or 0) + shieldAmount
            game.createShieldText(user, shieldAmount)
            return true
        end
    }
}

-- Player skill slots (max 4)
local playerSkills = {}

-- Initialize default skills
function Skills.init()
    playerSkills = {}
    Skills.learnSkill("charge")
end

-- Learn a skill
function Skills.learnSkill(skillId)
    if #playerSkills >= 4 then
        return false, "Skill slots full"
    end

    for _, skill in ipairs(playerSkills) do
        if skill.id == skillId then
            return false, "Already learned"
        end
    end

    for _, skillDef in ipairs(Skills.SKILLS) do
        if skillDef.id == skillId then
            local newSkill = {
                id = skillDef.id,
                name = skillDef.name,
                description = skillDef.description,
                cooldown = skillDef.cooldown,
                currentCooldown = 0,
                execute = skillDef.execute
            }
            table.insert(playerSkills, newSkill)
            return true
        end
    end

    return false, "Skill not found"
end

-- Get player skills
function Skills.getPlayerSkills()
    return playerSkills
end

-- Use a skill
function Skills.useSkill(index, direction, gameContext)
    local skill = playerSkills[index]
    if not skill then
        return false, "Invalid skill"
    end

    if skill.currentCooldown > 0 then
        return false, "On cooldown"
    end

    local success = skill.execute(gameContext.player, direction, gameContext)
    if success then
        skill.currentCooldown = skill.cooldown
        return true
    end

    return false, "Skill failed"
end

-- Tick cooldowns at turn end
function Skills.tickCooldowns()
    for _, skill in ipairs(playerSkills) do
        if skill.currentCooldown > 0 then
            skill.currentCooldown = skill.currentCooldown - 1
        end
    end
end

-- Absorb skill from enemy
function Skills.absorbSkill(enemyName)
    local skillMap = {
        ["Vampire"] = "lifesteal",
        ["Orc"] = "charge",
        ["Demon"] = "whirlwind"
    }

    local skillId = skillMap[enemyName]
    if skillId then
        local success, msg = Skills.learnSkill(skillId)
        if success then
            return skillId
        end
    end
    return nil
end

-- Reset skills (new game)
function Skills.reset()
    playerSkills = {}
    Skills.init()
end

return Skills
