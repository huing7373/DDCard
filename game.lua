-- game.lua
-- Game 单例类
-- 管理游戏生命周期、状态和所有游戏逻辑

local Object = require("engine.object")
local EventModule = require("engine.event")
local CardArea = require("entities.card_area")

local Game = Object:extend()
Game.__type = "Game"

-- 单例实例
local instance = nil

function Game:init()
    if instance then
        error("Game is a singleton, use Game.getInstance()")
    end

    self.initialized = false
    self.frame = 0

    -- 事件管理器
    self.event_manager = EventModule.EventManager()

    -- 字体缓存
    self.FONT = {}

    -- 卡牌区域管理
    self.card_areas = {}

    -- ========================================
    -- 核心游戏状态 (从 main.lua 迁移)
    -- ========================================
    self.gameState = {
        grid = {},
        cards = {},
        enemies = {},
        player = nil,
        state = nil,  -- 将在 start_up 中设置
        turnNumber = 1,
        currentLevel = 1,
        lastReward = nil,
        runResult = nil,
    }

    -- UI 状态
    self.uiState = {
        hoveredCard = nil,
        selectedCard = nil,
        moveTargets = {},
        attackTargets = {},
        isMoving = false,
        showLevelSelect = false,
        showUpgradeMenu = false,
        showSettlement = false,
        selectedSkillIndex = nil,
        showRewardSelect = false,
        rewardOptions = {},
    }

    -- 敌人回合状态
    self.turnState = {
        enemyActionDelay = 0,
        currentEnemyIndex = 0,
    }

    -- UI 按钮
    self.buttons = {}

    -- 模块引用 (延迟加载，避免循环依赖)
    self.modules = {}
end

-- 获取单例实例
function Game.getInstance()
    if not instance then
        instance = Game()
    end
    return instance
end

-- 加载模块引用
function Game:load_modules()
    self.modules.Config = require("config")
    self.modules.Utils = require("utils")
    self.modules.UI = require("ui")
    self.modules.Combat = require("combat")
    self.modules.Grid = require("grid")
    self.modules.Card = require("card")
    self.modules.AI = require("ai")
    self.modules.Levels = require("levels")
    self.modules.Progression = require("progression")
    self.modules.Skills = require("skills")
    self.modules.Roguelike = require("roguelike")
    self.modules.Draw = require("functions.draw")
    self.modules.Battle = require("functions.battle")
    self.modules.Turns = require("functions.turns")
    self.modules.GameFlow = require("functions.game_flow")
    self.modules.Animation = require("systems.animation")
    self.modules.StateMachine = require("systems.state_machine")

    -- 获取动画单例
    self.Anim = self.modules.Animation.getInstance()

    -- 常用配置引用
    self.GRID_SIZE = self.modules.Config.GRID.SIZE
    self.CELL_SIZE = self.modules.Config.GRID.CELL_SIZE
    self.GRID_OFFSET_X = self.modules.Config.GRID.OFFSET_X
    self.GRID_OFFSET_Y = self.modules.Config.GRID.OFFSET_Y
    self.DIRECTIONS = self.modules.Config.DIRECTIONS
    self.GAME_STATE = self.modules.Config.GAME_STATE
end

-- 设置全局配置
function Game:set_globals()
    require("globals")

    if not G then G = {} end

    G.GAME = self
    G.E = self.event_manager

    print("[Game] Globals initialized")
end

-- 加载字体
function Game:load_fonts()
    local font_path = "resources/fonts/msyh.ttc"
    local info = love.filesystem.getInfo(font_path)

    if info then
        self.FONT.SMALL = love.graphics.newFont(font_path, 12)
        self.FONT.NORMAL = love.graphics.newFont(font_path, 14)
        self.FONT.LARGE = love.graphics.newFont(font_path, 18)
        self.FONT.TITLE = love.graphics.newFont(font_path, 24)
        print("[Game] Fonts loaded")
    else
        self.FONT.SMALL = love.graphics.newFont(12)
        self.FONT.NORMAL = love.graphics.newFont(14)
        self.FONT.LARGE = love.graphics.newFont(18)
        self.FONT.TITLE = love.graphics.newFont(24)
        print("[Game] Using default fonts")
    end

    G.FONT = self.FONT
    love.graphics.setFont(self.FONT.NORMAL)
end

-- 游戏启动
function Game:start_up()
    print("[Game] Starting up...")

    self:set_globals()
    self:load_modules()
    self:load_fonts()

    -- 设置初始游戏状态
    self.gameState.state = self.GAME_STATE.PLAYER_TURN

    -- 初始化网格
    self.gameState.grid = self.modules.Grid.new(self.GRID_SIZE)

    -- 创建玩家
    local Config = self.modules.Config
    local Utils = self.modules.Utils
    local Card = self.modules.Card

    self.gameState.player = Card.new({
        name = "Demon Lord",
        type = Card.TYPE.PLAYER,
        hp = Config.PLAYER.DEFAULT_HP,
        maxHp = Config.PLAYER.DEFAULT_HP,
        attack = Utils.deepCopy(Config.PLAYER.DEFAULT_ATTACK),
        gridX = Config.PLAYER.DEFAULT_GRID_X,
        gridY = Config.PLAYER.DEFAULT_GRID_Y
    })
    self:placeCard(self.gameState.player)

    -- 加载第一关
    self:loadLevel(1)

    -- 初始化技能系统
    self.modules.Skills.init()

    -- 初始化状态机
    G.STATE_MACHINE = self.modules.StateMachine({
        initial_state = G.STATES.PLAYER_TURN,
        on_state_change = function(old_state, new_state)
            self.gameState.state = G.STATE_NAMES[new_state] and
                self.GAME_STATE[G.STATE_NAMES[new_state]] or new_state
        end
    })

    G.STATE_MACHINE:define_state(G.STATES.PLAYER_TURN, {})
    G.STATE_MACHINE:define_state(G.STATES.ENEMY_TURN, {})
    G.STATE_MACHINE:define_state(G.STATES.GAME_OVER, {})
    G.STATE_MACHINE:define_state(G.STATES.VICTORY, {})

    -- 创建 UI 按钮
    local UI = self.modules.UI
    self.buttons = {
        UI.createButton(620, 200, 100, 30, "End Turn", function()
            if self.gameState.state == self.GAME_STATE.PLAYER_TURN then
                self:endPlayerTurn()
            end
        end),
        UI.createButton(620, 240, 100, 30, "Restart", function()
            self:restartGame()
        end)
    }

    self.initialized = true
    print("[Game] Startup complete")
end

-- ========================================
-- 卡牌操作
-- ========================================

function Game:placeCard(card)
    self.modules.Grid.placeCard(self.gameState.grid, card, card.gridX, card.gridY)
    table.insert(self.gameState.cards, card)
    if card.type == self.modules.Card.TYPE.ENEMY then
        table.insert(self.gameState.enemies, card)
    end
end

function Game:removeCard(card)
    self.modules.Grid.removeCard(self.gameState.grid, card)
    self.modules.Utils.removeFromList(self.gameState.cards, card)
    if card.type == self.modules.Card.TYPE.ENEMY then
        self.modules.Utils.removeFromList(self.gameState.enemies, card)
    end
    if self.uiState.selectedCard == card then
        self.uiState.selectedCard = nil
    end
    if self.uiState.hoveredCard == card then
        self.uiState.hoveredCard = nil
    end
    print(string.format("%s defeated!", card.name))
end

function Game:moveCard(card, newX, newY)
    self.modules.Grid.moveCard(self.gameState.grid, card, newX, newY)
end

-- ========================================
-- 关卡管理
-- ========================================

function Game:loadLevel(levelIndex)
    self.modules.GameFlow.loadLevel({
        levelIndex = levelIndex,
        gameState = self.gameState,
        uiState = self.uiState,
        placeCard = function(card) self:placeCard(card) end,
        Card = self.modules.Card,
    })
end

-- ========================================
-- 动画和特效
-- ========================================

function Game:triggerScreenShake(intensity, duration)
    local Config = self.modules.Config
    self.Anim:shake(
        intensity or Config.EFFECTS.SHAKE_INTENSITY,
        duration or Config.EFFECTS.SHAKE_DURATION
    )
end

function Game:createSkillEffect(effectType, params)
    local Config = self.modules.Config
    self.Anim:add_skill_effect({
        type = effectType,
        center_x = params.centerX,
        center_y = params.centerY,
        duration = params.duration or Config.EFFECTS.SKILL_EFFECT_DURATION,
        data = params,
    })
end

function Game:createDamageText(x, y, damage, color, useScale)
    local Config = self.modules.Config
    local text = type(damage) == "string" and damage or "-" .. damage
    local shouldScale = useScale
    if shouldScale == nil then
        shouldScale = type(damage) == "number"
    end

    table.insert(self.Anim.damage_texts, {
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

-- ========================================
-- 技能上下文
-- ========================================

function Game:createSkillContext()
    local Config = self.modules.Config
    local Utils = self.modules.Utils
    local self_ref = self

    return {
        player = self.gameState.player,
        grid = self.gameState.grid,
        DIRECTIONS = self.DIRECTIONS,
        moveCard = function(card, x, y) self_ref:moveCard(card, x, y) end,
        removeCard = function(card) self_ref:removeCard(card) end,
        createDamageText = function(target, damage)
            local screenX, screenY = Utils.getGridCellCenter(
                target.gridX, target.gridY,
                self_ref.GRID_OFFSET_X, self_ref.GRID_OFFSET_Y, self_ref.CELL_SIZE
            )
            self_ref:createDamageText(screenX, screenY, damage, Config.COLORS.DAMAGE)
            if target.triggerFlash then
                target:triggerFlash(Config.EFFECTS.FLASH_DURATION)
            end
        end,
        createHealText = function(target, heal)
            local screenX, screenY = Utils.getGridCellCenter(
                target.gridX, target.gridY,
                self_ref.GRID_OFFSET_X, self_ref.GRID_OFFSET_Y, self_ref.CELL_SIZE
            )
            self_ref:createDamageText(screenX, screenY - 20, "+" .. heal, Config.COLORS.HEAL, false)
        end,
        createShieldText = function(target, amount)
            local screenX, screenY = Utils.getGridCellCenter(
                target.gridX, target.gridY,
                self_ref.GRID_OFFSET_X, self_ref.GRID_OFFSET_Y, self_ref.CELL_SIZE
            )
            self_ref:createDamageText(screenX, screenY - 20, "+" .. amount .. " Shield", Config.COLORS.SHIELD, false)
        end,
        triggerScreenShake = function(intensity, duration)
            self_ref:triggerScreenShake(intensity, duration)
        end,
        createSkillEffect = function(effectType, params)
            self_ref:createSkillEffect(effectType, params)
        end,
        getScreenPos = function(gridX, gridY)
            return Utils.getGridCellCenter(
                gridX, gridY,
                self_ref.GRID_OFFSET_X, self_ref.GRID_OFFSET_Y, self_ref.CELL_SIZE
            )
        end,
    }
end

-- ========================================
-- 战斗系统
-- ========================================

function Game:performAttack(attacker, defender, direction)
    local self_ref = self
    self.modules.Battle.performAttack({
        attacker = attacker,
        defender = defender,
        direction = direction,
        createDamageText = function(x, y, dmg, color)
            self_ref:createDamageText(x, y, dmg, color)
        end,
        triggerScreenShake = function(i, d)
            self_ref:triggerScreenShake(i, d)
        end,
        removeCard = function(card) self_ref:removeCard(card) end,
        grantKillReward = function(killer, victim)
            self_ref:grantKillReward(killer, victim)
        end,
    })
end

function Game:grantKillReward(killer, victim)
    local self_ref = self
    self.modules.Battle.grantKillReward({
        killer = killer,
        victim = victim,
        createDamageText = function(x, y, dmg, color)
            self_ref:createDamageText(x, y, dmg, color)
        end,
        gameState = self.gameState,
        Card = self.modules.Card,
    })
end

-- ========================================
-- 回合管理
-- ========================================

function Game:endPlayerTurn()
    self.modules.Turns.endPlayerTurn({
        gameState = self.gameState,
        uiState = self.uiState,
        turnState = self.turnState,
    })
end

function Game:startPlayerTurn()
    self.modules.Turns.startPlayerTurn({
        gameState = self.gameState,
        enemies = self.gameState.enemies,
    })
end

function Game:updateEnemyTurn(dt)
    local self_ref = self
    self.modules.Turns.updateEnemyTurn({
        dt = dt,
        gameState = self.gameState,
        turnState = self.turnState,
        performEnemyAction = function(enemy)
            self_ref:performEnemyAction(enemy)
        end,
        onTurnEnd = function()
            self_ref:startPlayerTurn()
        end,
    })
end

function Game:performEnemyAction(enemy)
    local self_ref = self
    self.modules.Turns.performEnemyAction({
        enemy = enemy,
        gameState = self.gameState,
        createSkillContext = function() return self_ref:createSkillContext() end,
        performAttack = function(a, d, dir) self_ref:performAttack(a, d, dir) end,
        moveCard = function(card, x, y) self_ref:moveCard(card, x, y) end,
        Card = self.modules.Card,
    })
end

-- ========================================
-- 游戏流程
-- ========================================

function Game:checkGameEnd()
    self.modules.GameFlow.checkGameEnd({
        gameState = self.gameState,
        uiState = self.uiState,
    })
end

function Game:restartGame()
    local self_ref = self
    self.modules.GameFlow.restartGame({
        gameState = self.gameState,
        uiState = self.uiState,
        Anim = self.Anim,
        placeCard = function(card) self_ref:placeCard(card) end,
        Card = self.modules.Card,
    })
end

function Game:startNewRun()
    local self_ref = self
    self.modules.GameFlow.startNewRun({
        restartGame = function() self_ref:restartGame() end,
    })
end

function Game:hardReset()
    local self_ref = self
    self.modules.GameFlow.hardReset({
        restartGame = function() self_ref:restartGame() end,
        Progression = self.modules.Progression,
    })
end

function Game:applyRewardAndContinue(reward)
    local self_ref = self
    self.modules.GameFlow.applyRewardAndContinue({
        reward = reward,
        gameState = self.gameState,
        uiState = self.uiState,
        loadLevel = function(idx) self_ref:loadLevel(idx) end,
    })
end

-- ========================================
-- 移动和攻击
-- ========================================

function Game:enterMoveMode(card)
    self.uiState.isMoving = true
    self.uiState.selectedCard = card
    self.uiState.moveTargets, self.uiState.attackTargets = self.modules.Grid.findTargets(
        self.gameState.grid, card, self.DIRECTIONS, self.GRID_SIZE
    )
end

function Game:exitMoveMode()
    self.uiState.isMoving = false
    self.uiState.moveTargets = {}
    self.uiState.attackTargets = {}
    self.uiState.selectedSkillIndex = nil
end

function Game:tryMoveCard(card, targetX, targetY)
    local found = self.modules.Utils.isInTargetList(targetX, targetY, self.uiState.moveTargets)
    if found then
        self:moveCard(card, targetX, targetY)
        self:exitMoveMode()
        if card.type == self.modules.Card.TYPE.PLAYER then
            self:endPlayerTurn()
        end
        return true
    end
    return false
end

function Game:tryAttackAt(attacker, targetX, targetY)
    for _, target in ipairs(self.uiState.attackTargets) do
        if target.x == targetX and target.y == targetY then
            self:performAttack(attacker, target.target, target.direction)
            self:exitMoveMode()
            if attacker.type == self.modules.Card.TYPE.PLAYER then
                self:endPlayerTurn()
            end
            return true
        end
    end
    return false
end

function Game:tryAttackAtDirection(attacker, dirKey)
    for _, target in ipairs(self.uiState.attackTargets) do
        if target.direction == dirKey then
            self:performAttack(attacker, target.target, target.direction)
            self:exitMoveMode()
            if attacker.type == self.modules.Card.TYPE.PLAYER then
                self:endPlayerTurn()
            end
            return true
        end
    end
    return false
end

function Game:useSelectedSkill(direction)
    if not self.uiState.selectedSkillIndex then return end

    print(string.format("[Skill] Using skill %d in direction %s", self.uiState.selectedSkillIndex, direction))

    local gameContext = self:createSkillContext()
    local success, msg = self.modules.Skills.useSkill(
        self.uiState.selectedSkillIndex, direction, gameContext
    )

    print(string.format("[Skill] Result: success=%s, msg=%s", tostring(success), tostring(msg)))

    self.uiState.selectedSkillIndex = nil
    self:exitMoveMode()

    if success then
        self:endPlayerTurn()
    else
        print("Skill failed: " .. (msg or "unknown"))
    end
end

-- ========================================
-- 坐标转换
-- ========================================

function Game:getGridAtScreen(screenX, screenY)
    local gridX, gridY = self.modules.Utils.screenToGrid(
        screenX, screenY,
        self.GRID_OFFSET_X, self.GRID_OFFSET_Y,
        self.CELL_SIZE, self.GRID_SIZE
    )
    if gridX then
        return { x = gridX, y = gridY }
    end
    return nil
end

function Game:getCardAtScreen(screenX, screenY)
    local gridPos = self:getGridAtScreen(screenX, screenY)
    if gridPos then
        return self.modules.Grid.getCard(self.gameState.grid, gridPos.x, gridPos.y)
    end
    return nil
end

-- ========================================
-- 更新循环
-- ========================================

function Game:update(dt)
    if not self.initialized then return end

    -- 更新全局计时器
    G.TIMERS.REAL = G.TIMERS.REAL + dt
    G.TIMERS.TOTAL = G.TIMERS.TOTAL + dt

    -- 更新事件队列
    self.event_manager:update(dt)

    -- 更新 Moveable 实体
    for _, moveable in ipairs(G.I.MOVEABLE) do
        moveable:move(dt)
    end

    -- 更新鼠标悬停
    local mx, my = love.mouse.getPosition()
    local adjustedMx = mx - self.Anim.screen_shake.offsetX
    local adjustedMy = my - self.Anim.screen_shake.offsetY
    self.uiState.hoveredCard = self:getCardAtScreen(adjustedMx, adjustedMy)

    -- 更新伤害文本
    self:updateDamageTexts(dt)

    -- 更新动画
    self.Anim:update_screen_shake(dt)
    self.Anim:update_skill_effects(dt)

    -- 更新卡牌特效
    for _, card in ipairs(self.gameState.cards) do
        if card.update then
            card:update(dt)
        end
    end

    -- 敌人回合
    if self.gameState.state == self.GAME_STATE.ENEMY_TURN then
        self:updateEnemyTurn(dt)
    end

    -- 检查游戏结束
    self:checkGameEnd()

    self.frame = self.frame + 1
end

function Game:updateDamageTexts(dt)
    local Config = self.modules.Config
    for i = #self.Anim.damage_texts, 1, -1 do
        local dmg = self.Anim.damage_texts[i]
        dmg.timer = dmg.timer + dt
        dmg.y = dmg.y - Config.TIMING.DAMAGE_TEXT_SPEED * dt
        dmg.alpha = 1 - (dmg.timer / dmg.duration)

        if dmg.timer >= dmg.duration then
            table.remove(self.Anim.damage_texts, i)
        end
    end
end

-- ========================================
-- 渲染循环
-- ========================================

function Game:draw()
    if not self.initialized then return end

    local Draw = self.modules.Draw

    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    -- 应用屏幕震动
    local shakeX = self.Anim.screen_shake.offsetX
    local shakeY = self.Anim.screen_shake.offsetY
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- 标题
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.print("Demon Lord", 10, 10)

    -- 主要绘制
    Draw.grid(self.gameState, self.uiState)
    Draw.skillEffects(self.Anim.skill_effects)
    Draw.cardDetailPanel(self.uiState, self.modules.Card)
    Draw.damageTexts(self.Anim.damage_texts)
    Draw.turnInfo(self.gameState, self.GAME_STATE)
    Draw.buttons(self.buttons)
    Draw.skillBar(self.uiState)

    love.graphics.pop()

    -- 覆盖层 (不受震动影响)
    if self.gameState.state == self.GAME_STATE.GAME_OVER or
       self.gameState.state == self.GAME_STATE.VICTORY then
        Draw.gameEndScreen(self.gameState, self.GAME_STATE)
    end

    if self.uiState.showLevelSelect then
        Draw.levelSelect(self.gameState)
    end

    if self.uiState.showUpgradeMenu then
        Draw.upgradeMenu()
    end

    if self.uiState.showRewardSelect then
        Draw.rewardSelect(self.uiState.rewardOptions)
    end

    Draw.progressionInfo()

    -- 帮助文本
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Roguelike | U=Upgrade | 1-4=Skills", 10, 550)

    if self.gameState.state == self.GAME_STATE.PLAYER_TURN then
        if self.uiState.isMoving then
            love.graphics.setColor(0.3, 0.9, 0.3)
            love.graphics.print("Green=Move Red=Attack | RightClick=Cancel | E=End Turn", 10, 570)
        else
            love.graphics.print("Click card or Space to act | E=End Turn", 10, 570)
        end
    elseif self.gameState.state == self.GAME_STATE.ENEMY_TURN then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.print("Enemy turn...", 10, 570)
    end
end

-- ========================================
-- 输入处理
-- ========================================

function Game:keypressed(key)
    local GAME_STATE = self.GAME_STATE
    local Skills = self.modules.Skills

    -- 游戏结束状态
    if self.gameState.state == GAME_STATE.GAME_OVER or
       self.gameState.state == GAME_STATE.VICTORY then
        if key == "r" then
            self:startNewRun()
        elseif key == "n" then
            self:hardReset()
        end
        return
    end

    if self.gameState.state ~= GAME_STATE.PLAYER_TURN then
        return
    end

    if key == "escape" then
        if self.uiState.showUpgradeMenu then
            self.uiState.showUpgradeMenu = false
        elseif self.uiState.isMoving then
            self:exitMoveMode()
        else
            love.event.quit()
        end
    elseif key == "space" or key == "m" then
        if self.gameState.player then
            self:enterMoveMode(self.gameState.player)
        end
    elseif key == "e" then
        self:endPlayerTurn()
    elseif key == "u" then
        self.uiState.showUpgradeMenu = not self.uiState.showUpgradeMenu
    elseif key == "1" or key == "2" or key == "3" or key == "4" then
        local skillIndex = tonumber(key)
        local skills = Skills.getPlayerSkills()
        print(string.format("[Skill] Key %s pressed, skillIndex=%d, skills count=%d", key, skillIndex, #skills))
        if skills[skillIndex] then
            print(string.format("[Skill] Skill found: %s, cooldown=%d", skills[skillIndex].name, skills[skillIndex].currentCooldown))
            if skills[skillIndex].currentCooldown == 0 then
                self.uiState.selectedSkillIndex = skillIndex
                self:enterMoveMode(self.gameState.player)
                print("[Skill] Entered move mode for skill")
            else
                print("[Skill] Skill on cooldown")
            end
        else
            print("[Skill] No skill at index " .. skillIndex)
        end
    elseif self.uiState.isMoving then
        print(string.format("[Input] In move mode, key=%s, selectedSkillIndex=%s", key, tostring(self.uiState.selectedSkillIndex)))
        local dirKey = nil
        if key == "up" or key == "w" then dirKey = "n"
        elseif key == "down" or key == "s" then dirKey = "s"
        elseif key == "left" or key == "a" then dirKey = "w"
        elseif key == "right" or key == "d" then dirKey = "e"
        end

        if dirKey then
            print(string.format("[Input] Direction: %s", dirKey))
            if self.uiState.selectedSkillIndex then
                self:useSelectedSkill(dirKey)
            else
                local dir = self.DIRECTIONS[dirKey]
                local newX = self.gameState.player.gridX + dir.dx
                local newY = self.gameState.player.gridY + dir.dy
                if not self:tryAttackAtDirection(self.gameState.player, dirKey) then
                    self:tryMoveCard(self.gameState.player, newX, newY)
                end
            end
        end
    end
end

function Game:mousepressed(x, y, button)
    local GAME_STATE = self.GAME_STATE
    local Utils = self.modules.Utils
    local UI = self.modules.UI
    local Config = self.modules.Config
    local Levels = self.modules.Levels
    local Progression = self.modules.Progression

    if self.gameState.state == GAME_STATE.GAME_OVER or
       self.gameState.state == GAME_STATE.VICTORY then
        return
    end

    -- 调整震动偏移
    local adjustedX = x - self.Anim.screen_shake.offsetX
    local adjustedY = y - self.Anim.screen_shake.offsetY

    -- 奖励选择
    if self.uiState.showRewardSelect and button == 1 then
        local startY = 200
        for i, reward in ipairs(self.uiState.rewardOptions) do
            local btnX, btnY = 200, startY + (i - 1) * 80
            if Utils.isPointInRect(adjustedX, adjustedY, btnX, btnY, 400, 60) then
                self:applyRewardAndContinue(reward)
                return
            end
        end
        return
    end

    -- 关卡选择
    if self.uiState.showLevelSelect and button == 1 then
        local levelData = Levels.getLevel(self.gameState.currentLevel)
        if levelData then
            local startY = 220
            for i, branchIndex in ipairs(levelData.branches) do
                local btnX, btnY = 250, startY + (i - 1) * 70
                local btnW, btnH = Config.UI.LEVEL_BTN_WIDTH, Config.UI.LEVEL_BTN_HEIGHT
                if Utils.isPointInRect(adjustedX, adjustedY, btnX, btnY, btnW, btnH) then
                    self:loadLevel(branchIndex)
                    return
                end
            end
        end
        return
    end

    -- 升级菜单
    if self.uiState.showUpgradeMenu and button == 1 then
        local upgrades = Progression.getAvailableUpgrades()
        local startY = 120
        for i, info in ipairs(upgrades) do
            local btnX, btnY = 200, startY + (i - 1) * 55
            local btnW, btnH = Config.UI.UPGRADE_BTN_WIDTH, Config.UI.UPGRADE_BTN_HEIGHT
            if Utils.isPointInRect(adjustedX, adjustedY, btnX, btnY, btnW, btnH) then
                if info.canBuy and not info.owned then
                    Progression.buyUpgrade(info.upgrade.id)
                    print("Bought upgrade: " .. info.upgrade.name)
                end
                return
            end
        end
        return
    end

    -- UI 按钮
    if button == 1 and UI.handleButtonClick(self.buttons, adjustedX, adjustedY) then
        return
    end

    if self.gameState.state ~= GAME_STATE.PLAYER_TURN then
        return
    end

    if button == 1 then
        local clickedCard = self:getCardAtScreen(adjustedX, adjustedY)
        local gridPos = self:getGridAtScreen(adjustedX, adjustedY)

        if self.uiState.isMoving and gridPos then
            if not self:tryAttackAt(self.gameState.player, gridPos.x, gridPos.y) then
                self:tryMoveCard(self.gameState.player, gridPos.x, gridPos.y)
            end
        elseif clickedCard and clickedCard.type == self.modules.Card.TYPE.PLAYER then
            self:enterMoveMode(clickedCard)
        else
            self.uiState.selectedCard = clickedCard
        end
    elseif button == 2 then
        self:exitMoveMode()
        self.uiState.selectedCard = nil
    end
end

-- ========================================
-- 清理
-- ========================================

function Game:cleanup()
    self.event_manager:clear_all()

    for _, area in pairs(self.card_areas) do
        area:remove()
    end
    self.card_areas = {}

    self.gameState.player = nil
    self.gameState.enemies = {}
    self.gameState.cards = {}

    if G.reset_instances then
        G.reset_instances()
    end

    print("[Game] Cleanup complete")
end

return Game
