-- data/enemies.lua
-- 敌人模板数据定义
-- 纯数据文件，不包含逻辑

local Enemies = {}

-- 敌人模板
-- 格式: name, hp, attack (8方向), moveType, moveRange, skills
Enemies.TEMPLATES = {
    兔子 = {
        name = "兔子",
        hp = 6,
        attack = { n = 0, ne = 0, e = 0, se = 0, s = 2, sw = 0, w = 0, nw = 0 },
        moveType = "eight_way",
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },

    左拳 = {
        name = "左拳",
        hp = 4,
        attack = { n = 0, ne = 0, e = 2, se = 0, s = 0, sw = 0, w = 0, nw = 0 },
        moveType = "cross",
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },

    右拳 = {
        name = "右拳",
        hp = 4,
        attack = { n = 0, ne = 0, e = 0, se = 0, s = 0, sw = 0, w = 2, nw = 0 },
        moveType = "cross",
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },

    大钳蟹 = {
        name = "猪仔",
        hp = 8,
        attack = { n = 0, ne = 0, e = 0, se = 2, s = 0, sw = 2, w = 0, nw = 0 },
        moveType = "diagonal",
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },

    猪仔 = {
        name = "大钳蟹",
        hp = 5,
        attack = { n = 0, ne = 0, e = 4, se = 0, s = 0, sw = 0, w = 2, nw = 0 },
        moveType = "cross",
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },

    跳鼠 = {
        name = "跳鼠",
        hp = 6,
        attack = { n = 0, ne = 4, e = 0, se = 4, s = 0, sw = 4, w = 0, nw = 4 },
        moveType = "diagonal_jump",
        moveRange = 2,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.0 } }
        }
    },

    小恶魔 = {
        name = "小恶魔",
        hp = 13,
        attack = { n = 2, ne = 0, e = 5, se = 0, s = 5, sw = 0, w = 5, nw = 0 },
        moveType = "eight_way",
        moveRange = 1,
        skills = {
            { id = "whirlwind", params = { damageMultiplier = 1.5 } },
            { id = "shield", params = { amount = 8 } }
        }
    },
}

-- 关卡数据
-- 格式: name, enemies (模板名+位置), branches (分支关卡)
Enemies.LEVELS = {
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

-- 获取敌人模板
function Enemies.getTemplate(name)
    return Enemies.TEMPLATES[name]
end

-- 获取关卡数据
function Enemies.getLevel(index)
    return Enemies.LEVELS[index]
end

-- 获取关卡数量
function Enemies.getLevelCount()
    return #Enemies.LEVELS
end

return Enemies
