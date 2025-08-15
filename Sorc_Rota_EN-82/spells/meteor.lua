local my_utility = require("my_utility/my_utility");

local menu_elements_meteor = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_meteor")),
    
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "meteor_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "meteor_elite_only_bool")),
}

local function menu()
    
    if menu_elements_meteor.tree_tab:push("Meteor")then
        menu_elements_meteor.main_boolean:render("Enable Spell", "")
        
        if menu_elements_meteor.main_boolean:get() then
            menu_elements_meteor.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_meteor.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
 
        menu_elements_meteor.tree_tab:pop()
    end
end

local spell_id_meteor = 296998
local next_time_allowed_cast = 0.0;

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = menu_elements_meteor.elite_only:get()
    
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
    
    local menu_boolean = menu_elements_meteor.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_meteor);

    if not is_logic_allowed then
        return false;
    end;
    
    -- Default enable_meteor to true if priority target is not active
    local enable_meteor = menu_elements_meteor.enable_meteor:get() or 
                         (not menu_elements_meteor.priority_target:get());
    
    -- Priority Targeting Mode: prioritize targets by type
    if menu_elements_meteor.priority_target:get() and target_selector_data then
        local priority_best_target, target_type = get_priority_target(target_selector_data)
        
        if priority_best_target then
            local target_position = priority_best_target:get_position()
            if cast_spell.position(spell_id_meteor, target_position, 0.35) then
                local current_time = get_time_since_inject()
                next_time_allowed_cast = current_time + 1.0
                if debug_enabled then
                    console.print("[PRIORITY] Meteor cast at " .. target_type .. " target");
                end
                return true
            end
        else
            if debug_enabled then
                console.print("[PRIORITY] No valid priority target found for Meteor");
            end
        end
        
        return false
    end
    
    if not best_target then
        return false;
    end;

    local target_position = best_target:get_position();

    cast_spell.position(spell_id_meteor, target_position, 0.35) 
    local current_time = get_time_since_inject();
    next_time_allowed_cast = current_time + 1.0;
        
    if debug_enabled then
        console.print("Sorcerer Plugin, Meteor");
    end
    return true;

end

return 
{
    menu = menu,
    logics = logics,   
}