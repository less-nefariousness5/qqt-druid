local gui = {}
local plugin_label = "Piteer V3.13"

local function create_checkbox(key)
    return checkbox:new(false, get_hash(plugin_label .. "_" .. key))
end


-- not able to require utils (and settings) because of circular reference
-- so the function lives in gui
function gui.get_character_class()
    local local_player = get_local_player();
    if not local_player then return 'default' end
    local class_id = local_player:get_character_class_id()
    local character_classes = {
        [0] = 'sorcerer',
        [1] = 'barbarian',
        [3] = 'rogue',
        [5] = 'druid',
        [6] = 'necromancer',
        [7] = 'spiritborn'
    }
    if character_classes[class_id] then
        return character_classes[class_id]
    else
        return 'default'
    end
end

gui.loot_modes_options = {
    "Nothing",    -- will get stuck
    "Sell",       -- will sell all and keep going
    "Salvage",    -- will salvage all and keep going
    "Stash",      -- nothing for now, will get stuck, but in future can be added
}

gui.loot_modes_enum = {
    NOTHING = 0,
    SELL = 1,
    SALVAGE = 2,
    STASH = 3,
}
gui.upgrade_modes_enum = {
    HIGHEST = 0,
    LOWEST = 1,
    PRIORITY = 2
}
gui.upgrade_mode = { "High to Low", "Low to High"}

-- Internal values for gamble categories (keep unchanged to ensure functionality)
gui.gamble_categories_internal = {
    ['sorcerer'] = {"Cap", "Key", "Chest", "Gloves", "Boots", "Pants", "Amulet", "Ring", "oneHandSword", "oneHandMace", "Dagger", "twoHandStaff", "Wand", "Focus"},
    ['barbarian'] = {"Cap", "Key", "Chest", "Gloves", "Boots", "Pants", "Amulet", "Ring", "oneHandAxe", "oneHandSword", "oneHandMace", "twoHandAxe", "twoHandSword", "twoHandMace", "twoHandPolearm"},
    ['rogue'] = {"Cap", "Key", "Chest", "Gloves", "Boots", "Pants", "Amulet", "Ring", "oneHandSword", "Dagger", "Bow", "Crossbow"},
    ['druid'] = {"Cap", "Key", "Chest", "Gloves", "Boots", "Pants", "Amulet", "Ring", "oneHandAxe", "oneHandSword", "oneHandMace", "twoHandAxe", "twoHandMace", "twoHandPolearm", "Dagger", "twoHandStaff", "Totem"},
    ['necromancer'] = {"Cap", "Key", "Chest", "Gloves", "Boots", "Pants", "Amulet", "Ring", "oneHandAxe", "oneHandSword", "oneHandMace", "twoHandAxe", "twoHandSword", "twoHandScythe", "twoHandMace", "Dagger", "Shield", "Wand", "Focus"},
    ['spiritborn'] = {"twoHandQuarterstaff", "Cap", "Key", "Chest", "Gloves", "Boots", "Pants", "Amulet", "Ring", "twoHandPolearm", "twoHandGlaive"},
    ['default'] = {"Class Not Loaded"}
}

-- Gamble categories display names in English
gui.gamble_categories = {
    ['sorcerer'] = {"Helmet", "Key", "Chest Armor", "Gloves", "Boots", "Pants", "Amulet", "Ring", "One-Hand Sword", "One-Hand Mace", "Dagger", "Two-Hand Staff", "Wand", "Focus"},
    ['barbarian'] = {"Helmet", "Key", "Chest Armor", "Gloves", "Boots", "Pants", "Amulet", "Ring", "One-Hand Axe", "One-Hand Sword", "One-Hand Mace", "Two-Hand Axe", "Two-Hand Sword", "Two-Hand Mace", "Polearm"},
    ['rogue'] = {"Helmet", "Key", "Chest Armor", "Gloves", "Boots", "Pants", "Amulet", "Ring", "One-Hand Sword", "Dagger", "Bow", "Crossbow"},
    ['druid'] = {"Helmet", "Key", "Chest Armor", "Gloves", "Boots", "Pants", "Amulet", "Ring", "One-Hand Axe", "One-Hand Sword", "One-Hand Mace", "Two-Hand Axe", "Two-Hand Mace", "Polearm", "Dagger", "Two-Hand Staff", "Totem"},
    ['necromancer'] = {"Helmet", "Key", "Chest Armor", "Gloves", "Boots", "Pants", "Amulet", "Ring", "One-Hand Axe", "One-Hand Sword", "One-Hand Mace", "Two-Hand Axe", "Two-Hand Sword", "Two-Hand Scythe", "Two-Hand Mace", "Dagger", "Shield", "Wand", "Focus"},
    ['spiritborn'] = {"Two-Hand Quarterstaff", "Helmet", "Key", "Chest Armor", "Gloves", "Boots", "Pants", "Amulet", "Ring", "Polearm", "Two-Hand Glaive"},
    ['default'] = {"Class Not Loaded"}
}

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox("main_toggle"),
    pit_settings_tree = tree_node:new(1),
    cerrigar_settings_tree = tree_node:new(1),
    melee_logic = create_checkbox("melee_logic"),
    elite_only_toggle = create_checkbox("elite_only"),
    pit_level = input_text:new(get_hash("piteer_pit_level_unique_id")),
    pit_level_slider = slider_int:new(1, 150, 1, 1984),
    loot_toggle = create_checkbox("loot_toggle"),
    loot_modes = combo_box:new(0, get_hash("piteer_loot_modes")),
    path_angle_slider = slider_int:new(0, 360, 10, get_hash("path_angle_slider")), -- 10 is a default value
    reset_time_slider = slider_int:new(60, 900, 600, get_hash("reset_time_slider")), -- New slider for reset time in seconds
    exit_pit_toggle = create_checkbox("exit_pit_toggle"),
    explorer_grid_size_slider = slider_int:new(10, 20, 15, get_hash("explorer_grid_size_slider")),
    gamble_category = {
        ['sorcerer'] = combo_box:new(0, get_hash("piteer_gamble_sorcerer_category")),
        ['barbarian'] = combo_box:new(0, get_hash("piteer_gamble_barbarian_category")),
        ['rogue'] = combo_box:new(0, get_hash("piteer_gamble_rogue_category")),
        ['druid'] = combo_box:new(0, get_hash("piteer_gamble_druid_category")),
        ['necromancer'] = combo_box:new(0, get_hash("piteer_gamble_necromancer_category")),
        ['spiritborn'] = combo_box:new(0, get_hash("piteer_gamble_spiritborn_category")),
        ['default'] = combo_box:new(0, get_hash("piteer_gamble_default_category")),
    },
    greater_affix_slider = slider_int:new(0, 3, 1, get_hash("greater_affix_slider")),
    gamble_toggle = create_checkbox("gamble_toggle"),
    gamble_threshold = slider_int:new(100, 2000, 1000, get_hash("gamble_threshold")),
    use_alfred = create_checkbox("use_alfred"),
    alfred_return = create_checkbox("aflred_return"),
    upgrade_toggle = create_checkbox("upgrade_toggle"),
    upgrade_mode = combo_box:new(0, get_hash("piteer_upgrade_mode")),
    upgrade_threshold = slider_int:new(10, 100, 50, get_hash("upgrade_threshold")),
    upgrade_legendary_toggle = create_checkbox("upgrade_legendary_toggle"),
    minimum_glyph_level = slider_int:new(1, 100, 1, get_hash("minimum_glyph_level")),
    maximum_glyph_level = slider_int:new(1, 100, 100, get_hash("maximum_glyph_level")),
    exit_pit_delay = slider_int:new(1, 300, 10, get_hash("exit_pit_delay")),
    cheat_death = create_checkbox("cheat_death"),
    escape_percentage = slider_int:new(10, 100, 40, get_hash("escape_percentage")),
    interact_shrine = create_checkbox('interact_shrine'),
    movement_tree = tree_node:new(2),
    movement_spell_in_explorer = create_checkbox("movement_spell_in_explorer"),
    use_evade_as_movement_spell = create_checkbox("use_evade_as_movement_spell"),
    use_teleport = create_checkbox("use_teleport"),
    use_teleport_enchanted = create_checkbox("use_teleport_enchanted"),
    ball_lightning_enabled = create_checkbox("ball_lightning_enabled"),
    use_dash = create_checkbox("use_dash"),
    use_shadow_step = create_checkbox("use_shadow_step"),
    use_the_hunter = create_checkbox("use_the_hunter"),
    use_soar = create_checkbox("use_soar"),
    use_rushing_claw = create_checkbox("use_rushing_claw"),
    use_leap = create_checkbox("use_leap"),
    ignore_normal_enemies_for_movement = create_checkbox("ignore_normal_enemies_for_movement"),
    disable_movement_on_boss = create_checkbox("disable_movement_on_boss"),
}

function gui.render()
    if not gui.elements.main_tree:push(plugin_label) then return end
    local class = gui.get_character_class()

    gui.elements.main_toggle:render("Enable", "Enable the bot")

    if gui.elements.pit_settings_tree:push("Pit Settings") then
        gui.elements.elite_only_toggle:render("Elite Only", "Only look for elite monsters in the pit?")
        gui.elements.loot_toggle:render("Enable Looting", "Enable/disable ground item looting")
        gui.elements.pit_level_slider:render("Pit Level", "Which pit level do you want to enter?")
        gui.elements.path_angle_slider:render("Path Angle", "Adjust path filtering angle (0-360 degrees)")
        gui.elements.explorer_grid_size_slider:render("Explorer Grid Size", "Adjust exploration grid size (1.0-2.0)")
        gui.elements.reset_time_slider:render("Reset Time (seconds)", "Set time to reset all dungeons (seconds)")
        gui.elements.exit_pit_toggle:render("Enable Exit Pit", "Enable/disable exit pit task")
        if gui.elements.exit_pit_toggle:get() then
            gui.elements.exit_pit_delay:render("Exit Delay", "Time to wait before completing pit (seconds)")
        end
        gui.elements.upgrade_toggle:render("Enable Glyph Upgrade", "Enable/disable glyph upgrade")
        if gui.elements.upgrade_toggle:get() then
            gui.elements.upgrade_mode:render("Upgrade Mode", gui.upgrade_mode, "Choose how to upgrade glyphs")
            gui.elements.upgrade_threshold:render("Upgrade Threshold", "Only upgrade glyphs when success rate is greater than or equal to upgrade threshold")
            gui.elements.upgrade_legendary_toggle:render("Upgrade to Legendary Glyph", "Disable this option to save gem fragments")
            gui.elements.minimum_glyph_level:render("Minimum Level", "Only upgrade glyphs with level greater than or equal to this value")
            gui.elements.maximum_glyph_level:render("Maximum Level", "Only upgrade glyphs with level less than or equal to this value")
        end
        gui.elements.interact_shrine:render("Enable Shrine Interaction (and Witchcraft Power)", "Enable shrine interaction (and Witchcraft Power S07)")
        gui.elements.cheat_death:render("Enable Expert Mode Death Protection", "Enable expert mode death protection")
        if gui.elements.cheat_death:get() then
            gui.elements.escape_percentage:render("Health Percentage", "Health percentage to immediately leave the pit")
        end
        gui.elements.movement_spell_in_explorer:render("Use Movement Spells in Explorer", "Try to use movement spells when exploring the pit")
        if gui.elements.movement_spell_in_explorer:get() then
            if gui.elements.movement_tree:push("Movement Spells") then
                gui.elements.use_evade_as_movement_spell:render("Default Evade", "Try to use evade as movement spell")
                gui.elements.use_teleport:render("Sorcerer Teleport", "Try to use sorcerer teleport as movement spell")
                gui.elements.use_teleport_enchanted:render("Sorcerer Enchanted Teleport", "Try to use sorcerer enchanted teleport as movement spell")
                gui.elements.ball_lightning_enabled:render("Ball Lightning Explorer Movement", "Use ball lightning as exploration movement spell (when no enemies)")
                gui.elements.use_dash:render("Rogue Dash", "Try to use rogue dash as movement spell")
                gui.elements.use_shadow_step:render("Rogue Shadow Step", "Try to use rogue shadow step as movement spell")
                gui.elements.use_the_hunter:render("Spiritborn The Hunter", "Try to use spiritborn the hunter as movement spell")
                gui.elements.use_soar:render("Spiritborn Soar", "Try to use spiritborn soar as movement spell")
                gui.elements.use_rushing_claw:render("Spiritborn Rushing Claw", "Try to use spiritborn rushing claw as movement spell")
                gui.elements.use_leap:render("Barbarian Leap", "Try to use barbarian leap as movement spell")
                
                -- Add option to ignore normal enemies
                gui.elements.ignore_normal_enemies_for_movement:render("Ignore Normal Enemies", "When enabled, movement spells will ignore normal enemies, only detect elites/champions/bosses")
                
                -- Add option to stop movement spells when encountering bosses
                gui.elements.disable_movement_on_boss:render("Stop Movement on Boss", "When enabled, will stop using exploration movement spells when encountering bosses")
                
                gui.elements.movement_tree:pop()
            end
        end
        gui.elements.pit_settings_tree:pop()
    end
    if gui.elements.cerrigar_settings_tree:push("Cerrigar Settings") then
        if PLUGIN_alfred_the_butler then
            local alfred_status = PLUGIN_alfred_the_butler.get_status()
            if alfred_status.enabled then
                gui.elements.use_alfred:render("Use Alfred", "Use Alfred to manage salvaging/selling/stashing")
            end
        end
        if not PLUGIN_alfred_the_butler or not gui.elements.use_alfred:get() then
            gui.elements.loot_modes:render("Loot Mode", gui.loot_modes_options, "Currently 'Nothing' and 'Stash' will get stuck")
            gui.elements.greater_affix_slider:render("Greater Affix Threshold", "Set number of greater affixes for salvaging (0-3)")
        else
            gui.elements.alfred_return:render("Return to Collect Loot", "Return to pit to collect ground loot")
        end
        gui.elements.gamble_toggle:render("Enable Gambling", "Enable/disable gambling")
        if gui.elements.gamble_toggle:get() then
            gui.elements.gamble_threshold:render("Gambling Start Threshold", "How many obols needed to start gambling (100-2000)")
            gui.elements.gamble_category[class]:render("Gambling Category", gui.gamble_categories[class], "Select item category for gambling")
        end
        gui.elements.cerrigar_settings_tree:pop()
    end

    gui.elements.main_tree:pop()
end

return gui
