local my_utility = require("my_utility/my_utility")

-- Import safe teleporting functions from teleport.lua (shared utilities)
local function calculate_distance(pos1, pos2)
    if type(pos2.get_position) == "function" then
        return pos1:dist_to_ignore_z(pos2:get_position())
    end
    if type(pos2.x) == "function" and type(pos2.y) == "function" then
        return pos1:dist_to_ignore_z(pos2)
    end
    if pos2.x and pos2.y then
        local temp_vec = vec3:new(pos2.x, pos2.y, pos1:z())
        return pos1:dist_to_ignore_z(temp_vec)
    end
    return 0
end

local function is_enemies_nearby(check_radius, threat_level)
    check_radius = check_radius or 6
    threat_level = threat_level or "any"
    
    local player_pos = get_player_position()
    local enemies = actors_manager.get_enemy_npcs()
    
    for _, enemy in ipairs(enemies) do
        if calculate_distance(player_pos, enemy:get_position()) < check_radius then
            if threat_level == "elite" then
                if enemy:is_elite() or enemy:is_champion() or enemy:is_boss() then
                    return true
                end
            else
                return true
            end
        end
    end
    return false
end

local function get_teleport_mode_ench(target)
    local player = get_local_player()
    if not player then
        return "EXPLORATION"
    end
    
    -- Emergency mode: low health
    local health_percentage = player:get_current_health() / player:get_max_health()
    if health_percentage < 0.3 then
        return "EMERGENCY"
    end
    
    -- Check if in active combat
    local enemies_nearby = is_enemies_nearby(8, "any")
    if enemies_nearby and target then
        if is_enemies_nearby(6, "elite") then
            return "COMBAT"
        end
        return "EXPLORATION"
    end
    
    return "EXPLORATION"
end

local function select_safe_teleport_target_ench(mode, target_enemy)
    local player_pos = get_player_position()
    if not player_pos or not target_enemy then
        return nil
    end
    
    local enemy_pos = target_enemy:get_position()
    local distance_to_enemy = calculate_distance(player_pos, enemy_pos)
    
    -- Mode-based distance configuration
    local safe_distance = 6  -- Default safe distance
    local max_distance = 15
    
    if mode == "COMBAT" then
        safe_distance = 4
        max_distance = 12
    elseif mode == "EMERGENCY" then
        safe_distance = 8
        max_distance = 20
    end
    
    -- Don't teleport if already close enough in exploration mode
    if mode == "EXPLORATION" and distance_to_enemy < 8 then
        return nil
    end
    
    -- Calculate direction to enemy
    local direction = vec3:new(
        enemy_pos:x() - player_pos:x(),
        enemy_pos:y() - player_pos:y(),
        0
    ):normalize()
    
    -- Calculate safe position near enemy (not on top of enemy)
    local target_distance = math.min(distance_to_enemy - safe_distance, max_distance)
    target_distance = math.max(target_distance, 5)  -- Minimum teleport distance
    
    local safe_target = player_pos:get_extended(direction, target_distance)
    safe_target = utility.set_height_of_valid_position(safe_target)
    
    if utility.is_point_walkeable(safe_target) then
        return safe_target
    end
    
    return nil
end

local menu_elements_teleport_ench =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "base_teleport_ench_base_main_bool")),
    cast_on_self        = checkbox:new(false, get_hash(my_utility.plugin_label .. "base_teleport_ench_cast_on_self_bool")),
    short_range_tp      = checkbox:new(false, get_hash(my_utility.plugin_label .. "base_teleport_ench_short_range_tp_bool")),
    priority_target     = checkbox:new(false, get_hash(my_utility.plugin_label .. "base_teleport_ench_priority_target_bool")),
}

local function menu()
    
    if menu_elements_teleport_ench.tree_tab:push("Teleport Enchantment") then
        menu_elements_teleport_ench.main_boolean:render("Enable Spell", "")
        
        if menu_elements_teleport_ench.main_boolean:get() then
            -- Track previous states before rendering
            local prev_self = menu_elements_teleport_ench.cast_on_self:get()
            local prev_priority = menu_elements_teleport_ench.priority_target:get()
            
            -- Render the checkboxes
            local self_clicked = menu_elements_teleport_ench.cast_on_self:render("Cast on Self", "Cast teleport at your current position")
            local priority_clicked = menu_elements_teleport_ench.priority_target:render("Cast on Priority Target", "Target Boss > Champion > Elite > Any")
            
            -- Get current states after rendering
            local curr_self = menu_elements_teleport_ench.cast_on_self:get()
            local curr_priority = menu_elements_teleport_ench.priority_target:get()
            
            -- Check if either option was just enabled
            local self_just_enabled = not prev_self and curr_self
            local priority_just_enabled = not prev_priority and curr_priority
            
            -- Handle mutual exclusivity
            if self_just_enabled then
                -- Cast on Self was just enabled, disable Priority Target
                menu_elements_teleport_ench.priority_target:set(false)
            elseif priority_just_enabled then
                -- Priority Target was just enabled, disable Cast on Self
                menu_elements_teleport_ench.cast_on_self:set(false)
            end
            
            -- Additional check for when clicking directly on an already disabled option
            if self_clicked and not prev_self then
                menu_elements_teleport_ench.cast_on_self:set(true)
                menu_elements_teleport_ench.priority_target:set(false)
            elseif priority_clicked and not prev_priority then
                menu_elements_teleport_ench.priority_target:set(true)
                menu_elements_teleport_ench.cast_on_self:set(false)
            end
            
            -- Final safety check
            if menu_elements_teleport_ench.cast_on_self:get() and menu_elements_teleport_ench.priority_target:get() then
                if self_clicked then
                    menu_elements_teleport_ench.priority_target:set(false)
                else
                    menu_elements_teleport_ench.cast_on_self:set(false)
                end
            end
            
            menu_elements_teleport_ench.short_range_tp:render("Short Range Teleport", "Prevent teleporting to random hills")
        end
        
        menu_elements_teleport_ench.tree_tab:pop()
    end
end

local spell_id_teleport_ench = 959728

local spell_data_teleport_ench = spell_data:new(
    5.0,                        -- radius
    8.0,                        -- range
    1.0,                        -- cast_delay
    0.7,                        -- projectile_speed
    false,                      -- has_collision
    spell_id_teleport_ench,     -- spell_id
    spell_geometry.circular,    -- geometry_type
    targeting_type.skillshot    -- targeting_type
)

local next_time_allowed_cast = 0.0
local_player = get_local_player()

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    
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
    
    -- Finally, use any available target
    if target_selector_data and target_selector_data.closest_unit then
        best_target = target_selector_data.closest_unit
        target_type = "Regular"
        return best_target, target_type
    end
    
    return nil, "none"
end

local function logics(target, target_selector_data)
    local_player = get_local_player()
    local menu_boolean = menu_elements_teleport_ench.main_boolean:get()
    local cast_on_self = menu_elements_teleport_ench.cast_on_self:get()
    local priority_target = menu_elements_teleport_ench.priority_target:get()
    local short_range_tp = menu_elements_teleport_ench.short_range_tp:get()

    -- Short Range Teleport Range
    if short_range_tp then
        spell_data_teleport_ench.range = 5.0
    else
        spell_data_teleport_ench.range = 8.0
    end
    
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_teleport_ench)

    -- Check if logic is allowed first - this prevents excessive calls
    if not is_logic_allowed then
        return false
    end

    local current_orb_mode = orbwalker.get_orb_mode()

    if not menu_boolean then
        return false
    end

    if current_orb_mode == orb_mode.none then
        return false
    end

    if not local_player:is_spell_ready(spell_id_teleport_ench) then
        return false
    end

    -- Cast on self mode
    if cast_on_self then
        if cast_spell.self(spell_id_teleport_ench, 0.5) then
            local current_time = get_time_since_inject()
            next_time_allowed_cast = current_time + 0.5

            if debug_enabled then
                console.print("Casted Teleport Enchantment on Self");
            end
            return true
        end
    -- Priority target mode with safe teleporting
    elseif priority_target and target_selector_data then
        local best_target, target_type = get_priority_target(target_selector_data)
        
        if best_target then
            local teleport_mode = get_teleport_mode_ench(best_target)
            local safe_position = select_safe_teleport_target_ench(teleport_mode, best_target)
            
            if safe_position then
                if cast_spell.position(spell_id_teleport_ench, safe_position, 0.5) then
                    local current_time = get_time_since_inject()
                    next_time_allowed_cast = current_time + 0.5

                    if debug_enabled then
                        console.print("Safe Teleport Enchantment to " .. target_type .. " [" .. teleport_mode .. "]");
                    end
                    return true
                end
            else
                if debug_enabled then
                    console.print("No safe position for Teleport Enchantment to " .. target_type);
                end
            end
        else
            if debug_enabled then
                console.print("No valid priority target found for Teleport Enchantment");
            end
        end
    -- Regular target mode with safe teleporting
    else
        if target then
            local teleport_mode = get_teleport_mode_ench(target)
            local safe_position = select_safe_teleport_target_ench(teleport_mode, target)
            
            if safe_position then
                if cast_spell.position(spell_id_teleport_ench, safe_position, 0.75) then
                    local current_time = get_time_since_inject()
                    next_time_allowed_cast = current_time + 0.75

                    if debug_enabled then
                        console.print("Safe Teleport Enchantment [" .. teleport_mode .. "]");
                    end
                    return true
                end
            else
                if debug_enabled then
                    console.print("No safe position for Teleport Enchantment");
                end
            end
        end
    end
            
    return false
end

return 
{
    menu = menu,
    logics = logics,   
    menu_elements_teleport_ench = menu_elements_teleport_ench,
}
