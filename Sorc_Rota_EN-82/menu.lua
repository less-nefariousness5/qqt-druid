local my_utility = require("my_utility/my_utility")
local menu_elements_jmrz =
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

return menu_elements_jmrz;