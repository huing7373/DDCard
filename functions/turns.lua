-- functions/turns.lua
-- 回合管理模块
-- 从 main.lua 提取的回合相关函数

local Config = require("config")
local AI = require("ai")
local Skills = require("skills")

local GAME_STATE = Config.GAME_STATE
local GRID_SIZE = Config.GRID.SIZE

local Turns = {}

-- 结束玩家回合
-- @param context 包含: gameState, uiState, turnState
function Turns.endPlayerTurn(context)
    local gameState = context.gameState
    local uiState = context.uiState
    local turnState = context.turnState

    uiState.isMoving = false
    uiState.moveTargets = {}
    uiState.attackTargets = {}
    gameState.state = GAME_STATE.ENEMY_TURN
    turnState.currentEnemyIndex = 1
    turnState.enemyActionDelay = Config.TIMING.ENEMY_ACTION_DELAY
    print("Player turn end, enemy turn start")
end

-- 开始玩家回合
-- @param context 包含: gameState, enemies
function Turns.startPlayerTurn(context)
    local gameState = context.gameState
    local enemies = context.enemies

    gameState.state = GAME_STATE.PLAYER_TURN
    gameState.turnNumber = gameState.turnNumber + 1
    Skills.tickCooldowns()
    Turns.tickEnemyCooldowns(enemies)
    print(string.format("Turn %d - Player turn start", gameState.turnNumber))
end

-- 更新敌人技能冷却
function Turns.tickEnemyCooldowns(enemies)
    for _, enemy in ipairs(enemies) do
        if enemy.skills then
            for _, skill in ipairs(enemy.skills) do
                if skill.currentCooldown > 0 then
                    skill.currentCooldown = skill.currentCooldown - 1
                end
            end
        end
    end
end

-- 更新敌人回合
-- @param context 包含: dt, gameState, turnState, performEnemyAction, startPlayerTurn
function Turns.updateEnemyTurn(context)
    local dt = context.dt
    local gameState = context.gameState
    local turnState = context.turnState
    local performEnemyAction = context.performEnemyAction
    local onTurnEnd = context.onTurnEnd

    if turnState.enemyActionDelay > 0 then
        turnState.enemyActionDelay = turnState.enemyActionDelay - dt
        return false
    end

    if turnState.currentEnemyIndex > #gameState.enemies then
        if onTurnEnd then
            onTurnEnd()
        end
        return true
    end

    local enemy = gameState.enemies[turnState.currentEnemyIndex]
    if enemy and enemy.hp > 0 then
        performEnemyAction(enemy)
    end

    turnState.currentEnemyIndex = turnState.currentEnemyIndex + 1
    turnState.enemyActionDelay = Config.TIMING.ENEMY_ACTION_DELAY
    return false
end

-- 执行敌人行动
-- @param context 包含: enemy, gameState, createSkillContext, performAttack, moveCard, Card
function Turns.performEnemyAction(context)
    local enemy = context.enemy
    local gameState = context.gameState
    local createSkillContext = context.createSkillContext
    local performAttack = context.performAttack
    local moveCard = context.moveCard
    local Card = context.Card

    local gameContext = {
        grid = gameState.grid,
        gridSize = GRID_SIZE,
        player = gameState.player
    }

    local decision = AI.decideAction(enemy, gameContext, Card)

    if decision.type == "skill" then
        local skillData = decision.data
        local skill = skillData.skill
        local direction = skillData.direction

        local skillContext = createSkillContext()
        local success = skill.execute(enemy, direction, skillContext, skill.params or {})
        if success then
            skill.currentCooldown = skill.cooldown
            print(string.format("Enemy %s used skill: %s", enemy.name, skill.name))
        else
            print(string.format("Enemy %s failed to use skill: %s", enemy.name, skill.name))
        end
        return "skill", success
    elseif decision.type == "attack" then
        local attack = decision.data
        performAttack(enemy, attack.target, attack.direction)
        print(string.format("Enemy %s attacks player!", enemy.name))
        return "attack", true
    elseif decision.type == "move" then
        local move = decision.data
        moveCard(enemy, move.x, move.y)
        print(string.format("Enemy %s moved to (%d,%d)", enemy.name, move.x, move.y))
        return "move", true
    else
        print(string.format("Enemy %s waits", enemy.name))
        return "wait", true
    end
end

return Turns
