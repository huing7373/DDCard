-- 魔王 - 主入口
-- Love2D 游戏框架

-- 加载新架构模块 (阶段 1-6)
require("globals")
local Object = require("engine.object")
local Moveable = require("engine.moveable")
local EventModule = require("engine.event")
local Animation = require("systems.animation")
local StateMachine = require("systems.state_machine")
local UIModule = require("systems.ui_manager")
local Game = require("game")

-- 加载模块
local Config = require("config")
local Utils = require("utils")
local UI = require("ui")
local Combat = require("combat")
local Grid = require("grid")
local Card = require("card")
local AI = require("ai")
local Levels = require("levels")
local Progression = require("progression")
local Skills = require("skills")
local Roguelike = require("roguelike")
local Draw = require("functions.draw")

-- 常用配置值的本地引用
local GRID_SIZE = Config.GRID.SIZE
local CELL_SIZE = Config.GRID.CELL_SIZE
local GRID_OFFSET_X = Config.GRID.OFFSET_X
local GRID_OFFSET_Y = Config.GRID.OFFSET_Y
local DIRECTIONS = Config.DIRECTIONS
local GAME_STATE = Config.GAME_STATE

-- 核心游戏状态
local gameState = {
    grid = {},
    cards = {},
    enemies = {},
    player = nil,
    state = GAME_STATE.PLAYER_TURN,
    turnNumber = 1,
    currentLevel = 1,
    lastReward = nil,
    runResult = nil,
}

-- UI状态
local uiState = {
    hoveredCard = nil,
    selectedCard = nil,
    moveTargets = {},
    attackTargets = {},
    isMoving = false,
    showLevelSelect = false,
    showUpgradeMenu = false,
    showSettlement = false,
    selectedSkillIndex = nil,
    showRewardSelect = false,   -- 是否显示奖励选择界面
    rewardOptions = {},         -- 当前三个奖励选项
}

-- 动画系统单例 (新架构)
local Anim = Animation.getInstance()

-- 敌人回合状态 (游戏逻辑，非动画)
local turnState = {
    enemyActionDelay = 0,
    currentEnemyIndex = 0,
}

-- UI按钮
local buttons = {}

-- 本地函数前向声明
local placeCard, removeCard, moveCard
local enterMoveMode, endPlayerTurn, startPlayerTurn
local performAttack, grantKillReward
local createDamageText, checkGameEnd
local loadLevel, restartGame
local createSkillContext

-- 初始化游戏
function love.load()
    -- 初始化 Game 单例 (新架构)
    local game = Game.getInstance()
    game:start_up()

    -- 使用 Game 加载的字体，或回退到手动加载
    if G.FONT and G.FONT.NORMAL then
        love.graphics.setFont(G.FONT.NORMAL)
    else
        -- 回退：手动加载字体
        local fontPath = "resources/fonts/msyh.ttc"
        local success, font = pcall(love.graphics.newFont, fontPath, 14)
        if success then
            love.graphics.setFont(font)
        else
            love.graphics.setNewFont(14)
            print("Warning: Chinese font not found, using default font")
        end
    end

    -- 初始化网格
    gameState.grid = Grid.new(GRID_SIZE)

    -- 创建玩家卡牌
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
    loadLevel(1)

    -- 初始化技能系统
    Skills.init()

    -- 初始化游戏状态机 (新架构)
    G.STATE_MACHINE = StateMachine({
        initial_state = G.STATES.PLAYER_TURN,
        on_state_change = function(old_state, new_state)
            -- 同步到 gameState.state (兼容层)
            gameState.state = G.STATE_NAMES[new_state] and
                GAME_STATE[G.STATE_NAMES[new_state]] or new_state
        end
    })

    -- 定义状态
    G.STATE_MACHINE:define_state(G.STATES.PLAYER_TURN, {})
    G.STATE_MACHINE:define_state(G.STATES.ENEMY_TURN, {})
    G.STATE_MACHINE:define_state(G.STATES.GAME_OVER, {})
    G.STATE_MACHINE:define_state(G.STATES.VICTORY, {})

    -- 创建UI按钮
    buttons = {
        UI.createButton(620, 200, 100, 30, "End Turn", function()
            if gameState.state == GAME_STATE.PLAYER_TURN then
                endPlayerTurn()
            end
        end),
        UI.createButton(620, 240, 100, 30, "Restart", function()
            restartGame()
        end)
    }

    print("魔王 - 游戏初始化完成")
end

-- 将卡牌放置到网格上
placeCard = function(card)
    Grid.placeCard(gameState.grid, card, card.gridX, card.gridY)
    table.insert(gameState.cards, card)
    if card.type == Card.TYPE.ENEMY then
        table.insert(gameState.enemies, card)
    end
end

-- 从网格移除卡牌
removeCard = function(card)
    Grid.removeCard(gameState.grid, card)
    Utils.removeFromList(gameState.cards, card)
    if card.type == Card.TYPE.ENEMY then
        Utils.removeFromList(gameState.enemies, card)
    end
    -- 清除已移除卡牌的UI引用
    if uiState.selectedCard == card then
        uiState.selectedCard = nil
    end
    if uiState.hoveredCard == card then
        uiState.hoveredCard = nil
    end
    print(string.format("%s defeated!", card.name))
end

-- 移动卡牌到新位置
moveCard = function(card, newX, newY)
    Grid.moveCard(gameState.grid, card, newX, newY)
end

-- 加载关卡
loadLevel = function(levelIndex)
    gameState.currentLevel = levelIndex
    local levelData = Levels.getLevel(levelIndex)

    if not levelData then
        print("No more levels!")
        gameState.state = GAME_STATE.VICTORY
        return
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
end

-- 更新屏幕震动 (使用 Animation 系统)
local function updateScreenShake(dt)
    Anim:update_screen_shake(dt)
end

-- 触发屏幕震动 (使用 Animation 系统)
local function triggerScreenShake(intensity, duration)
    Anim:shake(intensity, duration)
end

-- 更新技能特效 (使用 Animation 系统)
local function updateSkillEffects(dt)
    Anim:update_skill_effects(dt)
end

-- 创建技能特效 (使用 Animation 系统)
local function createSkillEffect(effectType, params)
    Anim:add_skill_effect({
        type = effectType,
        center_x = params.centerX,
        center_y = params.centerY,
        duration = params.duration or Config.EFFECTS.SKILL_EFFECT_DURATION,
        data = params,
    })
end

-- 创建技能执行上下文（玩家和敌人共用）
createSkillContext = function()
    return {
        player = gameState.player,
        grid = gameState.grid,
        DIRECTIONS = DIRECTIONS,
        moveCard = moveCard,
        removeCard = removeCard,
        createDamageText = function(target, damage)
            local screenX, screenY = Utils.getGridCellCenter(target.gridX, target.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
            createDamageText(screenX, screenY, damage, Config.COLORS.DAMAGE)
            if target.triggerFlash then
                target:triggerFlash(Config.EFFECTS.FLASH_DURATION)
            end
        end,
        createHealText = function(target, heal)
            local screenX, screenY = Utils.getGridCellCenter(target.gridX, target.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
            createDamageText(screenX, screenY - 20, "+" .. heal, Config.COLORS.HEAL, false)
        end,
        createShieldText = function(target, amount)
            local screenX, screenY = Utils.getGridCellCenter(target.gridX, target.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
            createDamageText(screenX, screenY - 20, "+" .. amount .. " Shield", Config.COLORS.SHIELD, false)
        end,
        triggerScreenShake = function(intensity, duration)
            triggerScreenShake(intensity or Config.EFFECTS.SKILL_SHAKE_INTENSITY, duration or Config.EFFECTS.SHAKE_DURATION)
        end,
        createSkillEffect = function(effectType, params)
            createSkillEffect(effectType, params)
        end,
        getScreenPos = function(gridX, gridY)
            return Utils.getGridCellCenter(gridX, gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
        end,
    }
end

-- 更新卡牌闪烁计时器
local function updateCardEffects(dt)
    for _, card in ipairs(gameState.cards) do
        if card.update then
            card:update(dt)
        end
    end
end

-- 更新游戏逻辑
function love.update(dt)
    -- 更新 Game 单例 (事件队列、Moveable 实体)
    local game = Game.getInstance()
    game:update(dt)

    local mx, my = love.mouse.getPosition()
    -- 调整屏幕震动偏移
    local adjustedMx = mx - Anim.screen_shake.offsetX
    local adjustedMy = my - Anim.screen_shake.offsetY
    uiState.hoveredCard = getCardAtScreen(adjustedMx, adjustedMy)

    updateDamageTexts(dt)
    updateScreenShake(dt)
    updateSkillEffects(dt)
    updateCardEffects(dt)

    if gameState.state == GAME_STATE.ENEMY_TURN then
        updateEnemyTurn(dt)
    end

    checkGameEnd()
end

-- 绘制技能特效 (委托给 Draw 模块)
local function drawSkillEffects()
    Draw.skillEffects(Anim.skill_effects)
end

-- 绘制游戏
function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    -- 应用屏幕震动偏移
    local shakeX = Anim.screen_shake.offsetX
    local shakeY = Anim.screen_shake.offsetY
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- 标题
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.print("Demon Lord", 10, 10)

    drawGrid()
    drawSkillEffects()
    drawCardDetailPanel()
    drawDamageTexts()
    drawTurnInfo()
    drawButtons()
    drawSkillBar()

    love.graphics.pop()  -- 结束屏幕震动变换

    if gameState.state == GAME_STATE.GAME_OVER or gameState.state == GAME_STATE.VICTORY then
        love.graphics.push()
        love.graphics.translate(-shakeX, -shakeY)  -- 移除UI覆盖层的震动
        drawGameEndScreen()
        love.graphics.pop()
    end

    if uiState.showLevelSelect then
        love.graphics.push()
        love.graphics.translate(-shakeX, -shakeY)
        drawLevelSelect()
        love.graphics.pop()
    end

    if uiState.showUpgradeMenu then
        love.graphics.push()
        love.graphics.translate(-shakeX, -shakeY)
        drawUpgradeMenu()
        love.graphics.pop()
    end

    if uiState.showRewardSelect then
        love.graphics.push()
        love.graphics.translate(-shakeX, -shakeY)
        drawRewardSelect()
        love.graphics.pop()
    end

    drawProgressionInfo()

    -- 帮助文本
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Roguelike | U=Upgrade | 1-4=Skills", 10, 550)
    if gameState.state == GAME_STATE.PLAYER_TURN then
        if uiState.isMoving then
            love.graphics.setColor(0.3, 0.9, 0.3)
            love.graphics.print("Green=Move Red=Attack | RightClick=Cancel | E=End Turn", 10, 570)
        else
            love.graphics.print("Click card or Space to act | E=End Turn", 10, 570)
        end
    elseif gameState.state == GAME_STATE.ENEMY_TURN then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.print("Enemy turn...", 10, 570)
    end
end

-- 绘制网格 (委托给 Draw 模块)
function drawGrid()
    Draw.grid(gameState, uiState)
end

-- 键盘输入
function love.keypressed(key)
    -- 游戏结束输入
    if gameState.state == GAME_STATE.GAME_OVER or gameState.state == GAME_STATE.VICTORY then
        if key == "r" then
            startNewRun()
        elseif key == "n" then
            hardReset()
        end
        return
    end

    if gameState.state ~= GAME_STATE.PLAYER_TURN then
        return
    end

    if key == "escape" then
        if uiState.showUpgradeMenu then
            uiState.showUpgradeMenu = false
        elseif uiState.isMoving then
            uiState.isMoving = false
            uiState.moveTargets = {}
            uiState.attackTargets = {}
        else
            love.event.quit()
        end
    elseif key == "space" or key == "m" then
        if gameState.player then
            enterMoveMode(gameState.player)
        end
    elseif key == "e" then
        endPlayerTurn()
    elseif key == "u" then
        uiState.showUpgradeMenu = not uiState.showUpgradeMenu
    elseif key == "1" or key == "2" or key == "3" or key == "4" then
        local skillIndex = tonumber(key)
        local skills = Skills.getPlayerSkills()
        if skills[skillIndex] and skills[skillIndex].currentCooldown == 0 then
            uiState.selectedSkillIndex = skillIndex
            enterMoveMode(gameState.player)
        end
    elseif uiState.isMoving then
        local dirKey = nil
        if key == "up" or key == "w" then dirKey = "n"
        elseif key == "down" or key == "s" then dirKey = "s"
        elseif key == "left" or key == "a" then dirKey = "w"
        elseif key == "right" or key == "d" then dirKey = "e"
        end

        if dirKey then
            if uiState.selectedSkillIndex then
                useSelectedSkill(dirKey)
            else
                local dir = DIRECTIONS[dirKey]
                local newX = gameState.player.gridX + dir.dx
                local newY = gameState.player.gridY + dir.dy
                if not tryAttackAtDirection(gameState.player, dirKey) then
                    tryMoveCard(gameState.player, newX, newY)
                end
            end
        end
    end
end

-- 使用选中的技能
function useSelectedSkill(direction)
    if not uiState.selectedSkillIndex then return end

    local gameContext = createSkillContext()
    local success, msg = Skills.useSkill(uiState.selectedSkillIndex, direction, gameContext)

    uiState.selectedSkillIndex = nil
    uiState.isMoving = false
    uiState.moveTargets = {}
    uiState.attackTargets = {}

    if success then
        endPlayerTurn()
    else
        print("Skill failed: " .. (msg or "unknown"))
    end
end

-- 鼠标点击
function love.mousepressed(x, y, button)
    if gameState.state == GAME_STATE.GAME_OVER or gameState.state == GAME_STATE.VICTORY then
        return
    end

    -- 调整屏幕震动偏移
    local adjustedX = x - Anim.screen_shake.offsetX
    local adjustedY = y - Anim.screen_shake.offsetY

    -- 奖励选择
    if uiState.showRewardSelect and button == 1 then
        handleRewardSelectClick(adjustedX, adjustedY)
        return
    end

    -- 关卡选择
    if uiState.showLevelSelect and button == 1 then
        handleLevelSelectClick(adjustedX, adjustedY)
        return
    end

    -- 升级菜单
    if uiState.showUpgradeMenu and button == 1 then
        handleUpgradeMenuClick(adjustedX, adjustedY)
        return
    end

    -- UI按钮点击
    if button == 1 and UI.handleButtonClick(buttons, adjustedX, adjustedY) then
        return
    end

    if gameState.state ~= GAME_STATE.PLAYER_TURN then
        return
    end

    if button == 1 then
        local clickedCard = getCardAtScreen(adjustedX, adjustedY)
        local gridPos = getGridAtScreen(adjustedX, adjustedY)

        if uiState.isMoving and gridPos then
            local attackResult = tryAttackAt(gameState.player, gridPos.x, gridPos.y)
            if not attackResult then
                tryMoveCard(gameState.player, gridPos.x, gridPos.y)
            end
        elseif clickedCard and clickedCard.type == Card.TYPE.PLAYER then
            enterMoveMode(clickedCard)
        else
            uiState.selectedCard = clickedCard
        end
    elseif button == 2 then
        uiState.isMoving = false
        uiState.moveTargets = {}
        uiState.attackTargets = {}
        uiState.selectedCard = nil
        uiState.selectedSkillIndex = nil
    end
end

-- 处理关卡选择点击
function handleLevelSelectClick(x, y)
    local levelData = Levels.getLevel(gameState.currentLevel)
    if not levelData then return end

    local startY = 220
    for i, branchIndex in ipairs(levelData.branches) do
        local btnX, btnY = 250, startY + (i - 1) * 70
        local btnW, btnH = Config.UI.LEVEL_BTN_WIDTH, Config.UI.LEVEL_BTN_HEIGHT

        if Utils.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
            loadLevel(branchIndex)
            return
        end
    end
end

-- 处理升级菜单点击
function handleUpgradeMenuClick(x, y)
    local upgrades = Progression.getAvailableUpgrades()
    local startY = 120
    for i, info in ipairs(upgrades) do
        local btnX, btnY = 200, startY + (i - 1) * 55
        local btnW, btnH = Config.UI.UPGRADE_BTN_WIDTH, Config.UI.UPGRADE_BTN_HEIGHT

        if Utils.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
            if info.canBuy and not info.owned then
                Progression.buyUpgrade(info.upgrade.id)
                print("Bought upgrade: " .. info.upgrade.name)
            end
            return
        end
    end
end

-- 获取屏幕位置的卡牌
function getCardAtScreen(screenX, screenY)
    local gridPos = getGridAtScreen(screenX, screenY)
    if gridPos then
        return Grid.getCard(gameState.grid, gridPos.x, gridPos.y)
    end
    return nil
end

-- 从屏幕坐标获取网格位置
function getGridAtScreen(screenX, screenY)
    local gridX, gridY = Utils.screenToGrid(screenX, screenY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE, GRID_SIZE)
    if gridX then
        return { x = gridX, y = gridY }
    end
    return nil
end

-- 进入移动/攻击模式
enterMoveMode = function(card)
    uiState.isMoving = true
    uiState.selectedCard = card
    uiState.moveTargets, uiState.attackTargets = Grid.findTargets(gameState.grid, card, DIRECTIONS, GRID_SIZE)
end

-- 尝试移动卡牌
function tryMoveCard(card, targetX, targetY)
    local found = Utils.isInTargetList(targetX, targetY, uiState.moveTargets)
    if found then
        moveCard(card, targetX, targetY)
        uiState.isMoving = false
        uiState.moveTargets = {}
        uiState.attackTargets = {}
        if card.type == Card.TYPE.PLAYER then
            endPlayerTurn()
        end
        return true
    end
    return false
end

-- 尝试向指定方向攻击
function tryAttackAtDirection(attacker, dirKey)
    for _, target in ipairs(uiState.attackTargets) do
        if target.direction == dirKey then
            performAttack(attacker, target.target, target.direction)
            uiState.isMoving = false
            uiState.moveTargets = {}
            uiState.attackTargets = {}
            if attacker.type == Card.TYPE.PLAYER then
                endPlayerTurn()
            end
            return true
        end
    end
    return false
end

-- 尝试在指定位置攻击
function tryAttackAt(attacker, targetX, targetY)
    for _, target in ipairs(uiState.attackTargets) do
        if target.x == targetX and target.y == targetY then
            performAttack(attacker, target.target, target.direction)
            uiState.isMoving = false
            uiState.moveTargets = {}
            uiState.attackTargets = {}
            if attacker.type == Card.TYPE.PLAYER then
                endPlayerTurn()
            end
            return true
        end
    end
    return false
end

-- 执行攻击
performAttack = function(attacker, defender, direction)
    local attackerDamage, defenderDamage = Combat.calculateDamage(attacker, defender, direction, DIRECTIONS)
    local defenderKilled, attackerKilled = Combat.applyDamage(attacker, defender, attackerDamage, defenderDamage)

    -- 创建伤害文本动画
    local attackerScreenX, attackerScreenY = Utils.getGridCellCenter(attacker.gridX, attacker.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
    local defenderScreenX, defenderScreenY = Utils.getGridCellCenter(defender.gridX, defender.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)

    if attackerDamage > 0 then
        createDamageText(defenderScreenX, defenderScreenY, attackerDamage, Config.COLORS.DAMAGE)
        -- 触发防御者闪烁
        if defender.triggerFlash then
            defender:triggerFlash(Config.EFFECTS.FLASH_DURATION)
        end
        -- 触发屏幕震动
        triggerScreenShake(Config.EFFECTS.SHAKE_INTENSITY, Config.EFFECTS.SHAKE_DURATION)
    end
    if defenderDamage > 0 then
        createDamageText(attackerScreenX, attackerScreenY, defenderDamage, Config.COLORS.COUNTER_DAMAGE)
        -- 反击触发攻击者闪烁
        if attacker.triggerFlash then
            attacker:triggerFlash(Config.EFFECTS.FLASH_DURATION)
        end
    end

    -- 处理死亡和奖励
    if defenderKilled then
        if attacker.hp > 0 then
            grantKillReward(attacker, defender)
        end
        removeCard(defender)
    end

    if attackerKilled then
        if defender.hp > 0 then
            grantKillReward(defender, attacker)
        end
        removeCard(attacker)
    end

    print(string.format("Attack! %s -> %s: %d dmg, counter: %d dmg",
        attacker.name, defender.name, attackerDamage, defenderDamage))
end

-- 发放击杀奖励
grantKillReward = function(killer, victim)
    local hpRecover, randomDir, atkBonus = Combat.calculateKillReward(victim, Config)
    Combat.applyHpRecovery(killer, hpRecover)

    local killerScreenX, killerScreenY = Utils.getGridCellCenter(killer.gridX, killer.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
    createDamageText(killerScreenX, killerScreenY - 20, "+" .. hpRecover, Config.COLORS.HEAL)

    if killer.type == Card.TYPE.PLAYER then
        Combat.applyAtkBonus(killer, randomDir, atkBonus)

        gameState.lastReward = {
            hpRecover = hpRecover,
            atkDir = randomDir,
            atkBonus = atkBonus
        }

        local soulReward = Combat.calculateSoulReward(victim)
        Progression.addSoulFragments(soulReward)
        -- 已移除: Progression.addExp(victim.maxHp) - 击杀不再获得经验值

        createDamageText(killerScreenX + 30, killerScreenY - 30, "+" .. soulReward .. " Soul", Config.COLORS.SOUL)

        Roguelike.recordKill()

        local absorbedSkill = Skills.absorbSkill(victim.name)
        if absorbedSkill then
            print("Absorbed new skill!")
        end

        print(string.format("Kill reward: +%d HP, %s atk+%d, soul+%d",
            hpRecover, randomDir, atkBonus, soulReward))

        -- 注意：击杀不再获得经验值，奖励在关卡结束时发放
    end
end

-- 结束玩家回合
endPlayerTurn = function()
    uiState.isMoving = false
    uiState.moveTargets = {}
    uiState.attackTargets = {}
    gameState.state = GAME_STATE.ENEMY_TURN
    turnState.currentEnemyIndex = 1
    turnState.enemyActionDelay = Config.TIMING.ENEMY_ACTION_DELAY
    print("Player turn end, enemy turn start")
end

-- 更新敌人回合
function updateEnemyTurn(dt)
    if turnState.enemyActionDelay > 0 then
        turnState.enemyActionDelay = turnState.enemyActionDelay - dt
        return
    end

    if turnState.currentEnemyIndex > #gameState.enemies then
        startPlayerTurn()
        return
    end

    local enemy = gameState.enemies[turnState.currentEnemyIndex]
    if enemy and enemy.hp > 0 then
        performEnemyAction(enemy)
    end

    turnState.currentEnemyIndex = turnState.currentEnemyIndex + 1
    turnState.enemyActionDelay = Config.TIMING.ENEMY_ACTION_DELAY
end

-- 执行敌人行动
function performEnemyAction(enemy)
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
    elseif decision.type == "attack" then
        local attack = decision.data
        performAttack(enemy, attack.target, attack.direction)
        print(string.format("Enemy %s attacks player!", enemy.name))
    elseif decision.type == "move" then
        local move = decision.data
        moveCard(enemy, move.x, move.y)
        print(string.format("Enemy %s moved to (%d,%d)", enemy.name, move.x, move.y))
    else
        print(string.format("Enemy %s waits", enemy.name))
    end
end

-- 更新敌人技能冷却
local function tickEnemyCooldowns()
    for _, enemy in ipairs(gameState.enemies) do
        if enemy.skills then
            for _, skill in ipairs(enemy.skills) do
                if skill.currentCooldown > 0 then
                    skill.currentCooldown = skill.currentCooldown - 1
                end
            end
        end
    end
end

-- 开始玩家回合
startPlayerTurn = function()
    gameState.state = GAME_STATE.PLAYER_TURN
    gameState.turnNumber = gameState.turnNumber + 1
    Skills.tickCooldowns()
    tickEnemyCooldowns()
    print(string.format("Turn %d - Player turn start", gameState.turnNumber))
end

-- 从奖励池中随机生成3个不重复的奖励选项
local function generateRewardOptions()
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
local function applyRewardAndContinue(reward)
    gameState.player.attack[reward.dir] = gameState.player.attack[reward.dir] + reward.bonus
    uiState.showRewardSelect = false
    uiState.rewardOptions = {}

    print(string.format("Reward applied: %s +%d", reward.dir, reward.bonus))

    -- 原关卡过渡逻辑
    local levelData = Levels.getLevel(gameState.currentLevel)
    if levelData and #levelData.branches > 0 then
        uiState.showLevelSelect = true
    elseif gameState.currentLevel >= Levels.getLevelCount() then
        gameState.state = GAME_STATE.VICTORY
        gameState.runResult = Roguelike.endRun(true, gameState.currentLevel)
        uiState.showSettlement = true
    else
        loadLevel(gameState.currentLevel + 1)
    end
end

-- 检查游戏结束
checkGameEnd = function()
    if gameState.state == GAME_STATE.GAME_OVER or gameState.state == GAME_STATE.VICTORY or uiState.showLevelSelect or uiState.showSettlement or uiState.showRewardSelect then
        return
    end

    if gameState.player == nil or gameState.player.hp <= 0 then
        gameState.state = GAME_STATE.GAME_OVER
        gameState.runResult = Roguelike.endRun(false, gameState.currentLevel)
        uiState.showSettlement = true
        print("Game Over - Player defeated")
    elseif #gameState.enemies == 0 then
        -- 显示奖励选择界面而不是立即继续
        uiState.rewardOptions = generateRewardOptions()
        uiState.showRewardSelect = true
        print("Level complete! Choose your reward...")
    end
end

-- 重启游戏
restartGame = function()
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

    loadLevel(1)
    print("Game restarted!")
end

-- 开始新一轮
function startNewRun()
    local skills = Skills.getPlayerSkills()
    if #skills > 0 then
        Roguelike.setInheritedSkill(skills[1].id)
    end

    Roguelike.startNewRun()
    restartGame()
    print("New run started!")
end

-- 硬重置
function hardReset()
    Roguelike.hardReset()
    Progression.reset()
    restartGame()
    print("New Game+ started!")
end

-- 创建伤害文本动画
createDamageText = function(x, y, damage, color, useScale)
    local text
    if type(damage) == "string" then
        text = damage
    else
        text = "-" .. damage
    end

    -- 默认对伤害数字使用缩放（不包括治疗/护盾文本）
    local shouldScale = useScale
    if shouldScale == nil then
        shouldScale = type(damage) == "number"
    end

    table.insert(Anim.damage_texts, {
        x = x,
        y = y,
        text = text,
        color = color,
        alpha = 1,
        timer = 0,
        duration = Config.TIMING.DAMAGE_TEXT_DURATION,
        useScale = shouldScale,
    })
end

-- 更新伤害文本
function updateDamageTexts(dt)
    for i = #Anim.damage_texts, 1, -1 do
        local dmg = Anim.damage_texts[i]
        dmg.timer = dmg.timer + dt
        dmg.y = dmg.y - Config.TIMING.DAMAGE_TEXT_SPEED * dt
        dmg.alpha = 1 - (dmg.timer / dmg.duration)

        if dmg.timer >= dmg.duration then
            table.remove(Anim.damage_texts, i)
        end
    end
end

-- 绘制伤害文本 (委托给 Draw 模块)
function drawDamageTexts()
    Draw.damageTexts(Anim.damage_texts)
end

-- 绘制卡牌详情面板 (委托给 Draw 模块)
function drawCardDetailPanel()
    Draw.cardDetailPanel(uiState, Card)
end

-- 绘制回合信息 (委托给 Draw 模块)
function drawTurnInfo()
    Draw.turnInfo(gameState, GAME_STATE)
end

-- 绘制按钮 (委托给 Draw 模块)
function drawButtons()
    Draw.buttons(buttons)
end

-- 绘制关卡选择 (委托给 Draw 模块)
function drawLevelSelect()
    Draw.levelSelect(gameState)
end

-- 绘制奖励选择界面 (委托给 Draw 模块)
function drawRewardSelect()
    Draw.rewardSelect(uiState.rewardOptions)
end

-- 处理奖励选择点击
function handleRewardSelectClick(x, y)
    local startY = 200
    for i, reward in ipairs(uiState.rewardOptions) do
        local btnX, btnY = 200, startY + (i - 1) * 80
        local btnW, btnH = 400, 60

        if Utils.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
            applyRewardAndContinue(reward)
            return
        end
    end
end

-- 绘制进度信息 (委托给 Draw 模块)
function drawProgressionInfo()
    Draw.progressionInfo()
end

-- 绘制技能栏 (委托给 Draw 模块)
function drawSkillBar()
    Draw.skillBar(uiState)
end

-- 绘制升级菜单 (委托给 Draw 模块)
function drawUpgradeMenu()
    Draw.upgradeMenu()
end

-- 绘制游戏结束屏幕 (委托给 Draw 模块)
function drawGameEndScreen()
    Draw.gameEndScreen(gameState, GAME_STATE)
end
