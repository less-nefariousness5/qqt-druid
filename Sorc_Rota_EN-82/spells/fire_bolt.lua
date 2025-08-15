local my_utility = require("my_utility/my_utility")

local menu_elements_fire_bolt =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "test_fire_bolt_main_boolean")),
    
    priority_target     = checkbox:new(false, get_hash(my_utility.plugin_label .. "fire_bolt_priority_target_bool")),
    jmr_logic        = checkbox:new(true, get_hash(my_utility.plugin_label .. "test_fire_bolt_jmr_logic_boolean")),
    elite_only                = checkbox:new(true, get_hash(my_utility.plugin_label .. "test_fire_bolt_elite_only_boolean")),
}

local function menu()
    
    if menu_elements_fire_bolt.tree_tab:push("Fire Bolt")then
        menu_elements_fire_bolt.main_boolean:render("Enable Spell", "")
        
        if menu_elements_fire_bolt.main_boolean:get() then
            menu_elements_fire_bolt.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_fire_bolt.jmr_logic:render("Enable JMR Logic", "")
            menu_elements_fire_bolt.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
 
        menu_elements_fire_bolt.tree_tab:pop()
    end
end

local spell_id_fire_bolt = 153249;

local fire_bolt_spell_data = spell_data:new(
    0.7,                        -- radius
    20.0,                        -- range
    0.0,                        -- cast_delay
    4.0,                        -- projectile_speed
    true,                      -- has_collision
    spell_id_fire_bolt,           -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    --targeting_type
)
local next_time_allowed_cast = 0.0;

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = menu_elements_fire_bolt.elite_only:get()
    
    -- Check for boss targets first (highest priority)
    if target_selector_data and target_selector_data.has_boss then
        best_target = target_selector_data.closest_boss
        target_type = "Boss"
        return best_target, target_type
    end
    
    -- Then check for champion targets
    if target_selector_data and target_selector_data.has_champion then
        best_target = target_selector_data.closest_champion
        target_type = "Champion"
        return best_target, target_type
    end
    
    -- Then check for elite targets
    if target_selector_data and target_selector_data.has_elite then
        best_target = target_selector_data.closest_elite
        target_type = "Elite"
        return best_target, target_type
    end
    
    -- Finally, use any available target (only if elite_only is false)
    if not elite_only and target_selector_data and target_selector_data.closest_unit then
        best_target = target_selector_data.closest_unit
        target_type = "Regular"
        return best_target, target_type
    end
    
    return nil, "none"
end

local function logics(best_target, target_selector_data)
    
    local menu_boolean = menu_elements_fire_bolt.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_fire_bolt);

    if not is_logic_allowed then
        return false;
    end;
    
    -- Default enable_fire_bolt to true if priority target is not active
    local enable_fire_bolt = menu_elements_fire_bolt.enable_fire_bolt:get() or 
                            (not menu_elements_fire_bolt.priority_target:get());
    
    -- Priority Targeting Mode: prioritize targets by type
    if menu_elements_fire_bolt.priority_target:get() and target_selector_data then
        local priority_best_target, target_type = get_priority_target(target_selector_data)
        
        if priority_best_target then
            local player_position = get_player_position()
            local target_position = priority_best_target:get_position()
            local is_collision = prediction.is_wall_collision(player_position, target_position, 0.2)
            if not is_collision then
                if cast_spell.target(priority_best_target, fire_bolt_spell_data, false) then
                    local current_time = get_time_since_inject()
                    next_time_allowed_cast = current_time
                    if debug_enabled then console.print("[PRIORITY] Fire Bolt cast at " .. target_type .. " target") end
                    return true
                end
            end
        else
            if debug_enabled then console.print("[PRIORITY] No valid priority target found for Fire Bolt") end
        end
        
        return false
    end
    
    if not best_target then
        return false;
    end;

    if  menu_elements_fire_bolt.elite_only:get() then
        if not best_target:is_boss() and not best_target:is_elite() and not best_target:is_champion() then
            return false;
        end
    end
    
    local player_position = get_player_position();
    local target_position = best_target:get_position();
    local is_collision = prediction.is_wall_collision(player_position, target_position, 0.2)
    if is_collision then
        return false
    end

    if cast_spell.target(best_target, fire_bolt_spell_data, false) then

        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time;

        if debug_enabled then console.print("Sorcerer Plugin, Casted Fire Bolt"); end
        return true;
    end;
            
    return false;
end


return
{
    menu = menu,
    logics = logics,
    menu_elements_fire_bolt = menu_elements_fire_bolt,
}