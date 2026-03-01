-- Skill System Module
-- Define skill effects and management

local Config = require("config")

local Skills = {}

-- Skill definitions (empty - no skills)
Skills.SKILLS = {}

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
