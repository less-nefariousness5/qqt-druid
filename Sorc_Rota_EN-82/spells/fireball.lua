local my_utility = require("my_utility/my_utility")

local fireball_menu_elements =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "fire_ball_main_boolean")),
    -- Priority Targeting feature
    priority_target     = checkbox:new(false, get_hash(my_utility.plugin_label .. "fireball_priority_target_bool")),
    elite_only          = checkbox:new(false, get_hash(my_utility.plugin_label .. "fireball_elite_only_bool"))
}

local function menu()
    if fireball_menu_elements.tree_tab:push("Fireball") then
        fireball_menu_elements.main_boolean:render("Enable Spell", "")
        
        if fireball_menu_elements.main_boolean:get() then
            -- Render priority targeting checkbox
            fireball_menu_elements.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            fireball_menu_elements.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
        
        fireball_menu_elements.tree_tab:pop()
    end
end

local spell_id_fireball = 165023;

local fireball_spell_data = spell_data:new(
    0.7,                        -- radius
    12.0,                        -- range
    1.6,                        -- cast_delay
    2.0,                        -- projectile_speed
    true,                      -- has_collision
    spell_id_fireball,           -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    --targeting_type
)
local next_time_allowed_cast = 0.0;

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = fireball_menu_elements.elite_only:get()
    
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
    local menu_boolean = fireball_menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_fireball);
    if not is_logic_allowed then
        return false;
    end;
    
    local current_time = get_time_since_inject();
    local player_local = get_local_player();
    local player_position = get_player_position();
    local cast_success = false;
    local target = nil;
    local target_type = "none";
    
    -- Check if spell is ready
    if not player_local:is_spell_ready(spell_id_fireball) then
        return false;
    end
    
    -- Check mana
    local current_mana = player_local:get_primary_resource_current()
    local max_mana = player_local:get_primary_resource_max()
    local mana_percentage = current_mana / max_mana
    if mana_percentage < 0.8 then
        return false
    end
    
    -- Priority Targeting Mode: prioritize targets by type
    if fireball_menu_elements.priority_target:get() and target_selector_data then
        local priority_best_target, target_type = get_priority_target(target_selector_data)
        
        if priority_best_target then
            if cast_spell.target(priority_best_target, fireball_spell_data, false) then
                local current_time = get_time_since_inject()
                next_time_allowed_cast = current_time + 0.1
                if debug_enabled then console.print("[PRIORITY] Fireball cast at " .. target_type .. " target") end
                return true
            end
        else
            if debug_enabled then console.print("[PRIORITY] No valid priority target found for Fireball") end
        end
        
        return false
    end
    
    -- Standard casting logic (if neither Execute nor Force Cast is active)
    if not best_target then
        return false;
    end
    
    local target = best_target;
    local target_position = target:get_position();
    local target_buffs = target:get_buffs()
    
    -- Check if target has FireBolt (153249: Sorcerer_FireBolt)
    local has_firebolt = false
    for _, buff in ipairs(target_buffs or {}) do
        if buff.name_hash == 153249 then
            has_firebolt = true
            break
        end
    end
    
    if has_firebolt and cast_spell.target(target, fireball_spell_data, false) then
        next_time_allowed_cast = current_time + 0.1;
        if debug_enabled then console.print("[STANDARD] Fireball cast at target with FireBolt") end
        -- Don't return true for standard casting, allow rotation to continue
        -- This ensures standard fireball doesn't interrupt the casting flow
        return false;
    end;
    
    return false;
end


return 
{
    menu = menu,
    logics = logics,   
}