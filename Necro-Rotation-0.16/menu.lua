local my_utility = require("my_utility/my_utility")
local menu_elements_bone =
{
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean")),
    main_tree           = tree_node:new(0),
    
    -- Build selection
    build_selector      = combo_box:new(0, get_hash(my_utility.plugin_label .. "build_selector")),
    build_config_tree   = tree_node:new(1),
    
    -- Spell categorization trees
    active_spells_tree = tree_node:new(1),
    inactive_spells_tree = tree_node:new(1),
    
    -- Weighted targeting system (imported from Sorc)
    weighted_targeting_tree = tree_node:new(1),
    weighted_targeting_enabled = checkbox:new(false, get_hash(my_utility.plugin_label .. "weighted_targeting_enabled")),
    scan_radius = slider_float:new(1.0, 30.0, 16.0, get_hash(my_utility.plugin_label .. "scan_radius")),
    scan_refresh_rate = slider_float:new(0.1, 1.0, 0.3, get_hash(my_utility.plugin_label .. "scan_refresh_rate")),
    min_targets = slider_int:new(1, 10, 3, get_hash(my_utility.plugin_label .. "min_targets")),
    comparison_radius = slider_float:new(0.1, 6.0, 3.0, get_hash(my_utility.plugin_label .. "comparison_radius")),
    
    -- Custom weights
    custom_weights_enabled = checkbox:new(false, get_hash(my_utility.plugin_label .. "custom_weights_enabled")),
    boss_weight = slider_int:new(1, 100, 50, get_hash(my_utility.plugin_label .. "boss_weight")),
    elite_weight = slider_int:new(1, 100, 25, get_hash(my_utility.plugin_label .. "elite_weight")),
    champion_weight = slider_int:new(1, 100, 15, get_hash(my_utility.plugin_label .. "champion_weight")),
    any_weight = slider_int:new(0, 100, 5, get_hash(my_utility.plugin_label .. "any_weight")),
    
    -- Build-specific settings (consolidated and functional)
    bloodwave_build_tree = tree_node:new(1),
    ring_of_power_build_tree = tree_node:new(1),
    shadowblight_build_tree = tree_node:new(1),
    
    -- Global build settings that override individual spell settings
    build_aggressive_mode = checkbox:new(false, get_hash(my_utility.plugin_label .. "build_aggressive_mode")),
    build_elite_priority = checkbox:new(true, get_hash(my_utility.plugin_label .. "build_elite_priority")),
    build_mana_conservation = slider_float:new(0.15, 0.50, 0.25, get_hash(my_utility.plugin_label .. "build_mana_conservation")),
}

return menu_elements_bone;