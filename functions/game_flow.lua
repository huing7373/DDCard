-- functions/game_flow.lua
-- 游戏流程模块
-- 从 main.lua 提取的游戏流程函数

local Config = require("config")
local Utils = require("utils")
local Grid = require("grid")
local Levels = require("levels")
local Roguelike = require("roguelike")
local Skills = require("skills")

local GAME_STATE = Config.GAME_STATE
local GRID_SIZE = Config.GRID.SIZE

local GameFlow = {}

-- 加载关卡
-- @param context 包含: levelIndex, gameState, uiState, placeCard, Card
function GameFlow.loadLevel(context)
    local levelIndex = context.levelIndex
    local gameState = context.gameState
    local uiState = context.uiState
    local placeCard = context.placeCard
    local Card = context.Card

    gameState.currentLevel = levelIndex
    local levelData = Levels.getLevel(levelIndex)

    if not levelData then
        print("No more levels!")
        gameState.state = GAME_STATE.VICTORY
        return false
    end

    -- 清除旧敌人
    for _, enemy in ipairs(gameState.enemies) do
        Grid.removeCard(gameState.grid, enemy)
    end
    gameState.enemies = {}

    -- 从卡牌列表移除敌人
    for i = #gameState.cards, 1, -1 do
        if gameState.cards[i].type == Card.TYPE.ENEMY then
            table.remove(gameState.cards, i)
        end
    end

    -- 生成敌人前重置玩家位置到默认位置
    if gameState.player then
        Grid.removeCard(gameState.grid, gameState.player)
        Grid.placeCard(gameState.grid, gameState.player, Config.PLAYER.DEFAULT_GRID_X, Config.PLAYER.DEFAULT_GRID_Y)
    end

    -- 根据难度缩放创建新敌人
    for _, enemyData in ipairs(levelData.enemies) do
        -- 如果敌人会生成在玩家位置则跳过
        if enemyData.x == gameState.player.gridX and enemyData.y == gameState.player.gridY then
            print(string.format("Warning: Enemy spawn at player position (%d,%d), skipping", enemyData.x, enemyData.y))
        else
            local enemyParams = Levels.createEnemyFromTemplate(enemyData.template, enemyData.x, enemyData.y)
            if enemyParams then
                enemyParams.type = Card.TYPE.ENEMY
                local enemy = Card.new(enemyParams)
                Roguelike.applyDifficultyToEnemy(enemy)
                placeCard(enemy)
            end
        end
    end

    -- 重置回合状态
    gameState.turnNumber = 1
    gameState.state = GAME_STATE.PLAYER_TURN
    uiState.showLevelSelect = false

    print(string.format("Enter Level %d: %s", levelIndex, levelData.name))
    return true
end

-- 重启游戏
-- @param context 包含: gameState, uiState, Anim, placeCard, loadLevel, Card
function GameFlow.restartGame(context)
    local gameState = context.gameState
    local uiState = context.uiState
    local Anim = context.Anim
    local placeCard = context.placeCard
    local Card = context.Card

    Grid.clear(gameState.grid, GRID_SIZE)

    gameState.cards = {}
    gameState.enemies = {}
    Anim.damage_texts = {}
    gameState.state = GAME_STATE.PLAYER_TURN
    gameState.turnNumber = 1
    gameState.currentLevel = 1
    uiState.showLevelSelect = false
    uiState.showUpgradeMenu = false
    uiState.showRewardSelect = false
    uiState.rewardOptions = {}
    uiState.selectedSkillIndex = nil
    uiState.isMoving = false
    uiState.moveTargets = {}
    uiState.attackTargets = {}

    local inheritedSkill = Roguelike.getInheritedSkill()
    Skills.reset()
    if inheritedSkill then
        Skills.learnSkill(inheritedSkill)
    end

    gameState.player = Card.new({
        name = "Demon Lord",
        type = Card.TYPE.PLAYER,
        hp = Config.PLAYER.DEFAULT_HP,
        maxHp = Config.PLAYER.DEFAULT_HP,
        attack = Utils.deepCopy(Config.PLAYER.DEFAULT_ATTACK),
        gridX = Config.PLAYER.DEFAULT_GRID_X,
        gridY = Config.PLAYER.DEFAULT_GRID_Y
    })
    placeCard(gameState.player)

    -- 加载第一关
    GameFlow.loadLevel({
        levelIndex = 1,
        gameState = gameState,
        uiState = uiState,
        placeCard = placeCard,
        Card = Card,
    })

    print("Game restarted!")
end

-- 开始新一轮
-- @param context 包含: restartGame
function GameFlow.startNewRun(context)
    local restartGame = context.restartGame

    local skills = Skills.getPlayerSkills()
    if #skills > 0 then
        Roguelike.setInheritedSkill(skills[1].id)
    end

    Roguelike.startNewRun()
    restartGame()
    print("New run started!")
end

-- 硬重置
-- @param context 包含: restartGame, Progression
function GameFlow.hardReset(context)
    local restartGame = context.restartGame
    local Progression = context.Progression

    Roguelike.hardReset()
    Progression.reset()
    restartGame()
    print("New Game+ started!")
end

-- 从奖励池中随机生成3个不重复的奖励选项
function GameFlow.generateRewardOptions()
    local pool = Utils.deepCopy(Config.LEVEL_REWARDS)
    local options = {}
    for i = 1, 3 do
        if #pool == 0 then break end
        local idx = math.random(#pool)
        table.insert(options, pool[idx])
        table.remove(pool, idx)
    end
    return options
end

-- 应用选中的奖励并继续下一关
-- @param context 包含: reward, gameState, uiState, loadLevel
function GameFlow.applyRewardAndContinue(context)
    local reward = context.reward
    local gameState = context.gameState
    local uiState = context.uiState
    local loadLevelFunc = context.loadLevel

    gameState.player.attack[reward.dir] = gameState.player.attack[reward.dir] + reward.bonus
    uiState.showRewardSelect = false
    uiState.rewardOptions = {}

    print(string.format("Reward applied: %s +%d", reward.dir, reward.bonus))

    -- 关卡过渡逻辑
    local levelData = Levels.getLevel(gameState.currentLevel)
    if levelData and #levelData.branches > 0 then
        uiState.showLevelSelect = true
    elseif gameState.currentLevel >= Levels.getLevelCount() then
        gameState.state = GAME_STATE.VICTORY
        gameState.runResult = Roguelike.endRun(true, gameState.currentLevel)
        uiState.showSettlement = true
    else
        loadLevelFunc(gameState.currentLevel + 1)
    end
end

-- 检查游戏结束
-- @param context 包含: gameState, uiState, generateRewardOptions
function GameFlow.checkGameEnd(context)
    local gameState = context.gameState
    local uiState = context.uiState

    if gameState.state == GAME_STATE.GAME_OVER or gameState.state == GAME_STATE.VICTORY or uiState.showLevelSelect or uiState.showSettlement or uiState.showRewardSelect then
        return nil
    end

    if gameState.player == nil or gameState.player.hp <= 0 then
        gameState.state = GAME_STATE.GAME_OVER
        gameState.runResult = Roguelike.endRun(false, gameState.currentLevel)
        uiState.showSettlement = true
        print("Game Over - Player defeated")
        return "game_over"
    elseif #gameState.enemies == 0 then
        -- 显示奖励选择界面而不是立即继续
        uiState.rewardOptions = GameFlow.generateRewardOptions()
        uiState.showRewardSelect = true
        print("Level complete! Choose your reward...")
        return "level_complete"
    end

    return nil
end

return GameFlow
