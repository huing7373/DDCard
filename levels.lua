-- Level Configuration Module
-- Define level data and enemy templates

local Skills = require("skills")

local Levels = {}

-- Enemy templates
Levels.ENEMY_TEMPLATES = {
    rab = {
        name = "rab",
        hp = 6,
        attack = { n = 0, ne = 0, e = 0, se = 0, s = 2, sw = 0, w = 0, nw = 0 }
    },
    L_Hand = {
        name = "L_Hand",
        hp = 4,
        attack = { n = 0, ne = 0, e = 2, se = 0, s = 0, sw = 0, w = 0, nw = 0 }
    },
    R_Hand = {
        name = "R_Hand",
        hp = 4,
        attack = { n = 0, ne = 0, e = 0, se = 0, s = 0, sw = 0, w = 2, nw = 0 }
    },
    PX = {
        name = "pig",
        hp = 8,
        attack = { n = 0, ne = 0, e = 0, se = 2, s = 0, sw = 2, w = 0, nw = 0 }
    },
    pig = {
        name = "PX",
        hp = 5,
        attack = { n = 1, ne = 0, e = 3, se = 0, s = 1, sw = 0, w = 0, nw = 0 }
    },
    TH = {
        name = "TH",
        hp = 6,
        attack = { n = 0, ne = 4, e = 0, se = 4, s = 0, sw = 4, w = 0, nw = 4 },
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },
    God = {
        name = "God",
        hp = 13,
        attack = { n = 2, ne = 0, e = 5, se = 0, s = 5, sw = 0, w = 5, nw = 0 },
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.5 } },
            { id = "shield", params = { amount = 8 } }
        }
    }
}

-- Level data
Levels.data = {
    -- Level 1: rab Nest
    {
        name = "rab Nest",
        enemies = {
            { template = "rab", x = 1, y = 1 },
            { template = "rab", x = 5, y = 1 }
        },
        branches = {2, 3}
    },
    -- Level 2: L_Hand Graveyard (Route A)
    {
        name = "Graveyard",
        enemies = {
            { template = "rab", x = 3, y = 2 },
            { template = "L_Hand", x = 5, y = 1 },
            { template = "R_Hand", x = 1, y = 1 }
        },
        branches = {4}
    },
    -- Level 3: pig Cave (Route B)
    {
        name = "pig Cave",
        enemies = {
            { template = "pig", x = 1, y = 1 },
            { template = "pig", x = 4, y = 1 },
            { template = "pig", x = 1, y = 1 },
            { template = "pig", x = 4, y = 1 }
        },
        branches = {4}
    },
    -- Level 4: PX Camp
    {
        name = "PX Camp",
        enemies = {
            { template = "PX", x = 3, y = 1 },
            { template = "rab", x = 4, y = 3 }
        },
        branches = {5, 6}
    },
    -- Level 5: TH Castle (Route A)
    {
        name = "TH Castle",
        enemies = {
            { template = "TH", x = 4, y = 2 },
            { template = "L_Hand", x = 1, y = 4 }
        },
        branches = {7}
    },
    -- Level 6: God Temple (Route B)
    {
        name = "God Temple",
        enemies = {
            { template = "God", x = 3, y = 3 }
        },
        branches = {7}
    },
    -- Level 7: Final Boss
    {
        name = "Dark Throne",
        enemies = {
            { template = "God", x = 3, y = 2 },
            { template = "TH", x = 1, y = 4 },
            { template = "PX", x = 4, y = 4 }
        },
        branches = {}
    }
}

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
        skills = enemySkills
    }
end

return Levels
