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

-- 动画状态
local animState = {
    damageTexts = {},
    enemyActionDelay = 0,
    currentEnemyIndex = 0,
    screenShake = {
        intensity = 0,
        timer = 0,
        offsetX = 0,
        offsetY = 0,
    },
    skillEffects = {},
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

-- 更新屏幕震动
local function updateScreenShake(dt)
    local shake = animState.screenShake
    if shake.timer > 0 then
        shake.timer = shake.timer - dt
        local progress = shake.timer / Config.EFFECTS.SHAKE_DURATION
        local currentIntensity = shake.intensity * progress
        shake.offsetX = (math.random() * 2 - 1) * currentIntensity
        shake.offsetY = (math.random() * 2 - 1) * currentIntensity
    else
        shake.offsetX = 0
        shake.offsetY = 0
        shake.intensity = 0
    end
end

-- 触发屏幕震动
local function triggerScreenShake(intensity, duration)
    animState.screenShake.intensity = intensity or Config.EFFECTS.SHAKE_INTENSITY
    animState.screenShake.timer = duration or Config.EFFECTS.SHAKE_DURATION
end

-- 更新技能特效
local function updateSkillEffects(dt)
    for i = #animState.skillEffects, 1, -1 do
        local effect = animState.skillEffects[i]
        effect.timer = effect.timer + dt
        if effect.timer >= effect.duration then
            table.remove(animState.skillEffects, i)
        end
    end
end

-- 创建技能特效
local function createSkillEffect(effectType, params)
    local effect = {
        type = effectType,
        timer = 0,
        duration = params.duration or Config.EFFECTS.SKILL_EFFECT_DURATION,
    }
    for k, v in pairs(params) do
        effect[k] = v
    end
    table.insert(animState.skillEffects, effect)
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
    local adjustedMx = mx - animState.screenShake.offsetX
    local adjustedMy = my - animState.screenShake.offsetY
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

-- 绘制技能特效
local function drawSkillEffects()
    for _, effect in ipairs(animState.skillEffects) do
        local progress = effect.timer / effect.duration
        local alpha = 1 - progress

        if effect.type == "charge_trail" then
            -- 从起点到终点绘制黄色线条
            love.graphics.setColor(1, 0.9, 0.3, alpha * 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.line(effect.startX, effect.startY, effect.endX, effect.endY)
            love.graphics.setLineWidth(1)

        elseif effect.type == "whirlwind_area" then
            -- 在周围8格绘制红色高亮
            local cellSize = CELL_SIZE
            for _, dir in pairs(DIRECTIONS) do
                local cellX = effect.centerX + dir.dx * cellSize
                local cellY = effect.centerY + dir.dy * cellSize
                love.graphics.setColor(1, 0.3, 0.3, alpha * 0.5)
                love.graphics.rectangle("fill", cellX - cellSize/2, cellY - cellSize/2, cellSize, cellSize)
            end

        elseif effect.type == "lifesteal_line" then
            -- 先绘制红色伤害线再绘制绿色治疗线
            local midProgress = progress * 2
            if midProgress < 1 then
                -- 伤害线
                love.graphics.setColor(1, 0.3, 0.3, alpha)
                love.graphics.setLineWidth(2)
                love.graphics.line(effect.startX, effect.startY, effect.endX, effect.endY)
            else
                -- 治疗线（反向）
                love.graphics.setColor(0.3, 1, 0.3, alpha)
                love.graphics.setLineWidth(2)
                love.graphics.line(effect.endX, effect.endY, effect.startX, effect.startY)
            end
            love.graphics.setLineWidth(1)

        elseif effect.type == "shield_ring" then
            -- 绘制扩展的蓝色圆环
            local radius = 20 + progress * 30
            love.graphics.setColor(0.3, 0.6, 1, alpha * 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", effect.centerX, effect.centerY, radius)
            love.graphics.setLineWidth(1)
        end
    end
end

-- 绘制游戏
function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    -- 应用屏幕震动偏移
    local shakeX = animState.screenShake.offsetX
    local shakeY = animState.screenShake.offsetY
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

-- 绘制网格
function drawGrid()
    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            local cellX = GRID_OFFSET_X + (x - 1) * CELL_SIZE
            local cellY = GRID_OFFSET_Y + (y - 1) * CELL_SIZE

            -- 棋盘格图案
            if (x + y) % 2 == 0 then
                love.graphics.setColor(Config.COLORS.GRID_EVEN)
            else
                love.graphics.setColor(Config.COLORS.GRID_ODD)
            end
            love.graphics.rectangle("fill", cellX, cellY, CELL_SIZE, CELL_SIZE)

            -- 检查目标（获取攻击力目标信息）
            local isMoveTarget, moveTarget = Utils.isInTargetList(x, y, uiState.moveTargets)
            local isAttackTarget, attackTarget = Utils.isInTargetList(x, y, uiState.attackTargets)

            -- 高亮目标
            if isMoveTarget then
                local hasAttackPower = moveTarget and moveTarget.attackPower and moveTarget.attackPower > 0
                if hasAttackPower then
                    love.graphics.setColor(Config.COLORS.MOVE_TARGET)
                else
                    love.graphics.setColor(Config.COLORS.MOVE_TARGET_DIM)
                end
                love.graphics.rectangle("fill", cellX, cellY, CELL_SIZE, CELL_SIZE)
            end
            if isAttackTarget then
                love.graphics.setColor(Config.COLORS.ATTACK_TARGET)
                love.graphics.rectangle("fill", cellX, cellY, CELL_SIZE, CELL_SIZE)
            end

            -- 边框
            if isAttackTarget then
                love.graphics.setColor(Config.COLORS.ATTACK_BORDER)
            elseif isMoveTarget then
                local hasAttackPower = moveTarget and moveTarget.attackPower and moveTarget.attackPower > 0
                if hasAttackPower then
                    love.graphics.setColor(Config.COLORS.MOVE_BORDER)
                else
                    love.graphics.setColor(Config.COLORS.MOVE_BORDER_DIM)
                end
            else
                love.graphics.setColor(Config.COLORS.GRID_BORDER)
            end
            love.graphics.rectangle("line", cellX, cellY, CELL_SIZE, CELL_SIZE)

            -- 绘制卡牌或坐标
            local cell = gameState.grid[y][x]
            if cell.card then
                cell.card:draw(cellX, cellY, CELL_SIZE)
            else
                -- 在移动目标上显示攻击力指示器
                if isMoveTarget and moveTarget and moveTarget.attackPower and moveTarget.attackPower > 0 then
                    love.graphics.setColor(Config.COLORS.ATTACK_POWER_TEXT)
                    local atkText = tostring(moveTarget.attackPower)
                    local font = love.graphics.getFont()
                    local textW = font:getWidth(atkText)
                    local textH = font:getHeight()
                    love.graphics.print(atkText, cellX + CELL_SIZE/2 - textW/2, cellY + CELL_SIZE/2 - textH/2)
                elseif isMoveTarget then
                    love.graphics.setColor(Config.COLORS.MOVE_INDICATOR)
                    love.graphics.circle("fill", cellX + CELL_SIZE/2, cellY + CELL_SIZE/2, 5)
                else
                    love.graphics.setColor(Config.COLORS.GRID_COORD)
                    love.graphics.print(string.format("%d,%d", x, y), cellX + 5, cellY + 5)
                end
            end
        end
    end
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
    local adjustedX = x - animState.screenShake.offsetX
    local adjustedY = y - animState.screenShake.offsetY

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
    animState.currentEnemyIndex = 1
    animState.enemyActionDelay = Config.TIMING.ENEMY_ACTION_DELAY
    print("Player turn end, enemy turn start")
end

-- 更新敌人回合
function updateEnemyTurn(dt)
    if animState.enemyActionDelay > 0 then
        animState.enemyActionDelay = animState.enemyActionDelay - dt
        return
    end

    if animState.currentEnemyIndex > #gameState.enemies then
        startPlayerTurn()
        return
    end

    local enemy = gameState.enemies[animState.currentEnemyIndex]
    if enemy and enemy.hp > 0 then
        performEnemyAction(enemy)
    end

    animState.currentEnemyIndex = animState.currentEnemyIndex + 1
    animState.enemyActionDelay = Config.TIMING.ENEMY_ACTION_DELAY
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
    animState.damageTexts = {}
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

    table.insert(animState.damageTexts, {
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
    for i = #animState.damageTexts, 1, -1 do
        local dmg = animState.damageTexts[i]
        dmg.timer = dmg.timer + dt
        dmg.y = dmg.y - Config.TIMING.DAMAGE_TEXT_SPEED * dt
        dmg.alpha = 1 - (dmg.timer / dmg.duration)

        if dmg.timer >= dmg.duration then
            table.remove(animState.damageTexts, i)
        end
    end
end

-- 绘制伤害文本
function drawDamageTexts()
    for _, dmg in ipairs(animState.damageTexts) do
        love.graphics.setColor(dmg.color[1], dmg.color[2], dmg.color[3], dmg.alpha)
        local font = love.graphics.getFont()
        local textW = font:getWidth(dmg.text)
        local textH = font:getHeight()

        -- 对伤害数字应用缩放效果
        if dmg.useScale then
            local scale = 1 + dmg.alpha * (Config.EFFECTS.DAMAGE_SCALE_START - 1)
            local scaledW = textW * scale
            local scaledH = textH * scale
            love.graphics.push()
            love.graphics.translate(dmg.x, dmg.y)
            love.graphics.scale(scale, scale)
            love.graphics.print(dmg.text, -textW / 2, -textH / 2)
            love.graphics.pop()
        else
            love.graphics.print(dmg.text, dmg.x - textW / 2, dmg.y)
        end
    end
end

-- 绘制卡牌详情面板
function drawCardDetailPanel()
    -- 移动/攻击模式下不显示面板以避免阻挡点击
    if uiState.isMoving then return end

    -- 仅当悬停在卡牌上时显示面板
    local card = uiState.hoveredCard
    if not card then return end

    local panelX, panelY = 10, 100
    local panelW, panelH = 180, 220

    -- 如果敌人有技能则增加面板高度
    if card.skills and #card.skills > 0 then
        panelH = panelH + #card.skills * 18
    end

    local borderColor = card.type == Card.TYPE.PLAYER and Config.COLORS.PLAYER_BORDER or Config.COLORS.ENEMY_BORDER
    UI.drawPanel(panelX, panelY, panelW, panelH, {0.15, 0.15, 0.2, 0.95}, borderColor)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(card.name, panelX + 10, panelY + 10)

    love.graphics.setColor(0.7, 0.7, 0.7)
    local typeText = card.type == Card.TYPE.PLAYER and "[Player]" or "[Enemy]"
    love.graphics.print(typeText, panelX + 10, panelY + 30)

    love.graphics.setColor(0.2, 0.8, 0.2)
    love.graphics.print(string.format("HP: %d / %d", card.hp, card.maxHp), panelX + 10, panelY + 55)

    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.print("Attack:", panelX + 10, panelY + 80)

    local dirNames = {
        { key = "n",  name = "N" },
        { key = "ne", name = "NE" },
        { key = "e",  name = "E" },
        { key = "se", name = "SE" },
        { key = "s",  name = "S" },
        { key = "sw", name = "SW" },
        { key = "w",  name = "W" },
        { key = "nw", name = "NW" },
    }

    love.graphics.setColor(0.9, 0.9, 0.9)
    local line1 = string.format("  %s:%d  %s:%d  %s:%d  %s:%d",
        dirNames[1].name, card.attack[dirNames[1].key],
        dirNames[3].name, card.attack[dirNames[3].key],
        dirNames[5].name, card.attack[dirNames[5].key],
        dirNames[7].name, card.attack[dirNames[7].key])
    local line2 = string.format("  %s:%d  %s:%d  %s:%d  %s:%d",
        dirNames[2].name, card.attack[dirNames[2].key],
        dirNames[4].name, card.attack[dirNames[4].key],
        dirNames[6].name, card.attack[dirNames[6].key],
        dirNames[8].name, card.attack[dirNames[8].key])

    love.graphics.print(line1, panelX + 10, panelY + 100)
    love.graphics.print(line2, panelX + 10, panelY + 120)

    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print(string.format("Pos: (%d, %d)", card.gridX, card.gridY), panelX + 10, panelY + 150)

    -- 显示技能
    love.graphics.setColor(0.8, 0.5, 1)
    love.graphics.print("Skills:", panelX + 10, panelY + 170)

    if card.skills and #card.skills > 0 then
        for i, skill in ipairs(card.skills) do
            local skillY = panelY + 170 + i * 18
            if skill.currentCooldown > 0 then
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print(string.format("  %s (CD:%d)", skill.name, skill.currentCooldown), panelX + 10, skillY)
            else
                love.graphics.setColor(0.9, 0.8, 1)
                love.graphics.print(string.format("  %s (Ready)", skill.name), panelX + 10, skillY)
            end
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("  No Skills", panelX + 10, panelY + 188)
    end
end

-- 绘制回合信息
function drawTurnInfo()
    local infoX, infoY = Config.UI.INFO_PANEL_X, Config.UI.INFO_PANEL_Y

    local levelData = Levels.getLevel(gameState.currentLevel)
    local levelName = levelData and levelData.name or "Unknown"
    love.graphics.setColor(0.8, 0.6, 1)
    love.graphics.print(string.format("Level %d: %s", gameState.currentLevel, levelName), infoX, infoY)

    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.print(string.format("Turn: %d", gameState.turnNumber), infoX, infoY + 25)

    local stateText, stateColor = "", {1, 1, 1}
    if gameState.state == GAME_STATE.PLAYER_TURN then
        stateText, stateColor = "Player Turn", Config.COLORS.PLAYER_TURN
    elseif gameState.state == GAME_STATE.ENEMY_TURN then
        stateText, stateColor = "Enemy Turn", Config.COLORS.ENEMY_TURN
    elseif gameState.state == GAME_STATE.GAME_OVER then
        stateText, stateColor = "Game Over", Config.COLORS.GAME_OVER
    elseif gameState.state == GAME_STATE.VICTORY then
        stateText, stateColor = "Victory!", Config.COLORS.VICTORY
    end

    love.graphics.setColor(stateColor)
    love.graphics.print(stateText, infoX, infoY + 50)

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(string.format("Enemies: %d", #gameState.enemies), infoX, infoY + 75)
end

-- 绘制按钮
function drawButtons()
    local mx, my = love.mouse.getPosition()
    UI.drawButtons(buttons, mx, my)
end

-- 绘制关卡选择
function drawLevelSelect()
    local levelData = Levels.getLevel(gameState.currentLevel)
    if not levelData or #levelData.branches == 0 then return end

    UI.drawOverlay(0.7)

    love.graphics.setColor(1, 0.8, 0.2)
    UI.drawCenteredText("Select Next Level", 0, 150, 800)

    local startY = 220
    local mx, my = love.mouse.getPosition()
    for i, branchIndex in ipairs(levelData.branches) do
        local branchData = Levels.getLevel(branchIndex)
        if branchData then
            local btnX, btnY = 250, startY + (i - 1) * 70
            local btnW, btnH = Config.UI.LEVEL_BTN_WIDTH, Config.UI.LEVEL_BTN_HEIGHT
            local hovered = Utils.isPointInRect(mx, my, btnX, btnY, btnW, btnH)

            local btn = { x = btnX, y = btnY, w = btnW, h = btnH, text = string.format("Level %d: %s", branchIndex, branchData.name) }
            UI.drawButton(btn, hovered, false, {
                bg = {0.25, 0.2, 0.35},
                hover = {0.4, 0.3, 0.5},
                border = {0.6, 0.4, 0.8}
            })
        end
    end
end

-- 绘制奖励选择界面
function drawRewardSelect()
    UI.drawOverlay(0.8)

    love.graphics.setColor(1, 0.9, 0.3)
    UI.drawCenteredText("Level Complete! Choose Reward", 0, 100, 800)

    local startY = 200
    local mx, my = love.mouse.getPosition()

    for i, reward in ipairs(uiState.rewardOptions) do
        local btnX, btnY = 200, startY + (i - 1) * 80
        local btnW, btnH = 400, 60
        local hovered = Utils.isPointInRect(mx, my, btnX, btnY, btnW, btnH)

        -- 绘制按钮背景
        love.graphics.setColor(hovered and 0.3 or 0.2, hovered and 0.35 or 0.25, hovered and 0.4 or 0.3)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5, 5)

        -- 绘制边框
        love.graphics.setColor(0.6, 0.5, 0.8)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 5, 5)

        -- 绘制文本
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(reward.name, btnX + 20, btnY + 10)

        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.print(string.format("%s +%d", string.upper(reward.dir), reward.bonus), btnX + 20, btnY + 35)
    end
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

-- 绘制进度信息
function drawProgressionInfo()
    local data = Progression.getData()
    local infoX, infoY = 620, 310

    UI.drawPanel(infoX - 5, infoY - 5, 170, 100, {0.15, 0.12, 0.2, 0.9})

    love.graphics.setColor(0.8, 0.5, 1)
    love.graphics.print("- Progress -", infoX, infoY)

    love.graphics.setColor(1, 0.9, 0.5)
    love.graphics.print(string.format("Level: %d", data.level), infoX, infoY + 20)

    local expNeeded = Progression.getExpToNextLevel()
    love.graphics.setColor(0.7, 0.7, 0.7)
    if expNeeded then
        love.graphics.print(string.format("EXP: %d/%d", data.exp, expNeeded), infoX, infoY + 40)
    else
        love.graphics.print("MAX", infoX + 50, infoY + 40)
    end

    love.graphics.setColor(0.8, 0.5, 1)
    love.graphics.print(string.format("Soul: %d", data.soulFragments), infoX, infoY + 60)
end

-- 绘制技能栏
function drawSkillBar()
    local skills = Skills.getPlayerSkills()
    local barX, barY = Config.UI.SKILL_BAR_X, Config.UI.SKILL_BAR_Y
    local slotW, slotH = Config.UI.SKILL_SLOT_WIDTH, Config.UI.SKILL_SLOT_HEIGHT

    UI.drawPanel(barX - 5, barY - 5, slotW * 4 + 25, slotH + 10, {0.1, 0.1, 0.15, 0.9}, nil, 3)

    for i = 1, 4 do
        local skill = skills[i]
        local slotX = barX + (i - 1) * (slotW + 5)

        -- 槽位背景
        if skill then
            if uiState.selectedSkillIndex == i then
                love.graphics.setColor(0.4, 0.3, 0.5)
            elseif skill.currentCooldown > 0 then
                love.graphics.setColor(0.2, 0.2, 0.2)
            else
                love.graphics.setColor(0.25, 0.2, 0.35)
            end
        else
            love.graphics.setColor(0.15, 0.15, 0.15)
        end
        love.graphics.rectangle("fill", slotX, barY, slotW, slotH, 3, 3)

        -- 边框
        if uiState.selectedSkillIndex == i then
            love.graphics.setColor(0.8, 0.6, 1)
        else
            love.graphics.setColor(0.4, 0.4, 0.5)
        end
        love.graphics.rectangle("line", slotX, barY, slotW, slotH, 3, 3)

        -- 按键数字
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print(tostring(i), slotX + 3, barY + 2)

        if skill then
            if skill.currentCooldown > 0 then
                love.graphics.setColor(0.5, 0.5, 0.5)
            else
                love.graphics.setColor(1, 1, 1)
            end
            local font = love.graphics.getFont()
            local nameW = font:getWidth(skill.name)
            love.graphics.print(skill.name, slotX + (slotW - nameW) / 2, barY + 8)

            if skill.currentCooldown > 0 then
                love.graphics.setColor(1, 0.5, 0.5)
                love.graphics.print(tostring(skill.currentCooldown), slotX + slotW - 12, barY + 2)
            end
        else
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.print("-", slotX + slotW / 2 - 3, barY + 8)
        end
    end
end

-- 绘制升级菜单
function drawUpgradeMenu()
    UI.drawOverlay(0.8)

    local data = Progression.getData()

    love.graphics.setColor(0.8, 0.5, 1)
    UI.drawCenteredText("Upgrade Menu", 0, 50, 800)

    love.graphics.setColor(1, 0.9, 0.5)
    love.graphics.print(string.format("Soul Fragments: %d", data.soulFragments), 320, 80)

    local upgrades = Progression.getAvailableUpgrades()
    local startY = 120
    local mx, my = love.mouse.getPosition()

    for i, info in ipairs(upgrades) do
        local upgrade = info.upgrade
        local btnX, btnY = 200, startY + (i - 1) * 55
        local btnW, btnH = Config.UI.UPGRADE_BTN_WIDTH, Config.UI.UPGRADE_BTN_HEIGHT

        local hovered = Utils.isPointInRect(mx, my, btnX, btnY, btnW, btnH)

        -- 背景
        if info.owned then
            love.graphics.setColor(0.2, 0.3, 0.2)
        elseif info.canBuy then
            love.graphics.setColor(hovered and 0.3 or 0.2, hovered and 0.25 or 0.18, hovered and 0.4 or 0.3)
        else
            love.graphics.setColor(0.15, 0.15, 0.15)
        end
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5, 5)

        -- 边框
        if info.owned then
            love.graphics.setColor(0.3, 0.6, 0.3)
        elseif info.canBuy then
            love.graphics.setColor(0.5, 0.4, 0.7)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 5, 5)

        -- 名称
        if info.owned then
            love.graphics.setColor(0.5, 0.8, 0.5)
        elseif info.canBuy then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
        end
        love.graphics.print(upgrade.name, btnX + 10, btnY + 5)

        -- 描述
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(upgrade.description, btnX + 10, btnY + 22)

        -- 价格或状态
        if info.owned then
            love.graphics.setColor(0.5, 0.8, 0.5)
            love.graphics.print("[Owned]", btnX + btnW - 70, btnY + 12)
        else
            love.graphics.setColor(0.8, 0.5, 1)
            love.graphics.print(string.format("%d", upgrade.cost), btnX + btnW - 50, btnY + 12)
        end
    end

    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Press U or ESC to close", 310, 550)
end

-- 绘制游戏 end screen
function drawGameEndScreen()
    UI.drawOverlay(0.85)

    local font = love.graphics.getFont()

    local text, color
    if gameState.state == GAME_STATE.VICTORY then
        text, color = "Victory!", Config.COLORS.VICTORY
    else
        text, color = "Defeat", Config.COLORS.GAME_OVER
    end

    love.graphics.setColor(color)
    UI.drawCenteredText(text, 0, 80, 800)

    if gameState.runResult then
        local result = gameState.runResult
        local stats = Roguelike.getStats()
        local startY = 130

        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print("- This Run -", 350, startY)

        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(string.format("Level Reached: %d", result.levelReached), 300, startY + 30)
        love.graphics.print(string.format("Enemies Killed: %d", result.enemiesKilled), 300, startY + 50)
        love.graphics.print(string.format("Damage Dealt: %d", result.damageDealt), 300, startY + 70)
        love.graphics.print(string.format("Damage Taken: %d", result.damageTaken), 300, startY + 90)

        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.print(string.format("Score: %d", result.score), 340, startY + 120)

        love.graphics.setColor(0.8, 0.5, 1)
        love.graphics.print("- History -", 355, startY + 160)

        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(string.format("Total Runs: %d", stats.runNumber), 300, startY + 190)
        love.graphics.print(string.format("Highest Level: %d", stats.highestLevel), 300, startY + 210)
        love.graphics.print(string.format("Best Score: %d", stats.bestScore), 300, startY + 230)
        love.graphics.print(string.format("Difficulty: x%.1f", stats.difficultyMultiplier), 300, startY + 250)
    end

    love.graphics.setColor(0.8, 0.8, 0.8)
    UI.drawCenteredText("R=New Run | N=New Game+ (reset progress)", 0, 450, 800)

    local skills = Skills.getPlayerSkills()
    if #skills > 0 and gameState.state == GAME_STATE.GAME_OVER then
        love.graphics.setColor(0.5, 0.8, 1)
        love.graphics.print("Your first skill will be inherited to next run", 245, 480)
    end
end
