-- Level Configuration Module
-- Define level data and enemy templates

local Skills = require("skills")
local Config = require("config")

local Levels = {}

-- Enemy templates
Levels.ENEMY_TEMPLATES = {
    兔子 = {
        name = "兔子",
        hp = 6,
        attack = { n = 0, ne = 0, e = 0, se = 0, s = 2, sw = 0, w = 0, nw = 0 },
        moveType = "eight_way",  -- 十字移动
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },
    左拳 = {
        name = "左拳",
        hp = 4,
        attack = { n = 0, ne = 0, e = 2, se = 0, s = 0, sw = 0, w = 0, nw = 0 },
        moveType = "cross",  -- 十字移动
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },
    右拳 = {
        name = "右拳",
        hp = 4,
        attack = { n = 0, ne = 0, e = 0, se = 0, s = 0, sw = 0, w = 2, nw = 0 },
        moveType = "cross",  -- 十字移动
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },
    大钳蟹 = {
        name = "猪仔",
        hp = 8,
        attack = { n = 0, ne = 0, e = 0, se = 2, s = 0, sw = 2, w = 0, nw = 0 },
        moveType = "diagonal",  -- 斜向移动
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },
    猪仔 = {
        name = "大钳蟹",
        hp = 5,
        attack = { n = 0, ne = 0, e = 4, se = 0, s = 0, sw = 0, w = 2, nw = 0 },
        moveType = "cross",  -- 十字移动
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },
    跳鼠 = {
        name = "跳鼠",
        hp = 6,
        attack = { n = 0, ne = 4, e = 0, se = 4, s = 0, sw = 4, w = 0, nw = 4 },
        moveType = "diagonal_jump",  -- 斜向跳跃
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },
    小恶魔 = {
        name = "小恶魔",
        hp = 13,
        attack = { n = 2, ne = 0, e = 5, se = 0, s = 5, sw = 0, w = 5, nw = 0 },
        moveType = "eight_way",  -- 八向移动
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.5 } },
            { id = "shield", params = { amount = 8 } }
        }
    }
}

-- Level data
Levels.data = {
    -- Level 1: 兔子 Nest
    {
        name = "兔子 Nest",
        enemies = {
            { template = "兔子", x = 3, y = 1 },
        },
        branches = {2, 3}
    },
    -- Level 2: 左拳 Graveyard (Route A)
    {
        name = "Graveyard",
        enemies = {
            { template = "左拳", x = 1, y = 1 },
            { template = "右拳", x = 5, y = 1 }
        },
        branches = {4}
    },
    -- Level 3: 猪仔 Cave (Route B)
    {
        name = "猪仔 Cave",
        enemies = {

            { template = "猪仔", x = 2, y = 1 },

            { template = "猪仔", x = 4, y = 1 }
        },
        branches = {4}
    },
    -- Level 4: 大钳蟹 Camp
    {
        name = "大钳蟹 Camp",
        enemies = {
            { template = "大钳蟹", x = 5, y = 5 },
            { template = "猪仔", x = 3, y = 1 },
        },
        branches = {5, 6}
    },
    -- Level 5: 跳鼠 Castle (Route A)
    {
        name = "跳鼠 Castle",
        enemies = {
            { template = "跳鼠", x = 2, y = 1 },
            { template = "跳鼠", x = 4, y = 5 }
        },
        branches = {7}
    },
    -- Level 6: 小恶魔 Temple (Route B)
    {
        name = "小恶魔 Temple",
        enemies = {
            { template = "小恶魔", x = 3, y = 1 }
        },
        branches = {7}
    },
    -- Level 7: Final Boss
    {
        name = "Dark 跳鼠rone",
        enemies = {
            { template = "小恶魔", x = 3, y = 1 },
            { template = "左拳", x = 1, y = 1 },
            { template = "右拳", x = 5, y = 1 }
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
        skills = enemySkills,
        -- Movement properties
        moveType = template.moveType or Config.MOVE_TYPE.EIGHT_WAY,
        moveRange = template.moveRange or 1,
        moveMinRange = template.moveMinRange or 0
    }
end

return Levels
