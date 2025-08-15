local my_utility = require("my_utility/my_utility");

local menu_elements_base_blade = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_ice_blade")),
    
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "ice_blade_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "ice_blade_elite_only_bool")),
    use_custom_cooldown   = checkbox:new(false, get_hash(my_utility.plugin_label .. "ice_blade_use_custom_cooldown")),
    custom_cooldown_sec   = slider_float:new(1.0, 10.0, 3.0, get_hash(my_utility.plugin_label .. "ice_blade_custom_cooldown_sec")),
}

local function menu()
    if menu_elements_base_blade.tree_tab:push("Ice Blades")then
        menu_elements_base_blade.main_boolean:render("Enable Spell", "")
        
        if menu_elements_base_blade.main_boolean:get() then
            menu_elements_base_blade.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_base_blade.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
        
        menu_elements_base_blade.use_custom_cooldown:render("Use Custom Cooldown", "Cast only once every X seconds")
        if menu_elements_base_blade.use_custom_cooldown:get() then
            menu_elements_base_blade.custom_cooldown_sec:render("Cooldown Time (seconds)", "", 2)
        end
        menu_elements_base_blade.tree_tab:pop()
    end
end

local spell_id_blade = 291492
local next_time_allowed_cast = 0.0
local last_cast_time = 0.0

local function logics(target)
    local current_time = get_time_since_inject()

    local menu_boolean = menu_elements_base_blade.main_boolean:get()
    local elite_only = menu_elements_base_blade.elite_only:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean, 
        next_time_allowed_cast, 
        spell_id_blade
    )


    if not is_logic_allowed then
        return false
    end
    
    -- 仅精英模式检查
    if elite_only and target then
        local is_elite = target:is_elite() or target:is_champion() or target:is_boss()
        if not is_elite then
            return false;
        end
    end

    local target_position = target:get_position()
    cast_spell.position(spell_id_blade, target_position, 0.02)
    next_time_allowed_cast = current_time + 0.1
    last_cast_time = current_time
    if debug_enabled then
        console.print("Sorcerer Plugin, Casted Ice");
    end
    return true
end

return 
{
    menu = menu,
    logics = logics,   
}