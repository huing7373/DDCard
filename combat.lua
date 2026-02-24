-- Combat System Module
-- Centralized damage calculation and combat logic

local Combat = {}

-- Calculate damage for a combat encounter
-- Returns attackerDamage, defenderCounterDamage
function Combat.calculateDamage(attacker, defender, direction, directions)
    local oppositeDir = directions[direction].opposite
    local attackerDamage = attacker.attack[direction] or 0
    local defenderDamage = defender.attack[oppositeDir] or 0
    return attackerDamage, defenderDamage
end

-- Apply damage to both combatants
-- Returns defenderKilled, attackerKilled booleans
function Combat.applyDamage(attacker, defender, attackerDamage, defenderDamage)
    -- Apply shield absorption if defender has shield
    if defender.shield and defender.shield > 0 then
        local absorbed = math.min(defender.shield, attackerDamage)
        defender.shield = defender.shield - absorbed
        attackerDamage = attackerDamage - absorbed
    end

    -- Apply shield absorption for attacker's counter damage
    if attacker.shield and attacker.shield > 0 then
        local absorbed = math.min(attacker.shield, defenderDamage)
        attacker.shield = attacker.shield - absorbed
        defenderDamage = defenderDamage - absorbed
    end

    defender.hp = defender.hp - attackerDamage
    attacker.hp = attacker.hp - defenderDamage

    local defenderKilled = defender.hp <= 0
    local attackerKilled = attacker.hp <= 0

    return defenderKilled, attackerKilled
end

-- Calculate rewards for killing an enemy
-- Returns hpRecover, randomDir, atkBonus
function Combat.calculateKillReward(victim, config)
    local hpRecover = math.ceil(victim.maxHp * config.COMBAT.KILL_HP_RECOVERY_PERCENT)
    local randomDir = config.DIRECTION_KEYS[math.random(#config.DIRECTION_KEYS)]
    local atkBonus = math.random(
        config.COMBAT.RANDOM_ATK_BONUS_MIN,
        config.COMBAT.RANDOM_ATK_BONUS_MAX
    )
    return hpRecover, randomDir, atkBonus
end

-- Apply HP recovery to killer
function Combat.applyHpRecovery(killer, hpRecover)
    killer.hp = math.min(killer.hp + hpRecover, killer.maxHp)
    return killer.hp
end

-- Apply attack bonus to killer
function Combat.applyAtkBonus(killer, direction, bonus)
    killer.attack[direction] = (killer.attack[direction] or 0) + bonus
end

-- Evaluate combat outcome for AI decision making
-- Returns net damage (positive means attacker benefits)
function Combat.evaluateCombat(attacker, defender, direction, directions)
    local attackerDamage, defenderDamage = Combat.calculateDamage(attacker, defender, direction, directions)

    local netDamage = attackerDamage - defenderDamage

    -- Bonus for kill potential
    if attackerDamage >= defender.hp then
        netDamage = netDamage + 10
    end

    -- Penalty for death risk
    if defenderDamage >= attacker.hp then
        netDamage = netDamage - 15
    end

    return netDamage
end

-- Check if attack would be beneficial for AI
function Combat.isGoodAttack(attacker, defender, direction, directions)
    local score = Combat.evaluateCombat(attacker, defender, direction, directions)
    local attackerDamage = attacker.attack[direction] or 0

    -- Attack if net positive or can kill
    return score >= 0 or attackerDamage >= defender.hp
end

-- Calculate soul reward for killing an enemy
function Combat.calculateSoulReward(victim)
    return victim.maxHp
end

return Combat
