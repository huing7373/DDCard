-- data/skills_data.lua
-- 技能元数据定义
-- 纯数据文件，不包含执行逻辑

local SkillsData = {}

-- 技能元数据
-- 格式: id, name, description, cooldown, params (默认参数)
SkillsData.SKILLS = {
    -- 1. 冲锋 - 移动并攻击
    charge = {
        id = "charge",
        name = "冲锋",
        description = "移动2格，对路径上的敌人造成伤害",
        cooldown = 3,
        params = {
            range = 2,           -- 冲锋距离
            damageMultiplier = 1.0 -- 伤害倍率
        }
    },

    -- 2. 吸血 - 伤害并治疗
    lifesteal = {
        id = "lifesteal",
        name = "吸血",
        description = "造成伤害，治疗伤害值的50%",
        cooldown = 4,
        params = {
            bonusDamage = 2,    -- 额外伤害
            healPercent = 0.5   -- 治疗比例
        }
    },

    -- 3. 旋风 - 攻击所有相邻敌人
    whirlwind = {
        id = "whirlwind",
        name = "旋风",
        description = "攻击所有8个相邻敌人",
        cooldown = 5,
        params = {
            damageMultiplier = 1.0 -- 伤害倍率
        }
    },

    -- 4. 护盾 - 临时保护
    shield = {
        id = "shield",
        name = "护盾",
        description = "获得临时护盾",
        cooldown = 4,
        params = {
            amount = 5 -- 护盾值
        }
    }
}

-- 技能吸收映射
-- 击杀特定敌人后可学习的技能
SkillsData.ABSORB_MAP = {
    ["Vampire"] = "lifesteal",
    ["Orc"] = "charge",
    ["Demon"] = "whirlwind"
}

-- 获取技能元数据
function SkillsData.get(skillId)
    return SkillsData.SKILLS[skillId]
end

-- 获取所有技能ID列表
function SkillsData.getAllIds()
    local ids = {}
    for id, _ in pairs(SkillsData.SKILLS) do
        table.insert(ids, id)
    end
    return ids
end

-- 获取技能吸收映射
function SkillsData.getAbsorbSkill(enemyName)
    return SkillsData.ABSORB_MAP[enemyName]
end

return SkillsData
