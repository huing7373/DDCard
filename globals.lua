-- globals.lua
-- 全局配置和实例追踪
-- 集中管理游戏全局状态

-- 全局表
G = G or {}

--------------------------------------------------
-- 游戏状态枚举 (数字枚举便于比较)
--------------------------------------------------
G.STATES = {
    PLAYER_TURN = 1,
    ENEMY_TURN = 2,
    ANIMATING = 3,
    GAME_OVER = 4,
    VICTORY = 5,
    MENU = 6,
    LEVEL_SELECT = 7,
    UPGRADE = 8,
}

-- 状态名称映射 (用于调试输出)
G.STATE_NAMES = {
    [1] = "PLAYER_TURN",
    [2] = "ENEMY_TURN",
    [3] = "ANIMATING",
    [4] = "GAME_OVER",
    [5] = "VICTORY",
    [6] = "MENU",
    [7] = "LEVEL_SELECT",
    [8] = "UPGRADE",
}

--------------------------------------------------
-- 方向定义
--------------------------------------------------
G.DIRECTIONS = {
    n  = { dx = 0,  dy = -1, index = 0, opposite = "s" },
    ne = { dx = 1,  dy = -1, index = 1, opposite = "sw" },
    e  = { dx = 1,  dy = 0,  index = 2, opposite = "w" },
    se = { dx = 1,  dy = 1,  index = 3, opposite = "nw" },
    s  = { dx = 0,  dy = 1,  index = 4, opposite = "n" },
    sw = { dx = -1, dy = 1,  index = 5, opposite = "ne" },
    w  = { dx = -1, dy = 0,  index = 6, opposite = "e" },
    nw = { dx = -1, dy = -1, index = 7, opposite = "se" },
}

-- 方向键列表 (顺序迭代用)
G.DIRECTION_KEYS = {"n", "ne", "e", "se", "s", "sw", "w", "nw"}

--------------------------------------------------
-- 移动类型枚举
--------------------------------------------------
G.MOVE_TYPE = {
    EIGHT_WAY = 1,      -- 八向移动 (默认)
    CROSS = 2,          -- 十字移动
    DIAGONAL = 3,       -- 斜向移动
    CROSS_JUMP = 4,     -- 十字跳跃
    DIAGONAL_JUMP = 5,  -- 斜向跳跃
}

-- 各移动类型的方向集合
G.MOVE_DIRECTIONS = {
    [G.MOVE_TYPE.EIGHT_WAY] = {"n", "ne", "e", "se", "s", "sw", "w", "nw"},
    [G.MOVE_TYPE.CROSS] = {"n", "e", "s", "w"},
    [G.MOVE_TYPE.DIAGONAL] = {"ne", "se", "sw", "nw"},
    [G.MOVE_TYPE.CROSS_JUMP] = {"n", "e", "s", "w"},
    [G.MOVE_TYPE.DIAGONAL_JUMP] = {"ne", "se", "sw", "nw"},
}

--------------------------------------------------
-- 实例追踪表
--------------------------------------------------
G.I = {
    MOVEABLE = {},   -- 所有可移动实体
    CARD = {},       -- 所有卡牌
    UI = {},         -- 所有 UI 元素
}

--------------------------------------------------
-- 定时器管理
--------------------------------------------------
G.TIMERS = {
    REAL = 0,        -- 真实时间
    TOTAL = 0,       -- 游戏总时间
}

--------------------------------------------------
-- 颜色定义
--------------------------------------------------
G.C = {
    -- 卡牌背景
    PLAYER_BG = {0.2, 0.4, 0.8},
    ENEMY_BG = {0.7, 0.2, 0.2},

    -- 卡牌边框
    PLAYER_BORDER = {0.3, 0.6, 1},
    ENEMY_BORDER = {1, 0.3, 0.3},

    -- 网格高亮
    MOVE_TARGET = {0.2, 0.6, 0.2, 0.5},
    ATTACK_TARGET = {0.7, 0.2, 0.2, 0.5},
    MOVE_BORDER = {0.3, 0.9, 0.3},
    ATTACK_BORDER = {1, 0.3, 0.3},

    -- 网格单元格
    GRID_EVEN = {0.2, 0.2, 0.25},
    GRID_ODD = {0.25, 0.25, 0.3},
    GRID_BORDER = {0.4, 0.4, 0.5},

    -- 伤害文字
    DAMAGE = {1, 0.3, 0.3},
    COUNTER_DAMAGE = {1, 0.6, 0.3},
    HEAL = {0.3, 1, 0.3},
    SHIELD = {0.5, 0.7, 1},
    SOUL = {0.8, 0.5, 1},

    -- UI
    WHITE = {1, 1, 1},
    BLACK = {0, 0, 0},
    GOLD = {1, 0.9, 0.3},
    GREY = {0.5, 0.5, 0.5},
    RED = {1, 0.3, 0.3},
    GREEN = {0.3, 1, 0.3},
    BLUE = {0.3, 0.6, 1},
}

--------------------------------------------------
-- 设置配置
--------------------------------------------------
G.SETTINGS = {
    -- 网格
    GRID_SIZE = 5,
    CELL_SIZE = 100,
    GRID_OFFSET_X = 75,
    GRID_OFFSET_Y = 10,

    -- 动画
    LERP_SPEED = 10,
    DAMAGE_TEXT_DURATION = 1.5,
    DAMAGE_TEXT_SPEED = 30,

    -- 战斗
    KILL_HP_RECOVERY_PERCENT = 0.25,

    -- AI
    ENEMY_ACTION_DELAY = 0.5,
}

--------------------------------------------------
-- 辅助函数
--------------------------------------------------

-- 获取状态名称
function G.get_state_name(state)
    return G.STATE_NAMES[state] or "UNKNOWN"
end

-- 重置实例追踪
function G.reset_instances()
    G.I.MOVEABLE = {}
    G.I.CARD = {}
    G.I.UI = {}
end

return G
