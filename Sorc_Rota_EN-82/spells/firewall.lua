local my_utility = require("my_utility/my_utility");

local menu_elements_firewall = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_firwall")),
    
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "firewall_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "firewall_elite_only_bool")),
}

local function menu()
    
    if menu_elements_firewall.tree_tab:push("Firewall")then
        menu_elements_firewall.main_boolean:render("Enable Spell", "")
        
        if menu_elements_firewall.main_boolean:get() then
            menu_elements_firewall.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_firewall.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
 
        menu_elements_firewall.tree_tab:pop()
    end
end

local spell_id_firewall = 111422
local next_time_allowed_cast = 0.0;

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = menu_elements_firewall.elite_only:get()
    
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
    
    local menu_boolean = menu_elements_firewall.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_firewall);

    if not is_logic_allowed then
    return false;
    end;
    
    -- Default enable_firewall to true if priority target is not active
    local enable_firewall = menu_elements_firewall.enable_firewall:get() or 
                           (not menu_elements_firewall.priority_target:get());
    
    -- Priority Targeting Mode: cast at priority target position
    if menu_elements_firewall.priority_target:get() and target_selector_data then
        local priority_best_target, target_type = get_priority_target(target_selector_data)
        
        if priority_best_target then
            local priority_target_position = priority_best_target:get_position()
            
            if cast_spell.position(spell_id_firewall, priority_target_position, 0.35) then
                local current_time = get_time_since_inject()
                next_time_allowed_cast = current_time + 0.1
                if debug_enabled then
                    console.print("[PRIORITY] Firewall cast at " .. target_type .. " target");
                end
                return true
            end
        else
            if debug_enabled then
                console.print("[PRIORITY] No valid priority target found for Firewall");
            end
        end
        
        return false
    end
    
    if not best_target then
        return false;
    end;

    local target_position = best_target:get_position();

    if cast_spell.position(spell_id_firewall, target_position, 0.35) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.1;
            
        if debug_enabled then
            console.print("Sorcerer Plugin, Firewall");
        end
        return true;
    end;
        
    return false;

end

return 
{
    menu = menu,
    logics = logics,   
}