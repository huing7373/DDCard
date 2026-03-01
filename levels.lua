-- Level Configuration Module
-- 关卡配置和敌人创建逻辑

local Skills = require("skills")
local Config = require("config")
local EnemyData = require("data.enemies")

local Levels = {}

-- 从数据模块导出模板和关卡数据 (向后兼容)
Levels.ENEMY_TEMPLATES = EnemyData.TEMPLATES
Levels.data = EnemyData.LEVELS

-- Get level data
function Levels.getLevel(levelIndex)
    return Levels.data[levelIndex]
end

-- Get total level count
function Levels.getLevelCount()
    return #Levels.data
end

-- Create enemy data from template
function Levels.createEnemyFromTemplate(templateName, x, y)
    local template = Levels.ENEMY_TEMPLATES[templateName]
    if not template then
        return nil
    end

    -- Initialize enemy skills from template
    local enemySkills = nil
    if template.skills then
        enemySkills = {}
        for _, skillEntry in ipairs(template.skills) do
            -- Support both simple format ("skillId") and detailed format ({ id = "skillId", params = {...} })
            local skillId, customParams
            if type(skillEntry) == "string" then
                skillId = skillEntry
                customParams = nil
            else
                skillId = skillEntry.id
                customParams = skillEntry.params
            end

            local skillDef = Skills.getSkillById(skillId)
            if skillDef then
                -- Deep copy default params, then override with custom params
                local paramsCopy = {}
                if skillDef.params then
                    for k, v in pairs(skillDef.params) do
                        paramsCopy[k] = v
                    end
                end
                if customParams then
                    for k, v in pairs(customParams) do
                        paramsCopy[k] = v
                    end
                end
                table.insert(enemySkills, {
                    id = skillDef.id,
                    name = skillDef.name,
                    description = skillDef.description,
                    cooldown = skillDef.cooldown,
                    currentCooldown = 0,
                    params = paramsCopy,
                    execute = skillDef.execute
                })
            end
        end
    end

    return {
        name = template.name,
        hp = template.hp,
        maxHp = template.hp,
        attack = {
            n = template.attack.n,
            ne = template.attack.ne,
            e = template.attack.e,
            se = template.attack.se,
            s = template.attack.s,
            sw = template.attack.sw,
            w = template.attack.w,
            nw = template.attack.nw
        },
        gridX = x,
        gridY = y,
        skills = enemySkills,
        -- Movement properties
        moveType = template.moveType or Config.MOVE_TYPE.EIGHT_WAY,
        moveRange = template.moveRange or 1,
        moveMinRange = template.moveMinRange or 0
    }
end

return Levels
