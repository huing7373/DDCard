-- functions/battle.lua
-- 战斗逻辑模块
-- 从 main.lua 提取的战斗相关函数

local Config = require("config")
local Combat = require("combat")
local Utils = require("utils")
local Progression = require("progression")
local Skills = require("skills")
local Roguelike = require("roguelike")

local GRID_OFFSET_X = Config.GRID.OFFSET_X
local GRID_OFFSET_Y = Config.GRID.OFFSET_Y
local CELL_SIZE = Config.GRID.CELL_SIZE
local DIRECTIONS = Config.DIRECTIONS

local Battle = {}

-- 执行攻击
-- @param context 包含: attacker, defender, direction, createDamageText, triggerScreenShake, removeCard, Card
function Battle.performAttack(context)
    local attacker = context.attacker
    local defender = context.defender
    local direction = context.direction
    local createDamageText = context.createDamageText
    local triggerScreenShake = context.triggerScreenShake
    local removeCard = context.removeCard
    local grantKillReward = context.grantKillReward

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

    return {
        attackerDamage = attackerDamage,
        defenderDamage = defenderDamage,
        defenderKilled = defenderKilled,
        attackerKilled = attackerKilled,
    }
end

-- 发放击杀奖励
-- @param context 包含: killer, victim, createDamageText, gameState, Card
function Battle.grantKillReward(context)
    local killer = context.killer
    local victim = context.victim
    local createDamageText = context.createDamageText
    local gameState = context.gameState
    local Card = context.Card

    local hpRecover, randomDir, atkBonus = Combat.calculateKillReward(victim, Config)
    Combat.applyHpRecovery(killer, hpRecover)

    local killerScreenX, killerScreenY = Utils.getGridCellCenter(killer.gridX, killer.gridY, GRID_OFFSET_X, GRID_OFFSET_Y, CELL_SIZE)
    createDamageText(killerScreenX, killerScreenY - 20, "+" .. hpRecover, Config.COLORS.HEAL)

    if killer.type == Card.TYPE.PLAYER then
        -- Combat.applyAtkBonus(killer, randomDir, atkBonus)

        gameState.lastReward = {
            hpRecover = hpRecover,
            atkDir = randomDir,
            atkBonus = atkBonus
        }

        local soulReward = Combat.calculateSoulReward(victim)
        Progression.addSoulFragments(soulReward)


        createDamageText(killerScreenX + 30, killerScreenY - 30, "+" .. soulReward .. " Soul", Config.COLORS.SOUL)

        Roguelike.recordKill()

        local absorbedSkill = Skills.absorbSkill(victim.name)
        if absorbedSkill then
            print("Absorbed new skill!")
        end

        print(string.format("Kill reward: +%d HP, %s atk+%d, soul+%d",
            hpRecover, randomDir, atkBonus, soulReward))
    end

    return {
        hpRecover = hpRecover,
        atkDir = randomDir,
        atkBonus = atkBonus,
    }
end

return Battle
