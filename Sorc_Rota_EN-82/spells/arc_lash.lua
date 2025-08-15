local my_utility = require("my_utility/my_utility");

local menu_elements_sorc_lash_base = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_arc_lash")),
    
    enable_arc_lash       = checkbox:new(false, get_hash(my_utility.plugin_label .. "enable_arc_lash_base")),
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "arc_lash_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "arc_lash_elite_only_bool")),
}

local function menu()
    
    if menu_elements_sorc_lash_base.tree_tab:push("Arc Lash") then
        menu_elements_sorc_lash_base.main_boolean:render("Enable Spell", "")
        
        if menu_elements_sorc_lash_base.main_boolean:get() then
            menu_elements_sorc_lash_base.enable_arc_lash:render("Enable Arc Lash Casting", "Enable or disable active Arc Lash casting")
            menu_elements_sorc_lash_base.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_sorc_lash_base.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
 
        menu_elements_sorc_lash_base.tree_tab:pop()
    end
end

local local_player = get_local_player();
if local_player == nil then
    return
end

local spell_id_arc_lash = 297902
local arc_lash_data = spell_data:new(
    2.0,                              -- radius
    3.0,                            -- range
    0.8,                            -- cast_delay
    1.2,                            -- projectile_speed
    true,                          -- has_collision
    spell_id_arc_lash,              -- spell_id
    spell_geometry.circular,        -- geometry_type
    targeting_type.skillshot        --targeting_type
)
local next_time_allowed_cast = 0.0;

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = menu_elements_sorc_lash_base.elite_only:get()
    
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
    
    local menu_boolean = menu_elements_sorc_lash_base.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast,
                spell_id_arc_lash);

    if not is_logic_allowed then
        return false;
    end;
    
    -- Default enable_arc_lash to true if priority target is not active
    local enable_arc_lash = menu_elements_sorc_lash_base.enable_arc_lash:get() or 
                           (not menu_elements_sorc_lash_base.priority_target:get());
    
    -- Priority Targeting Mode: prioritize targets by type
    if menu_elements_sorc_lash_base.priority_target:get() and target_selector_data then
        local priority_best_target, target_type = get_priority_target(target_selector_data)
        
        if priority_best_target then
            if cast_spell.target(priority_best_target, arc_lash_data, false) then
                local current_time = get_time_since_inject()
                next_time_allowed_cast = current_time + 0.4
                if debug_enabled then
                    console.print("[PRIORITY] Arc Lash cast at " .. target_type .. " target");
                end
                return true
            end
        else
            if debug_enabled then
                console.print("[PRIORITY] No valid priority target found for Arc Lash");
            end
        end
        
        return false
    end
    
    if not best_target then
        return false;
    end;

    if cast_spell.target(best_target, arc_lash_data, false) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.4;
        
        if debug_enabled then
            console.print("Sorcerer Plugin, Casted Arc Lash");
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