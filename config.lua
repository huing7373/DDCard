-- Configuration Module
-- Centralized constants and configuration values

local Config = {}

-- Grid configuration
Config.GRID = {
    SIZE = 5,
    CELL_SIZE = 100,
    OFFSET_X = 75,
    OFFSET_Y = 10,
}

-- 8 direction definitions
Config.DIRECTIONS = {
    n  = { dx = 0,  dy = -1, opposite = "s" },
    ne = { dx = 1,  dy = -1, opposite = "sw" },
    e  = { dx = 1,  dy = 0,  opposite = "w" },
    se = { dx = 1,  dy = 1,  opposite = "nw" },
    s  = { dx = 0,  dy = 1,  opposite = "n" },
    sw = { dx = -1, dy = 1,  opposite = "ne" },
    w  = { dx = -1, dy = 0,  opposite = "e" },
    nw = { dx = -1, dy = -1, opposite = "se" },
}

-- Direction key list for iteration
Config.DIRECTION_KEYS = {"n", "ne", "e", "se", "s", "sw", "w", "nw"}

-- Timing configuration
Config.TIMING = {
    ENEMY_ACTION_DELAY = 0.5,
    DAMAGE_TEXT_DURATION = 1.5,
    DAMAGE_TEXT_SPEED = 30,
}

-- Combat configuration
Config.COMBAT = {
    KILL_HP_RECOVERY_PERCENT = 0.25,
    RANDOM_ATK_BONUS_MIN = 1,
    RANDOM_ATK_BONUS_MAX = 2,
}

-- Color configuration
Config.COLORS = {
    -- Card backgrounds
    PLAYER_BG = {0.2, 0.4, 0.8},
    ENEMY_BG = {0.7, 0.2, 0.2},

    -- Card borders
    PLAYER_BORDER = {0.3, 0.6, 1},
    ENEMY_BORDER = {1, 0.3, 0.3},

    -- Grid highlighting
    MOVE_TARGET = {0.2, 0.6, 0.2, 0.5},
    ATTACK_TARGET = {0.7, 0.2, 0.2, 0.5},
    MOVE_BORDER = {0.3, 0.9, 0.3},
    ATTACK_BORDER = {1, 0.3, 0.3},

    -- Grid cells
    GRID_EVEN = {0.2, 0.2, 0.25},
    GRID_ODD = {0.25, 0.25, 0.3},
    GRID_BORDER = {0.4, 0.4, 0.5},

    -- Damage text
    DAMAGE = {1, 0.3, 0.3},
    COUNTER_DAMAGE = {1, 0.6, 0.3},
    HEAL = {0.3, 1, 0.3},
    SHIELD = {0.5, 0.7, 1},
    SOUL = {0.8, 0.5, 1},

    -- UI elements
    BUTTON_BG = {0.25, 0.25, 0.35},
    BUTTON_HOVER = {0.4, 0.4, 0.5},
    BUTTON_BORDER = {0.5, 0.5, 0.6},
    BUTTON_TEXT = {1, 1, 1},

    -- Game states
    PLAYER_TURN = {0.3, 0.8, 0.3},
    ENEMY_TURN = {0.9, 0.3, 0.3},
    GAME_OVER = {0.8, 0.2, 0.2},
    VICTORY = {0.2, 0.9, 0.2},
}

-- UI Layout configuration
Config.UI = {
    -- Button sizes
    BUTTON_WIDTH = 100,
    BUTTON_HEIGHT = 30,
    BUTTON_CORNER_RADIUS = 5,

    -- Panel positions
    INFO_PANEL_X = 620,
    INFO_PANEL_Y = 100,

    -- Skill bar
    SKILL_BAR_X = 200,
    SKILL_BAR_Y = 520,
    SKILL_SLOT_WIDTH = 80,
    SKILL_SLOT_HEIGHT = 30,

    -- Upgrade menu
    UPGRADE_BTN_WIDTH = 400,
    UPGRADE_BTN_HEIGHT = 45,

    -- Level select
    LEVEL_BTN_WIDTH = 300,
    LEVEL_BTN_HEIGHT = 50,
}

-- Player default stats
Config.PLAYER = {
    DEFAULT_HP = 20,
    DEFAULT_ATTACK = { n = 3, ne = 0, e = 0, se = 0, s = 0, sw = 0, w = 0, nw = 0 },
    DEFAULT_GRID_X = 3,
    DEFAULT_GRID_Y = 4,
}

-- Game state enumeration
Config.GAME_STATE = {
    PLAYER_TURN = "player_turn",
    ENEMY_TURN = "enemy_turn",
    ANIMATING = "animating",
    GAME_OVER = "game_over",
    VICTORY = "victory"
}

-- Visual effects configuration
Config.EFFECTS = {
    FLASH_DURATION = 0.15,          -- Flash duration when hit (seconds)
    SHAKE_INTENSITY = 3,            -- Normal attack screen shake (pixels)
    SKILL_SHAKE_INTENSITY = 5,      -- Skill screen shake (pixels)
    SHAKE_DURATION = 0.1,           -- Screen shake duration (seconds)
    DAMAGE_SCALE_START = 1.5,       -- Initial damage number scale
    SKILL_EFFECT_DURATION = 0.3,    -- Skill visual effect duration
    SHIELD_GLOW_SPEED = 3,          -- Shield glow pulse speed
}

return Config
