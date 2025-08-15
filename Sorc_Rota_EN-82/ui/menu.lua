local my_utility = require("my_utility/my_utility")
local spell_priority = require("spell_priority")
local spell_data = require("my_utility/spell_data")

-- build spell table for menu rendering
local spells =
{
    arc_lash                = require("spells/arc_lash"),
    ball                    = require("spells/ball"),
    blizzard                = require("spells/blizzard"),
    chain_lightning         = require("spells/chain_lightning"),
    charged_bolts           = require("spells/charged_bolts"),
    deep_freeze             = require("spells/deep_freeze"),
    evade                   = require("spells/evade"),
    familiars               = require("spells/familiars"),
    flame_shield            = require("spells/flame_shield"),
    firewall                = require("spells/firewall"),
    fire_bolt               = require("spells/fire_bolt"),
    fireball                = require("spells/fireball"),
    frost_bolt              = require("spells/frost_bolt"),
    frost_nova              = require("spells/frost_nova"),
    frozen_orb              = require("spells/frozen_orb"),
    hydra                   = require("spells/hydra"),
    ice_armor               = require("spells/ice_armor"),
    ice_blade               = require("spells/ice_blade"),
    ice_shards              = require("spells/ice_shards"),
    incinerate              = require("spells/incinerate"),
    inferno                 = require("spells/inferno"),
    meteor                  = require("spells/meteor"),
    spear                   = require("spells/spear"),
    spark                   = require("spells/spark"),
    teleport                = require("spells/teleport"),
    teleport_ench           = require("spells/teleport_ench"),
    unstable_current        = require("spells/unstable_current")
}

local menu =
{
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean")),
    immortal_boolean        = checkbox:new(false, get_hash(my_utility.plugin_label .. "immortal_boolean")),
    immortal_drawings        = checkbox:new(false, get_hash(my_utility.plugin_label .. "immortal_drawings")),
    main_tree           = tree_node:new(0),

    -- Crackling Energy Snapshot Toggle
    crackling_energy_snapshot_enabled = checkbox:new(false, get_hash(my_utility.plugin_label .. "crackling_energy_snapshot_enabled")),

    -- Spell Category Tree Nodes
    active_spells_tree = tree_node:new(1),
    inactive_spells_tree = tree_node:new(1),

    -- Weighted Targeting System
    weighted_targeting_tree = tree_node:new(1),
    weighted_targeting_enabled = checkbox:new(true, get_hash(my_utility.plugin_label .. "weighted_targeting_enabled")),

    -- Special Target Weight Tree Node
    special_weights_tree = tree_node:new(1),

    -- Scan Settings
    scan_radius = slider_int:new(1, 30, 12, get_hash(my_utility.plugin_label .. "scan_radius")),
    scan_refresh_rate = slider_float:new(0.1, 1.0, 0.2, get_hash(my_utility.plugin_label .. "scan_refresh_rate")),
    min_targets = slider_int:new(1, 10, 1, get_hash(my_utility.plugin_label .. "min_targets")),
    comparison_radius = slider_float:new(0.1, 6.0, 3.0, get_hash(my_utility.plugin_label .. "comparison_radius")),

    -- Custom Weight Toggle
    custom_weights_enabled = checkbox:new(false, get_hash(my_utility.plugin_label .. "custom_weights_enabled")),

    -- Target Weights (with default values)
    boss_weight = slider_int:new(1, 100, 50, get_hash(my_utility.plugin_label .. "boss_weight")),
    elite_weight = slider_int:new(1, 100, 10, get_hash(my_utility.plugin_label .. "elite_weight")),
    champion_weight = slider_int:new(1, 100, 15, get_hash(my_utility.plugin_label .. "champion_weight")),
    any_weight = slider_int:new(0, 100, 2, get_hash(my_utility.plugin_label .. "any_weight")),

    -- Custom Buff Weights
    custom_buff_weights_enabled = checkbox:new(false, get_hash(my_utility.plugin_label .. "custom_buff_weights_enabled")),
    buff_weights_tree = tree_node:new(1),
    damage_resistance_provider_weight = slider_int:new(1, 100, 30, get_hash(my_utility.plugin_label .. "damage_resistance_provider_weight")),
    damage_resistance_receiver_penalty = slider_int:new(0, 20, 5, get_hash(my_utility.plugin_label .. "damage_resistance_receiver_penalty")),
    horde_objective_weight = slider_int:new(1, 100, 50, get_hash(my_utility.plugin_label .. "horde_objective_weight")),
    vulnerable_debuff_weight = slider_int:new(1, 5, 1, get_hash(my_utility.plugin_label .. "vulnerable_debuff_weight")),
}

-- configuration table exposed to services
local config =
{
    enabled                             = menu.main_boolean:get(),
    weighted_targeting_enabled          = menu.weighted_targeting_enabled:get(),
    scan_radius                         = menu.scan_radius:get(),
    scan_refresh_rate                   = menu.scan_refresh_rate:get(),
    min_targets                         = menu.min_targets:get(),
    comparison_radius                   = menu.comparison_radius:get(),
    custom_weights_enabled              = menu.custom_weights_enabled:get(),
    boss_weight                         = menu.boss_weight:get(),
    elite_weight                        = menu.elite_weight:get(),
    champion_weight                     = menu.champion_weight:get(),
    any_weight                          = menu.any_weight:get(),
    custom_buff_weights_enabled         = menu.custom_buff_weights_enabled:get(),
    damage_resistance_provider_weight   = menu.damage_resistance_provider_weight:get(),
    damage_resistance_receiver_penalty  = menu.damage_resistance_receiver_penalty:get(),
    horde_objective_weight              = menu.horde_objective_weight:get(),
    vulnerable_debuff_weight            = menu.vulnerable_debuff_weight:get(),
}

on_render_menu(function ()
    if not menu.main_tree:push("Sorcerer: Salad Version") then
        return;
    end;

    menu.main_boolean:render("Enable Plugin", "");
    config.enabled = menu.main_boolean:get();

    if not config.enabled then
        menu.main_tree:pop();
        return;
    end;

    -- 获取已装备的技能
    local equipped_spells = get_equipped_spell_ids()
    table.insert(equipped_spells, spell_data.evade.spell_id) -- 将躲避技能添加到列表中

    -- 检查传送附魔增益(增益ID 516547)
    local has_teleport_ench_buff = false
    local player_buffs = get_local_player():get_buffs()
    if player_buffs then
        for _, buff in ipairs(player_buffs) do
            if buff.name_hash == 516547 then
                has_teleport_ench_buff = true
                break
            end
        end
    end

    -- 如果检测到传送附魔增益，将其添加到已装备技能中
    if has_teleport_ench_buff then
        table.insert(equipped_spells, spell_data.teleport_ench.spell_id)
    end

    -- 为已装备技能创建查找表
    local equipped_lookup = {}
    for _, spell_id in ipairs(equipped_spells) do
        equipped_lookup[spell_id] = true
    end

    -- Weighted Targeting System menu
    if menu.weighted_targeting_tree:push("Weighted Targeting System") then
        menu.weighted_targeting_enabled:render("Enable Weighted Targeting", "Enable weighted system for prioritizing targets based on type and distance")
        config.weighted_targeting_enabled = menu.weighted_targeting_enabled:get()

        -- 仅在启用权重目标时显示配置选项
        if config.weighted_targeting_enabled then
            -- 扫描设置
            menu.scan_radius:render("Scan Radius", "Radius around character to scan for targets (1-30)")
            config.scan_radius = menu.scan_radius:get()
            menu.scan_refresh_rate:render("Refresh Rate", "Target scan refresh rate in seconds (0.1-1.0)", 1)
            config.scan_refresh_rate = menu.scan_refresh_rate:get()
            menu.min_targets:render("Minimum Targets", "Minimum number of targets required to activate weighted targeting system (1-10)")
            config.min_targets = menu.min_targets:get()
            menu.comparison_radius:render("Comparison Radius", "Radius to check nearby targets when calculating weights (0.1-6.0)", 1)
            config.comparison_radius = menu.comparison_radius:get()

            -- 自定义权重开关
            menu.custom_weights_enabled:render("Custom Enemy Weights", "Enable to customize weights for different enemy types")
            config.custom_weights_enabled = menu.custom_weights_enabled:get()

            -- 仅在启用自定义权重时显示权重滑块
            if config.custom_weights_enabled then
                -- 目标权重
                menu.boss_weight:render("Boss Weight", "Weight assigned to boss targets (1-100)")
                config.boss_weight = menu.boss_weight:get()
                menu.elite_weight:render("Elite Weight", "Weight assigned to elite targets (1-100)")
                config.elite_weight = menu.elite_weight:get()
                menu.champion_weight:render("Champion Weight", "Weight assigned to champion targets (1-100)")
                config.champion_weight = menu.champion_weight:get()
                menu.any_weight:render("Normal Target Weight", "Weight assigned to normal targets (0-100, set to 0 to ignore normal targets)")
                config.any_weight = menu.any_weight:get()
            end
            -- 自定义增益权重部分
            menu.custom_buff_weights_enabled:render("Custom Buff Weights", "Enable to customize weights for targets with special buffs")
            config.custom_buff_weights_enabled = menu.custom_buff_weights_enabled:get()
            if config.custom_buff_weights_enabled then
                menu.damage_resistance_provider_weight:render("Damage Resistance Provider Bonus", "Weight bonus for enemies providing damage resistance aura (1-100)")
                config.damage_resistance_provider_weight = menu.damage_resistance_provider_weight:get()
                menu.damage_resistance_receiver_penalty:render("Damage Resistance Receiver Penalty", "Weight penalty for enemies receiving damage resistance (0-20)")
                config.damage_resistance_receiver_penalty = menu.damage_resistance_receiver_penalty:get()
                menu.horde_objective_weight:render("Horde Objective Bonus", "Weight bonus for horde objective targets (1-100)")
                config.horde_objective_weight = menu.horde_objective_weight:get()
                menu.vulnerable_debuff_weight:render("Vulnerable Debuff Bonus", "Weight bonus for targets with vulnerable debuff (1-5)")
                config.vulnerable_debuff_weight = menu.vulnerable_debuff_weight:get()
            end
        end

        menu.weighted_targeting_tree:pop()
    end;

    -- 用已装备的技能ID填充查找表
    for _, spell_id in ipairs(equipped_spells) do
        equipped_lookup[spell_id] = true
    end

    -- 激活技能菜单(当前已装备的技能)
    if menu.active_spells_tree:push("Active Spells") then
        -- 遍历技能优先级以保持定义的顺序
        for _, spell_name in ipairs(spell_priority) do
            -- 检查技能是否存在于技能表、技能数据中，并且是否已装备
            if spells[spell_name] and spell_data[spell_name] and spell_data[spell_name].spell_id and equipped_lookup[spell_data[spell_name].spell_id] then
                spells[spell_name].menu()
            end
        end
        menu.active_spells_tree:pop()
    end

    -- 未激活技能菜单(当前未装备的技能)
    if menu.inactive_spells_tree:push("Inactive Spells") then
        -- 遍历技能优先级以保持定义的顺序
        for _, spell_name in ipairs(spell_priority) do
            -- 检查技能是否存在于技能表、技能数据中，并且是否未装备
            if spells[spell_name] and spell_data[spell_name] and spell_data[spell_name].spell_id and not equipped_lookup[spell_data[spell_name].spell_id] then
                spells[spell_name].menu()
            end
        end
        menu.inactive_spells_tree:pop()
    end;

    menu.main_tree:pop();

end)

return config
