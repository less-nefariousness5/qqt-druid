local my_utility = require("my_utility/my_utility")

local spark_menu_elements =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "spark_main_boolean")),
    
    priority_target     = checkbox:new(false, get_hash(my_utility.plugin_label .. "spark_priority_target_bool")),
}

local function menu()
    
    if spark_menu_elements.tree_tab:push("Spark")then
        spark_menu_elements.main_boolean:render("Enable Spell", "")
        
        if spark_menu_elements.main_boolean:get() then
            spark_menu_elements.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
        end
 
        spark_menu_elements.tree_tab:pop()
    end
end

local spell_id_spark = 143483;

local spark_spell_data = spell_data:new(
    0.7,                        -- radius
    10.0,                        -- range
    1.0,                        -- cast_delay
    3.5,                        -- projectile_speed
    false,                      -- has_collision
    spell_id_spark,             -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    --targeting_type
)
local next_time_allowed_cast = 0.0;

-- Function to get the best target based on priority
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    
    if target_selector_data and target_selector_data.has_boss then
        return target_selector_data.closest_boss, "Boss"
    end
    
    if target_selector_data and target_selector_data.has_champion then
        return target_selector_data.closest_champion, "Champion"
    end
    
    if target_selector_data and target_selector_data.has_elite then
        return target_selector_data.closest_elite, "Elite"
    end
    
    if target_selector_data and target_selector_data.closest_unit then
        return target_selector_data.closest_unit, "Regular"
    end
    
    return nil, "none"
end

local function logics(best_target, target_selector_data)
    
    local menu_boolean = spark_menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_spark);

    if not is_logic_allowed then
        return false;
    end;
    
    local player_local = get_local_player();
    
    -- Default enable_spark to true if priority target is not active
    local enable_spark = not spark_menu_elements.priority_target:get();
    
    -- Priority Targeting Mode
    if spark_menu_elements.priority_target:get() and target_selector_data then
        local priority_best_target, target_type = get_priority_target(target_selector_data)
        
        if priority_best_target then
            if cast_spell.target(priority_best_target, spark_spell_data, false) then
                local current_time = get_time_since_inject()
                next_time_allowed_cast = current_time + 0.6
                if debug_enabled then console.print("[PRIORITY] Spark cast at " .. target_type .. " target") end
                return true
            end
        else
            if debug_enabled then console.print("[PRIORITY] No valid priority target found for Spark") end
        end
        
        return false
    end
    
    if not best_target then
        return false;
    end;

    if cast_spell.target(best_target, spark_spell_data, false) then

        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.6;

        if debug_enabled then console.print("Sorcerer Plugin, Casted Spark"); end
        return true;
    end;
            
    return false;
end


return 
{
    menu = menu,
    logics = logics,   
}