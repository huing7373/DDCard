-- Demon Lord - Main Entry Point
-- Love2D Game Framework

-- Load modules
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

-- Local references for frequently used config values
local GRID_SIZE = Config.GRID.SIZE
local CELL_SIZE = Config.GRID.CELL_SIZE
local GRID_OFFSET_X = Config.GRID.OFFSET_X
local GRID_OFFSET_Y = Config.GRID.OFFSET_Y
local DIRECTIONS = Config.DIRECTIONS
local GAME_STATE = Config.GAME_STATE

-- Core game state
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

-- UI state
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
}

-- Animation state
local animState = {
    damageTexts = {},
    enemyActionDelay = 0,
    currentEnemyIndex = 0,
}

-- UI Buttons
local buttons = {}

-- Forward declarations for local functions
local placeCard, removeCard, moveCard
local enterMoveMode, endPlayerTurn, startPlayerTurn
local performAttack, grantKillReward
local createDamageText, checkGameEnd
local loadLevel, restartGame

-- Initialize game
function love.load()
    love.graphics.setNewFont(14)

    -- Initialize grid
    gameState.grid = Grid.new(GRID_SIZE)

    -- Create player card
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

    -- Load first level
    loadLevel(1)

    -- Initialize skill system
    Skills.init()

    -- Create UI buttons
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

    print("Demon Lord - Game initialized")
end

-- Place card on grid
placeCard = function(card)
    Grid.placeCard(gameState.grid, card, card.gridX, card.gridY)
    table.insert(gameState.cards, card)
    if card.type == Card.TYPE.ENEMY then
        table.insert(gameState.enemies, card)
    end
end

-- Remove card from grid
removeCard = function(card)
    Grid.removeCard(gameState.grid, card)
    Utils.removeFromList(gameState.cards, card)
    if card.type == Card.TYPE.ENEMY then
        Utils.removeFromList(gameState.enemies, card)
    end
    print(string.format("%s defeated!", card.name))
end

-- Move card to new position
moveCard = function(card, newX, newY)
    Grid.moveCard(gameState.grid, card, newX, newY)
end

-- Load level
loadLevel = function(levelIndex)
    gameState.currentLevel = levelIndex
    local levelData = Levels.getLevel(levelIndex)

    if not levelData then
        print("No more levels!")
        gameState.state = GAME_STATE.VICTORY
        return
    end

    -- Clear old enemies
    for _, enemy in ipairs(gameState.enemies) do
        Grid.removeCard(gameState.grid, enemy)
    end
    gameState.enemies = {}

    -- Remove enemies from card list
    for i = #gameState.cards, 1, -1 do
        if gameState.cards[i].type == Card.TYPE.ENEMY then
            table.remove(gameState.cards, i)
        end
    end

    -- Create new enemies with difficulty scaling
    for _, enemyData in ipairs(levelData.enemies) do
        local enemyParams = Levels.createEnemyFromTemplate(enemyData.template, enemyData.x, enemyData.y)
        if enemyParams then
            enemyParams.type = Card.TYPE.ENEMY
            local enemy = Card.new(enemyParams)
            Roguelike.applyDifficultyToEnemy(enemy)
            placeCard(enemy)
        end
    end

    -- Reset turn state
    gameState.turnNumber = 1
    gameState.state = GAME_STATE.PLAYER_TURN
    uiState.showLevelSelect = false

    print(string.format("Enter Level %d: %s", levelIndex, levelData.name))
end

-- Update game logic
function love.update(dt)
    local mx, my = love.mouse.getPosition()
    uiState.hoveredCard = getCardAtScreen(mx, my)

    updateDamageTexts(dt)

    if gameState.state == GAME_STATE.ENEMY_TURN then
        updateEnemyTurn(dt)
    end

    checkGameEnd()
end

-- Draw game
function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    -- Title
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.print("Demon Lord", 10, 10)

    drawGrid()
    drawCardDetailPanel()
    drawDamageTexts()
    drawTurnInfo()
    drawButtons()
    drawSkillBar()

    if gameState.state == GAME_STATE.GAME_OVER or gameState.state == GAME_STATE.VICTORY then
        drawGameEndScreen()
    end

    if uiState.showLevelSelect then
        drawLevelSelect()
    end

    if uiState.showUpgradeMenu then
        drawUpgradeMenu()
    end

    drawProgressionInfo()

    -- Help text
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

-- Draw grid
function drawGrid()
    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            local cellX = GRID_OFFSET_X + (x - 1) * CELL_SIZE
            local cellY = GRID_OFFSET_Y + (y - 1) * CELL_SIZE

            -- Checkerboard pattern
            if (x + y) % 2 == 0 then
                love.graphics.setColor(Config.COLORS.GRID_EVEN)
            else
                love.graphics.setColor(Config.COLORS.GRID_ODD)
            end
            love.graphics.rectangle("fill", cellX, cellY, CELL_SIZE, CELL_SIZE)

            -- Check targeting
            local isMoveTarget = Utils.isInTargetList(x, y, uiState.moveTargets)
            local isAttackTarget = Utils.isInTargetList(x, y, uiState.attackTargets)

            -- Highlight targets
            if isMoveTarget then
                love.graphics.setColor(Config.COLORS.MOVE_TARGET)
                love.graphics.rectangle("fill", cellX, cellY, CELL_SIZE, CELL_SIZE)
            end
            if isAttackTarget then
                love.graphics.setColor(Config.COLORS.ATTACK_TARGET)
                love.graphics.rectangle("fill", cellX, cellY, CELL_SIZE, CELL_SIZE)
            end

            -- Border
            if isAttackTarget then
                love.graphics.setColor(Config.COLORS.ATTACK_BORDER)
            elseif isMoveTarget then
                love.graphics.setColor(Config.COLORS.MOVE_BORDER)
            else
                love.graphics.setColor(Config.COLORS.GRID_BORDER)
            end
            love.graphics.rectangle("line", cellX, cellY, CELL_SIZE, CELL_SIZE)

            -- Draw card or coordinates
            local cell = gameState.grid[y][x]
            if cell.card then
                cell.card:draw(cellX, cellY, CELL_SIZE)
            else
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print(string.format("%d,%d", x, y), cellX + 5, cellY + 5)
            end
        end
    end
end

-- Keyboard input
function love.keypressed(key)
    -- Game over input
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

-- Use selected skill
function useSelectedSkill(direction)
    if not uiState.selectedSkillIndex then return end

    local gameContext = {
        player = gameState.player,
        grid = gameState.grid,
        DIRECTIONS = DIRECTIONS,
        moveCard = moveCard,
        removeCard = removeCard,
        createDamageText = function(target, damage)
            local screenX, screenY = Utils.getGridCellCenter(target.gridX, target.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
            createDamageText(screenX, screenY, damage, Config.COLORS.DAMAGE)
        end,
        createHealText = function(target, heal)
            local screenX, screenY = Utils.getGridCellCenter(target.gridX, target.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
            createDamageText(screenX, screenY - 20, "+" .. heal, Config.COLORS.HEAL)
        end,
        createShieldText = function(target, amount)
            local screenX, screenY = Utils.getGridCellCenter(target.gridX, target.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
            createDamageText(screenX, screenY - 20, "+" .. amount .. " Shield", Config.COLORS.SHIELD)
        end
    }

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

-- Mouse click
function love.mousepressed(x, y, button)
    if gameState.state == GAME_STATE.GAME_OVER or gameState.state == GAME_STATE.VICTORY then
        return
    end

    -- Level select
    if uiState.showLevelSelect and button == 1 then
        handleLevelSelectClick(x, y)
        return
    end

    -- Upgrade menu
    if uiState.showUpgradeMenu and button == 1 then
        handleUpgradeMenuClick(x, y)
        return
    end

    -- UI buttons
    if button == 1 and UI.handleButtonClick(buttons, x, y) then
        return
    end

    if gameState.state ~= GAME_STATE.PLAYER_TURN then
        return
    end

    if button == 1 then
        local clickedCard = getCardAtScreen(x, y)
        local gridPos = getGridAtScreen(x, y)

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
    end
end

-- Handle level select click
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

-- Handle upgrade menu click
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

-- Get card at screen position
function getCardAtScreen(screenX, screenY)
    local gridPos = getGridAtScreen(screenX, screenY)
    if gridPos then
        return Grid.getCard(gameState.grid, gridPos.x, gridPos.y)
    end
    return nil
end

-- Get grid position from screen coordinates
function getGridAtScreen(screenX, screenY)
    local gridX, gridY = Utils.screenToGrid(screenX, screenY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE, GRID_SIZE)
    if gridX then
        return { x = gridX, y = gridY }
    end
    return nil
end

-- Enter move/attack mode
enterMoveMode = function(card)
    uiState.isMoving = true
    uiState.selectedCard = card
    uiState.moveTargets, uiState.attackTargets = Grid.findTargets(gameState.grid, card, DIRECTIONS, GRID_SIZE)
end

-- Try to move card
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

-- Try attack at direction
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

-- Try attack at position
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

-- Perform attack
performAttack = function(attacker, defender, direction)
    local attackerDamage, defenderDamage = Combat.calculateDamage(attacker, defender, direction, DIRECTIONS)
    local defenderKilled, attackerKilled = Combat.applyDamage(attacker, defender, attackerDamage, defenderDamage)

    -- Create damage text animations
    local attackerScreenX, attackerScreenY = Utils.getGridCellCenter(attacker.gridX, attacker.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
    local defenderScreenX, defenderScreenY = Utils.getGridCellCenter(defender.gridX, defender.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)

    if attackerDamage > 0 then
        createDamageText(defenderScreenX, defenderScreenY, attackerDamage, Config.COLORS.DAMAGE)
    end
    if defenderDamage > 0 then
        createDamageText(attackerScreenX, attackerScreenY, defenderDamage, Config.COLORS.COUNTER_DAMAGE)
    end

    -- Handle deaths and rewards
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

-- Grant kill reward
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
        Progression.addExp(victim.maxHp)

        createDamageText(killerScreenX + 30, killerScreenY - 30, "+" .. soulReward .. " Soul", Config.COLORS.SOUL)

        Roguelike.recordKill()

        local absorbedSkill = Skills.absorbSkill(victim.name)
        if absorbedSkill then
            print("Absorbed new skill!")
        end

        print(string.format("Kill reward: +%d HP, %s atk+%d, soul+%d",
            hpRecover, randomDir, atkBonus, soulReward))
    end
end

-- End player turn
endPlayerTurn = function()
    uiState.isMoving = false
    uiState.moveTargets = {}
    uiState.attackTargets = {}
    gameState.state = GAME_STATE.ENEMY_TURN
    animState.currentEnemyIndex = 1
    animState.enemyActionDelay = Config.TIMING.ENEMY_ACTION_DELAY
    print("Player turn end, enemy turn start")
end

-- Update enemy turn
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

-- Perform enemy action
function performEnemyAction(enemy)
    local gameContext = {
        grid = gameState.grid,
        gridSize = GRID_SIZE,
        player = gameState.player
    }

    local decision = AI.decideAction(enemy, gameContext, Card)

    if decision.type == "attack" then
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

-- Start player turn
startPlayerTurn = function()
    gameState.state = GAME_STATE.PLAYER_TURN
    gameState.turnNumber = gameState.turnNumber + 1
    Skills.tickCooldowns()
    print(string.format("Turn %d - Player turn start", gameState.turnNumber))
end

-- Check game end
checkGameEnd = function()
    if gameState.state == GAME_STATE.GAME_OVER or gameState.state == GAME_STATE.VICTORY or uiState.showLevelSelect or uiState.showSettlement then
        return
    end

    if gameState.player == nil or gameState.player.hp <= 0 then
        gameState.state = GAME_STATE.GAME_OVER
        gameState.runResult = Roguelike.endRun(false, gameState.currentLevel)
        uiState.showSettlement = true
        print("Game Over - Player defeated")
    elseif #gameState.enemies == 0 then
        local levelData = Levels.getLevel(gameState.currentLevel)
        if levelData and #levelData.branches > 0 then
            uiState.showLevelSelect = true
            print("Level complete! Select next level...")
        elseif gameState.currentLevel >= Levels.getLevelCount() then
            gameState.state = GAME_STATE.VICTORY
            gameState.runResult = Roguelike.endRun(true, gameState.currentLevel)
            uiState.showSettlement = true
            print("Victory! Game cleared!")
        else
            loadLevel(gameState.currentLevel + 1)
        end
    end
end

-- Restart game
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

-- Start new run
function startNewRun()
    local skills = Skills.getPlayerSkills()
    if #skills > 0 then
        Roguelike.setInheritedSkill(skills[1].id)
    end

    Roguelike.startNewRun()
    restartGame()
    print("New run started!")
end

-- Hard reset
function hardReset()
    Roguelike.hardReset()
    Progression.reset()
    restartGame()
    print("New Game+ started!")
end

-- Create damage text animation
createDamageText = function(x, y, damage, color)
    local text
    if type(damage) == "string" then
        text = damage
    else
        text = "-" .. damage
    end

    table.insert(animState.damageTexts, {
        x = x,
        y = y,
        text = text,
        color = color,
        alpha = 1,
        timer = 0,
        duration = Config.TIMING.DAMAGE_TEXT_DURATION
    })
end

-- Update damage texts
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

-- Draw damage texts
function drawDamageTexts()
    for _, dmg in ipairs(animState.damageTexts) do
        love.graphics.setColor(dmg.color[1], dmg.color[2], dmg.color[3], dmg.alpha)
        local font = love.graphics.getFont()
        local textW = font:getWidth(dmg.text)
        love.graphics.print(dmg.text, dmg.x - textW / 2, dmg.y)
    end
end

-- Draw card detail panel
function drawCardDetailPanel()
    local card = uiState.hoveredCard or uiState.selectedCard
    if not card then return end

    local panelX, panelY = 10, 100
    local panelW, panelH = 180, 200

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
end

-- Draw turn info
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

-- Draw buttons
function drawButtons()
    local mx, my = love.mouse.getPosition()
    UI.drawButtons(buttons, mx, my)
end

-- Draw level select
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

-- Draw progression info
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

-- Draw skill bar
function drawSkillBar()
    local skills = Skills.getPlayerSkills()
    local barX, barY = Config.UI.SKILL_BAR_X, Config.UI.SKILL_BAR_Y
    local slotW, slotH = Config.UI.SKILL_SLOT_WIDTH, Config.UI.SKILL_SLOT_HEIGHT

    UI.drawPanel(barX - 5, barY - 5, slotW * 4 + 25, slotH + 10, {0.1, 0.1, 0.15, 0.9}, nil, 3)

    for i = 1, 4 do
        local skill = skills[i]
        local slotX = barX + (i - 1) * (slotW + 5)

        -- Slot background
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

        -- Border
        if uiState.selectedSkillIndex == i then
            love.graphics.setColor(0.8, 0.6, 1)
        else
            love.graphics.setColor(0.4, 0.4, 0.5)
        end
        love.graphics.rectangle("line", slotX, barY, slotW, slotH, 3, 3)

        -- Key number
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

-- Draw upgrade menu
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

        -- Background
        if info.owned then
            love.graphics.setColor(0.2, 0.3, 0.2)
        elseif info.canBuy then
            love.graphics.setColor(hovered and 0.3 or 0.2, hovered and 0.25 or 0.18, hovered and 0.4 or 0.3)
        else
            love.graphics.setColor(0.15, 0.15, 0.15)
        end
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5, 5)

        -- Border
        if info.owned then
            love.graphics.setColor(0.3, 0.6, 0.3)
        elseif info.canBuy then
            love.graphics.setColor(0.5, 0.4, 0.7)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 5, 5)

        -- Name
        if info.owned then
            love.graphics.setColor(0.5, 0.8, 0.5)
        elseif info.canBuy then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
        end
        love.graphics.print(upgrade.name, btnX + 10, btnY + 5)

        -- Description
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(upgrade.description, btnX + 10, btnY + 22)

        -- Price or status
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

-- Draw game end screen
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
