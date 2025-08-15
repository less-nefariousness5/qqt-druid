local my_utility = require("my_utility/my_utility")

local menu_elements_deep_freeze = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_deep_freeze")),
    
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "deep_freeze_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "deep_freeze_elite_only_bool")),
    min_max_targets       = slider_int:new(0, 30, 5, get_hash(my_utility.plugin_label .. "min_max_number_of_targets_for_cast"))
}

local function menu()
    
    if menu_elements_deep_freeze.tree_tab:push("Deep Freeze") then
        menu_elements_deep_freeze.main_boolean:render("Enable Spell", "")

        if menu_elements_deep_freeze.main_boolean:get() then
            menu_elements_deep_freeze.priority_target:render("Priority Target", "Cast only when high-value targets are detected")
            menu_elements_deep_freeze.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
            menu_elements_deep_freeze.min_max_targets:render("Min Nearby Enemies", "Number of targets required to cast this spell")
        end

        menu_elements_deep_freeze.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local spell_id_deep_freeze = 291827;

-- Function to check if there are priority targets nearby for self-cast skills
local function has_priority_targets_nearby(target_selector_data)
    if not target_selector_data then
        return false, "none"
    end
    
    local elite_only = menu_elements_deep_freeze.elite_only:get()
    
    -- Check for boss targets first (highest priority)
    if target_selector_data.has_boss then
        return true, "Boss"
    end
    
    -- Then check for champion targets
    if target_selector_data.has_champion then
        return true, "Champion"
    end
    
    -- Then check for elite targets
    if target_selector_data.has_elite then
        return true, "Elite"
    end
    
    -- Only check for regular targets if elite_only is false
    if not elite_only then
        return false, "none"
    end
    
    return false, "none"
end

local function logics(best_target, target_selector_data)

    local menu_boolean = menu_elements_deep_freeze.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_deep_freeze);

    if not is_logic_allowed then
    return false;
    end;
    
    -- Default enable_deep_freeze to true if priority target is not active
    local enable_deep_freeze = menu_elements_deep_freeze.enable_deep_freeze:get() or 
                              (not menu_elements_deep_freeze.priority_target:get());
    
    -- Priority Targeting Mode: only cast if high-value targets are nearby
    if menu_elements_deep_freeze.priority_target:get() and target_selector_data then
        local has_priority, target_type = has_priority_targets_nearby(target_selector_data)
        
        if not has_priority then
            if debug_enabled then
                console.print("[PRIORITY] No priority targets nearby for Deep Freeze");
            end
            return false
        else
            if debug_enabled then
                console.print("[PRIORITY] " .. target_type .. " target detected, proceeding with Deep Freeze");
            end
        end
    end

    local area_data = target_selector.get_most_hits_target_circular_area_light(get_player_position(), 5.5, 5.5, false)
    local units = area_data.n_hits

    if units < menu_elements_deep_freeze.min_max_targets:get() then
        return false;
    end;

    if cast_spell.self(spell_id_deep_freeze, 0.0) then
        
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 4;
        return true;
    end;


    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}