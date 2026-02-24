-- Level Configuration Module
-- Define level data and enemy templates

local Levels = {}

-- Enemy templates
Levels.ENEMY_TEMPLATES = {
    goblin = {
        name = "Goblin",
        hp = 8,
        attack = { n = 2, ne = 1, e = 2, se = 1, s = 2, sw = 1, w = 2, nw = 1 }
    },
    skeleton = {
        name = "Skeleton",
        hp = 6,
        attack = { n = 3, ne = 0, e = 3, se = 0, s = 3, sw = 0, w = 3, nw = 0 }
    },
    orc = {
        name = "Orc",
        hp = 12,
        attack = { n = 3, ne = 2, e = 3, se = 2, s = 3, sw = 2, w = 3, nw = 2 }
    },
    slime = {
        name = "Slime",
        hp = 5,
        attack = { n = 1, ne = 1, e = 1, se = 1, s = 1, sw = 1, w = 1, nw = 1 }
    },
    vampire = {
        name = "Vampire",
        hp = 10,
        attack = { n = 4, ne = 2, e = 4, se = 2, s = 4, sw = 2, w = 4, nw = 2 }
    },
    demon = {
        name = "Demon",
        hp = 15,
        attack = { n = 4, ne = 3, e = 4, se = 3, s = 4, sw = 3, w = 4, nw = 3 }
    }
}

-- Level data
Levels.data = {
    -- Level 1: Goblin Nest
    {
        name = "Goblin Nest",
        enemies = {
            { template = "goblin", x = 4, y = 1 },
            { template = "goblin", x = 3, y = 4 }
        },
        branches = {2, 3}
    },
    -- Level 2: Skeleton Graveyard (Route A)
    {
        name = "Graveyard",
        enemies = {
            { template = "skeleton", x = 1, y = 1 },
            { template = "skeleton", x = 4, y = 4 },
            { template = "skeleton", x = 4, y = 1 }
        },
        branches = {4}
    },
    -- Level 3: Slime Cave (Route B)
    {
        name = "Slime Cave",
        enemies = {
            { template = "slime", x = 1, y = 1 },
            { template = "slime", x = 4, y = 1 },
            { template = "slime", x = 1, y = 4 },
            { template = "slime", x = 4, y = 4 }
        },
        branches = {4}
    },
    -- Level 4: Orc Camp
    {
        name = "Orc Camp",
        enemies = {
            { template = "orc", x = 3, y = 1 },
            { template = "goblin", x = 4, y = 3 }
        },
        branches = {5, 6}
    },
    -- Level 5: Vampire Castle (Route A)
    {
        name = "Vampire Castle",
        enemies = {
            { template = "vampire", x = 4, y = 2 },
            { template = "skeleton", x = 1, y = 4 }
        },
        branches = {7}
    },
    -- Level 6: Demon Temple (Route B)
    {
        name = "Demon Temple",
        enemies = {
            { template = "demon", x = 3, y = 3 }
        },
        branches = {7}
    },
    -- Level 7: Final Boss
    {
        name = "Dark Throne",
        enemies = {
            { template = "demon", x = 3, y = 2 },
            { template = "vampire", x = 1, y = 4 },
            { template = "orc", x = 4, y = 4 }
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
        gridY = y
    }
end

return Levels
