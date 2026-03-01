-- Skill System Module
-- Define skill effects and management

local Config = require("config")

local Skills = {}

-- Skill definitions
Skills.SKILLS = {
    -- 燃血冲锋: 消耗1HP，进行两次移动并附带攻击
    {
        id = "blood_charge",
        name = "燃血冲锋",
        description = "消耗1HP，移动2格并攻击路径上的敌人",
        cooldown = 2,
        currentCooldown = 0,
        params = {
            hpCost = 1,
            range = 2,
            damageMultiplier = 1.0
        },
        execute = function(user, direction, game, params)
            local DIRECTIONS = game.DIRECTIONS or require("config").DIRECTIONS
            local GRID_SIZE = require("config").GRID.SIZE
            local dir = DIRECTIONS[direction]
            if not dir then return false end

            local hpCost = params.hpCost or 1
            local range = params.range or 2
            local damageMultiplier = params.damageMultiplier or 1.0

            -- 检查HP是否足够
            if user.hp <= hpCost then
                return false
            end

            -- 消耗HP
            user.hp = user.hp - hpCost

            local baseDamage = user.attack[direction] or 0
            local damage = math.floor(baseDamage * damageMultiplier)
            local moved = false

            -- 记录起始位置用于视觉效果
            local startX, startY
            if game.getScreenPos then
                startX, startY = game.getScreenPos(user.gridX, user.gridY)
            end

            -- 移动并攻击
            for step = 1, range do
                local newX = user.gridX + dir.dx
                local newY = user.gridY + dir.dy

                if newX < 1 or newX > GRID_SIZE or newY < 1 or newY > GRID_SIZE then
                    break
                end

                local targetCell = game.grid[newY][newX]
                if targetCell.card then
                    -- 遇到目标，造成伤害
                    if targetCell.card.type ~= user.type then
                        targetCell.card.hp = targetCell.card.hp - damage
                        game.createDamageText(targetCell.card, damage)
                        if targetCell.card.hp <= 0 then
                            game.removeCard(targetCell.card)
                        end
                    end
                    break
                else
                    -- 空格，移动过去
                    game.moveCard(user, newX, newY)
                    moved = true
                end
            end

            -- 创建冲锋视觉效果
            if moved and game.getScreenPos and game.createSkillEffect then
                local endX, endY = game.getScreenPos(user.gridX, user.gridY)
                game.createSkillEffect("charge_trail", {
                    startX = startX, startY = startY,
                    endX = endX, endY = endY,
                    duration = 0.3
                })
                if game.triggerScreenShake then
                    game.triggerScreenShake(5, 0.15)
                end
            end

            return true
        end
    },
}

-- Get skill definition by ID
function Skills.getSkillById(skillId)
    for _, skillDef in ipairs(Skills.SKILLS) do
        if skillDef.id == skillId then
            return skillDef
        end
    end
    return nil
end

-- Player skill slots (max 4)
local playerSkills = {}

-- Initialize default skills
function Skills.init()
    playerSkills = {}
    Skills.learnSkill("blood_charge")
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
            local paramsCopy = nil
            if skillDef.params then
                paramsCopy = {}
                for k, v in pairs(skillDef.params) do
                    paramsCopy[k] = v
                end
            end
            local newSkill = {
                id = skillDef.id,
                name = skillDef.name,
                description = skillDef.description,
                cooldown = skillDef.cooldown,
                currentCooldown = 0,
                params = paramsCopy,
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

    local success = skill.execute(gameContext.player, direction, gameContext, skill.params or {})
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

-- Absorb skill from enemy (disabled)
function Skills.absorbSkill(enemyName)
    return nil
end

-- Reset skills (new game)
function Skills.reset()
    playerSkills = {}
    Skills.init()
end

return Skills
