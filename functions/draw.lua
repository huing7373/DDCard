-- functions/draw.lua
-- UI 绘制函数模块
-- 从 main.lua 提取的绘制逻辑

local Config = require("config")
local UI = require("ui")
local Levels = require("levels")
local Skills = require("skills")
local Progression = require("progression")
local Utils = require("utils")
local Roguelike = require("roguelike")

local Draw = {}

-- 常用配置值的本地引用
local GRID_SIZE = Config.GRID.SIZE
local CELL_SIZE = Config.GRID.CELL_SIZE
local GRID_OFFSET_X = Config.GRID.OFFSET_X
local GRID_OFFSET_Y = Config.GRID.OFFSET_Y
local DIRECTIONS = Config.DIRECTIONS

-- 绘制回合信息
function Draw.turnInfo(gameState, GAME_STATE)
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
function Draw.buttons(buttons)
    local mx, my = love.mouse.getPosition()
    UI.drawButtons(buttons, mx, my)
end

-- 绘制技能栏
function Draw.skillBar(uiState)
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

-- 绘制进度信息
function Draw.progressionInfo()
    local data = Progression.getData()
    local infoX, infoY = 620, 300

    love.graphics.setColor(0.6, 0.4, 0.8)
    love.graphics.print("Progression", infoX, infoY)

    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.print(string.format("Level: %d", data.level), infoX, infoY + 20)

    local expNeeded = Progression.getExpForLevel(data.level + 1)
    love.graphics.setColor(0.7, 0.7, 0.7)
    if expNeeded then
        love.graphics.print(string.format("EXP: %d/%d", data.exp, expNeeded), infoX, infoY + 40)
    else
        love.graphics.print("MAX", infoX + 50, infoY + 40)
    end

    love.graphics.setColor(0.8, 0.5, 1)
    love.graphics.print(string.format("Soul: %d", data.soulFragments), infoX, infoY + 60)
end

-- 绘制关卡选择界面
function Draw.levelSelect(gameState)
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

-- 绘制升级菜单
function Draw.upgradeMenu()
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

-- 绘制游戏结束屏幕
function Draw.gameEndScreen(gameState, GAME_STATE)
    UI.drawOverlay(0.85)

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

-- 绘制奖励选择界面
function Draw.rewardSelect(rewardOptions)
    UI.drawOverlay(0.8)

    love.graphics.setColor(1, 0.9, 0.3)
    UI.drawCenteredText("Level Complete! Choose Reward", 0, 100, 800)

    local startY = 200
    local mx, my = love.mouse.getPosition()

    for i, reward in ipairs(rewardOptions) do
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

-- 绘制网格
function Draw.grid(gameState, uiState)
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

-- 绘制技能特效
function Draw.skillEffects(skillEffects)
    for _, effect in ipairs(skillEffects) do
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
            for _, dir in pairs(DIRECTIONS) do
                local cellX = effect.centerX + dir.dx * CELL_SIZE
                local cellY = effect.centerY + dir.dy * CELL_SIZE
                love.graphics.setColor(1, 0.3, 0.3, alpha * 0.5)
                love.graphics.rectangle("fill", cellX - CELL_SIZE/2, cellY - CELL_SIZE/2, CELL_SIZE, CELL_SIZE)
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

-- 绘制卡牌详情面板
function Draw.cardDetailPanel(uiState, Card)
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

-- 绘制伤害文字 (使用 Animation 系统数据)
function Draw.damageTexts(damageTexts)
    for _, dmg in ipairs(damageTexts) do
        love.graphics.setColor(dmg.color[1], dmg.color[2], dmg.color[3], dmg.alpha)
        local font = love.graphics.getFont()
        local textW = font:getWidth(dmg.text)
        local textH = font:getHeight()

        -- 对伤害数字应用缩放效果
        if dmg.useScale then
            local scale = 1 + dmg.alpha * (Config.EFFECTS.DAMAGE_SCALE_START - 1)
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

return Draw
