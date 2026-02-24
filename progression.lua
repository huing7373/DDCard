-- Progression System Module
-- Manage soul fragments, upgrades and evolution points

local Utils = require("utils")

local Progression = {}

-- Player persistent data (kept across levels)
local playerData = {
    soulFragments = 0,
    evolutionPoints = 0,
    level = 1,
    exp = 0,
    totalKills = 0,
    bonusHp = 0,
    bonusAttack = 0,
    upgrades = {}
}

-- Upgrade options
Progression.UPGRADES = {
    {
        id = "hp_boost_1",
        name = "HP Boost I",
        description = "Max HP +5",
        cost = 10,
        effect = function(data) data.bonusHp = data.bonusHp + 5 end
    },
    {
        id = "hp_boost_2",
        name = "HP Boost II",
        description = "Max HP +10",
        cost = 25,
        requires = "hp_boost_1",
        effect = function(data) data.bonusHp = data.bonusHp + 10 end
    },
    {
        id = "atk_boost_1",
        name = "ATK Boost I",
        description = "All directions +1 ATK",
        cost = 15,
        effect = function(data) data.bonusAttack = data.bonusAttack + 1 end
    },
    {
        id = "atk_boost_2",
        name = "ATK Boost II",
        description = "All directions +2 ATK",
        cost = 35,
        requires = "atk_boost_1",
        effect = function(data) data.bonusAttack = data.bonusAttack + 2 end
    },
    {
        id = "soul_boost",
        name = "Soul Harvest",
        description = "Soul gain +50%",
        cost = 20,
        effect = function(data) data.soulBonus = 1.5 end
    }
}

-- Level experience table
local EXP_TABLE = {
    10,   -- 1->2
    25,   -- 2->3
    50,   -- 3->4
    100,  -- 4->5
    200,  -- 5->6
    350,  -- 6->7
    500,  -- 7->8
    750,  -- 8->9
    1000  -- 9->10
}

-- Get player data
function Progression.getData()
    return playerData
end

-- Get exp needed for next level
function Progression.getExpToNextLevel()
    if playerData.level >= #EXP_TABLE + 1 then
        return nil
    end
    return EXP_TABLE[playerData.level]
end

-- Add soul fragments
function Progression.addSoulFragments(amount)
    local multiplier = playerData.soulBonus or 1
    playerData.soulFragments = playerData.soulFragments + math.floor(amount * multiplier)
end

-- Add experience
function Progression.addExp(amount)
    playerData.exp = playerData.exp + amount
    playerData.totalKills = playerData.totalKills + 1

    local expNeeded = Progression.getExpToNextLevel()
    while expNeeded and playerData.exp >= expNeeded do
        playerData.exp = playerData.exp - expNeeded
        playerData.level = playerData.level + 1
        playerData.evolutionPoints = playerData.evolutionPoints + 1
        expNeeded = Progression.getExpToNextLevel()
    end
end

-- Find upgrade by ID
local function findUpgradeById(upgradeId)
    return Utils.findInList(Progression.UPGRADES, function(u)
        return u.id == upgradeId
    end)
end

-- Check if can buy upgrade
function Progression.canBuyUpgrade(upgradeId)
    if playerData.upgrades[upgradeId] then
        return false, "Already owned"
    end

    local upgrade = findUpgradeById(upgradeId)
    if not upgrade then
        return false, "Not found"
    end

    if upgrade.requires and not playerData.upgrades[upgrade.requires] then
        return false, "Requires prerequisite"
    end

    if playerData.soulFragments < upgrade.cost then
        return false, "Not enough souls"
    end

    return true, upgrade
end

-- Buy upgrade
function Progression.buyUpgrade(upgradeId)
    local canBuy, result = Progression.canBuyUpgrade(upgradeId)
    if not canBuy then
        return false, result
    end

    local upgrade = result
    playerData.soulFragments = playerData.soulFragments - upgrade.cost
    playerData.upgrades[upgradeId] = true

    if upgrade.effect then
        upgrade.effect(playerData)
    end

    return true, upgrade
end

-- Apply permanent bonuses to card
function Progression.applyToCard(card)
    card.maxHp = card.maxHp + playerData.bonusHp
    card.hp = card.maxHp

    for dir, _ in pairs(card.attack) do
        card.attack[dir] = card.attack[dir] + playerData.bonusAttack
    end
end

-- Reset progress (new game)
function Progression.reset()
    playerData = {
        soulFragments = 0,
        evolutionPoints = 0,
        level = 1,
        exp = 0,
        totalKills = 0,
        bonusHp = 0,
        bonusAttack = 0,
        upgrades = {}
    }
end

-- Get all available upgrades (for UI)
function Progression.getAvailableUpgrades()
    local available = {}
    for _, upgrade in ipairs(Progression.UPGRADES) do
        local canBuy, _ = Progression.canBuyUpgrade(upgrade.id)
        table.insert(available, {
            upgrade = upgrade,
            canBuy = canBuy,
            owned = playerData.upgrades[upgrade.id] or false
        })
    end
    return available
end

return Progression
