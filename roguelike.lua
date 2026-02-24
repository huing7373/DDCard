-- Roguelike循环模块
-- 管理游戏循环、结算和继承

local Roguelike = {}

-- 运行数据
local runData = {
    runNumber = 1,          -- 当前运行次数
    highestLevel = 0,       -- 历史最高关卡
    totalRuns = 0,          -- 总运行次数
    bestScore = 0,          -- 最高分数

    -- 当前运行数据
    currentScore = 0,
    enemiesKilled = 0,
    damageDealt = 0,
    damageTaken = 0,

    -- 继承的技能（死亡后保留一个技能）
    inheritedSkill = nil,

    -- 难度系数（每次通关增加）
    difficultyMultiplier = 1.0
}

-- 计算得分
function Roguelike.calculateScore(levelReached, enemiesKilled, damageDealt)
    local score = 0
    score = score + levelReached * 100
    score = score + enemiesKilled * 50
    score = score + math.floor(damageDealt * 0.5)
    return score
end

-- 记录击杀
function Roguelike.recordKill()
    runData.enemiesKilled = runData.enemiesKilled + 1
end

-- 记录伤害
function Roguelike.recordDamage(dealt, taken)
    runData.damageDealt = runData.damageDealt + dealt
    runData.damageTaken = runData.damageTaken + taken
end

-- 获取运行数据
function Roguelike.getData()
    return runData
end

-- 结束当前运行（死亡或通关）
function Roguelike.endRun(victory, levelReached)
    runData.totalRuns = runData.totalRuns + 1

    -- 计算得分
    runData.currentScore = Roguelike.calculateScore(
        levelReached,
        runData.enemiesKilled,
        runData.damageDealt
    )

    -- 胜利奖励
    if victory then
        runData.currentScore = runData.currentScore * 2
        runData.difficultyMultiplier = runData.difficultyMultiplier + 0.2
    end

    -- 更新最高纪录
    if levelReached > runData.highestLevel then
        runData.highestLevel = levelReached
    end
    if runData.currentScore > runData.bestScore then
        runData.bestScore = runData.currentScore
    end

    return {
        score = runData.currentScore,
        enemiesKilled = runData.enemiesKilled,
        damageDealt = runData.damageDealt,
        damageTaken = runData.damageTaken,
        levelReached = levelReached,
        victory = victory
    }
end

-- 开始新运行
function Roguelike.startNewRun()
    runData.runNumber = runData.runNumber + 1
    runData.enemiesKilled = 0
    runData.damageDealt = 0
    runData.damageTaken = 0
    runData.currentScore = 0
end

-- 选择继承技能
function Roguelike.setInheritedSkill(skillId)
    runData.inheritedSkill = skillId
end

-- 获取继承的技能
function Roguelike.getInheritedSkill()
    return runData.inheritedSkill
end

-- 获取难度系数
function Roguelike.getDifficultyMultiplier()
    return runData.difficultyMultiplier
end

-- 应用难度到敌人
function Roguelike.applyDifficultyToEnemy(enemy)
    local mult = runData.difficultyMultiplier
    enemy.hp = math.ceil(enemy.hp * mult)
    enemy.maxHp = enemy.hp

    for dir, val in pairs(enemy.attack) do
        enemy.attack[dir] = math.ceil(val * mult)
    end
end

-- 完全重置（新游戏+）
function Roguelike.hardReset()
    runData = {
        runNumber = 1,
        highestLevel = 0,
        totalRuns = 0,
        bestScore = 0,
        currentScore = 0,
        enemiesKilled = 0,
        damageDealt = 0,
        damageTaken = 0,
        inheritedSkill = nil,
        difficultyMultiplier = 1.0
    }
end

-- 获取统计信息（用于结算界面）
function Roguelike.getStats()
    return {
        runNumber = runData.runNumber,
        highestLevel = runData.highestLevel,
        totalRuns = runData.totalRuns,
        bestScore = runData.bestScore,
        difficultyMultiplier = runData.difficultyMultiplier
    }
end

return Roguelike
