local my_utility = require("my_utility/my_utility")

local frozen_orb_menu_elements =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "frozen_orb_main_boolean")),
    
    priority_target     = checkbox:new(false, get_hash(my_utility.plugin_label .. "frozen_orb_priority_target_bool")),
    elite_only          = checkbox:new(false, get_hash(my_utility.plugin_label .. "frozen_orb_elite_only_bool")),
}

local function menu()
    
    if frozen_orb_menu_elements.tree_tab:push("Frozen Orb")then
        frozen_orb_menu_elements.main_boolean:render("Enable Spell", "")
        
        if frozen_orb_menu_elements.main_boolean:get() then
            frozen_orb_menu_elements.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            frozen_orb_menu_elements.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
 
        frozen_orb_menu_elements.tree_tab:pop()
    end
end

local spell_id_fozen_orb = 291347;

local frozen_orb_data = spell_data:new(
    1.5,                        -- radius
    2.0,                        -- range
    1.0,                        -- cast_delay
    2.5,                        -- projectile_speed
    false,                      -- has_collision
    spell_id_fozen_orb,             -- spell_id
    spell_geometry.circular, -- geometry_type
    targeting_type.skillshot    --targeting_type
)
local next_time_allowed_cast = 0.0;

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = frozen_orb_menu_elements.elite_only:get()
    
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

    if  utility.is_spell_ready(292074) then
        return false;
    end;
	
    local menu_boolean = frozen_orb_menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_fozen_orb);

    if not is_logic_allowed then
        return false;
    end;
    
    local player_local = get_local_player();
    local player_position = get_player_position();
    
    -- Default enable_frozen_orb to true if priority target is not active
    local enable_frozen_orb = frozen_orb_menu_elements.enable_frozen_orb:get() or 
                             (not frozen_orb_menu_elements.priority_target:get());
    
    -- Priority Targeting Mode: prioritize targets by type
    if frozen_orb_menu_elements.priority_target:get() and target_selector_data then
        local priority_best_target, target_type = get_priority_target(target_selector_data)
        
        if priority_best_target then
            if cast_spell.target(priority_best_target, frozen_orb_data, false) then
                local current_time = get_time_since_inject()
                next_time_allowed_cast = current_time + 0.8
                if debug_enabled then console.print("[PRIORITY] Frozen Orb cast at " .. target_type .. " target") end
                return true
            end
        else
            if debug_enabled then console.print("[PRIORITY] No valid priority target found for Frozen Orb") end
        end
        
        return false
    end

    if not best_target then
        return false;
    end;

    local target_position = best_target:get_position();

    if cast_spell.target(best_target, frozen_orb_data, false) then

        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.8;

        if debug_enabled then console.print("Sorc Plugin, Casted Frozen Orb"); end
        return true;
    end;
            
    return false;
end


return 
{
    menu = menu,
    logics = logics,   
}