local my_utility = require("my_utility/my_utility");
local movement_settings = require("movement_settings");

local menu_elements_sorc_base = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_teleport_base")),
   
    enable_teleport       = checkbox:new(false, get_hash(my_utility.plugin_label .. "enable_teleport_base")),
    keybind_ignore_hits   = checkbox:new(true, get_hash(my_utility.plugin_label .. "keybind_ignore_min_hits_base_tp")),
    exploration_movement  = checkbox:new(false, get_hash(my_utility.plugin_label .. "teleport_exploration_movement")), -- 新增：探索时移动
    
    min_hits              = slider_int:new(1, 20, 6, get_hash(my_utility.plugin_label .. "min_hits_to_cast_base_tp")),
    
    soft_score            = slider_float:new(2.0, 15.0, 6.0, get_hash(my_utility.plugin_label .. "min_percentage_hits_soft_core_tp")),
    
    teleport_on_self      = checkbox:new(false, get_hash(my_utility.plugin_label .. "teleport_on_self_base")),
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "teleport_priority_target_bool")),
    
    short_range_tele      = checkbox:new(false, get_hash(my_utility.plugin_label .. "short_range_tele_base")),
    
    tele_gtfo             = checkbox:new(false, get_hash(my_utility.plugin_label .. "gtfo"))
}

local function menu()
    if menu_elements_sorc_base.tree_tab:push("Teleport") then
        menu_elements_sorc_base.main_boolean:render("Enable Spell", "");
        
        if menu_elements_sorc_base.main_boolean:get() then
            -- Track previous states before rendering
            local prev_self = menu_elements_sorc_base.teleport_on_self:get()
            local prev_priority = menu_elements_sorc_base.priority_target:get()
            
            -- Render checkboxes
            local self_clicked = menu_elements_sorc_base.teleport_on_self:render("Cast on Self", "Cast teleport at your current position")
            local priority_clicked = menu_elements_sorc_base.priority_target:render("Cast on Priority Target", "Target priority: Boss > Champion > Elite > Any")
            menu_elements_sorc_base.exploration_movement:render("Exploration Movement", "Use teleport as movement spell in exploration mode")
            -- Update global movement settings
            movement_settings.update_teleport_exploration(menu_elements_sorc_base.exploration_movement:get())
            
            -- Get current states after rendering
            local curr_self = menu_elements_sorc_base.teleport_on_self:get()
            local curr_priority = menu_elements_sorc_base.priority_target:get()
            
            -- Check if either option was just enabled
            local self_just_enabled = not prev_self and curr_self
            local priority_just_enabled = not prev_priority and curr_priority
            
            -- Handle mutual exclusivity
            if self_just_enabled then
                -- Cast on Self was just enabled, disable Priority Target
                menu_elements_sorc_base.priority_target:set(false)
            elseif priority_just_enabled then
                -- Priority Target was just enabled, disable Cast on Self
                menu_elements_sorc_base.teleport_on_self:set(false)
            end
            
            -- Additional check for when clicking directly on an already disabled option
            if self_clicked and not prev_self then
                menu_elements_sorc_base.teleport_on_self:set(true)
                menu_elements_sorc_base.priority_target:set(false)
            elseif priority_clicked and not prev_priority then
                menu_elements_sorc_base.priority_target:set(true)
                menu_elements_sorc_base.teleport_on_self:set(false)
            end
            
            -- Final safety check
            if menu_elements_sorc_base.teleport_on_self:get() and menu_elements_sorc_base.priority_target:get() then
                if self_clicked then
                    menu_elements_sorc_base.priority_target:set(false)
                else
                    menu_elements_sorc_base.teleport_on_self:set(false)
                end
            end
            
            menu_elements_sorc_base.short_range_tele:render("Short Range Teleport", "Prevent teleporting to random hills");
            menu_elements_sorc_base.tele_gtfo:render("Emergency Teleport", "Emergency teleport when health is below 90 percent");
        end
        
        menu_elements_sorc_base.tree_tab:pop();
    end
end

local my_target_selector = require("my_utility/my_target_selector");

local spell_id_tp = 288106;

local spell_radius = 2.5;
local spell_max_range = 10.0;

local next_time_allowed_cast = 0.0;

-- Safe Teleporting System - Mode-based teleport target selection

-- Calculate distance between two positions
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

-- Check if enemies are nearby
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

-- Check if a position is safe for teleporting
local function is_safe_teleport_position(position)
    if not utility.is_point_walkeable(position) then
        return false
    end
    
    -- Check for walls around the position
    local wall_check_directions = {
        { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 },
        { x = 1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = 1 }, { x = -1, y = -1 }
    }
    
    local wall_count = 0
    for _, dir in ipairs(wall_check_directions) do
        local check_point = vec3:new(
            position:x() + dir.x * 2.0,
            position:y() + dir.y * 2.0,
            position:z()
        )
        check_point = utility.set_height_of_valid_position(check_point)
        if not utility.is_point_walkeable(check_point) then
            wall_count = wall_count + 1
        end
    end
    
    -- Avoid completely trapped positions
    return wall_count < 6
end

-- Teleport modes configuration
local teleport_modes = {
    COMBAT = {
        enemy_check_radius = 3,
        min_distance = 5,
        max_distance = 15,
        safe_distance_from_enemy = 4
    },
    EXPLORATION = {
        enemy_check_radius = 8,
        min_distance = 8,
        max_distance = 20,
        safe_distance_from_enemy = 6
    },
    EMERGENCY = {
        enemy_check_radius = 10,
        min_distance = 10,
        max_distance = 25,
        safe_distance_from_enemy = 8
    }
}

-- Select safe teleport target based on mode
local function select_safe_teleport_target(mode, target_enemy, player_pos)
    local config = teleport_modes[mode] or teleport_modes.EXPLORATION
    player_pos = player_pos or get_player_position()
    
    if not player_pos then
        return nil
    end
    
    -- Emergency mode: teleport away from enemies
    if mode == "EMERGENCY" then
        local enemies = actors_manager.get_enemy_npcs()
        local escape_direction = vec3:new(0, 0, 0)
        local enemy_count = 0
        
        -- Calculate average enemy position to escape opposite direction
        for _, enemy in ipairs(enemies) do
            local enemy_pos = enemy:get_position()
            if calculate_distance(player_pos, enemy_pos) < config.enemy_check_radius then
                escape_direction = vec3:new(
                    escape_direction:x() + (player_pos:x() - enemy_pos:x()),
                    escape_direction:y() + (player_pos:y() - enemy_pos:y()),
                    escape_direction:z()
                )
                enemy_count = enemy_count + 1
            end
        end
        
        if enemy_count > 0 then
            escape_direction = vec3:new(
                escape_direction:x() / enemy_count,
                escape_direction:y() / enemy_count,
                escape_direction:z()
            ):normalize()
            
            local escape_target = player_pos:get_extended(escape_direction, config.max_distance)
            escape_target = utility.set_height_of_valid_position(escape_target)
            
            if is_safe_teleport_position(escape_target) then
                return escape_target
            end
        end
        
        -- Fallback: try different angles for escape
        for angle = 0, 315, 45 do
            local rad = math.rad(angle)
            local direction = vec3:new(math.cos(rad), math.sin(rad), 0)
            local candidate = player_pos:get_extended(direction, config.max_distance)
            candidate = utility.set_height_of_valid_position(candidate)
            
            if is_safe_teleport_position(candidate) then
                return candidate
            end
        end
        
        return nil
    end
    
    -- Combat/Exploration modes: teleport toward enemy but maintain safe distance
    if target_enemy then
        local enemy_pos = target_enemy:get_position()
        local distance_to_enemy = calculate_distance(player_pos, enemy_pos)
        
        -- Don't teleport if already close enough in exploration mode
        if mode == "EXPLORATION" and distance_to_enemy < config.min_distance then
            return nil
        end
        
        -- Calculate direction to enemy
        local direction = vec3:new(
            enemy_pos:x() - player_pos:x(),
            enemy_pos:y() - player_pos:y(),
            0
        ):normalize()
        
        -- Calculate safe position near enemy (not on top of enemy)
        local safe_target_distance = math.min(distance_to_enemy - config.safe_distance_from_enemy, config.max_distance)
        safe_target_distance = math.max(safe_target_distance, config.min_distance)
        
        local safe_target = player_pos:get_extended(direction, safe_target_distance)
        safe_target = utility.set_height_of_valid_position(safe_target)
        
        if is_safe_teleport_position(safe_target) then
            return safe_target
        end
        
        -- Try alternative positions around the target
        for offset = -45, 45, 15 do
            local rad = math.atan2(direction:y(), direction:x()) + math.rad(offset)
            local alt_direction = vec3:new(math.cos(rad), math.sin(rad), 0)
            local alt_target = player_pos:get_extended(alt_direction, safe_target_distance)
            alt_target = utility.set_height_of_valid_position(alt_target)
            
            if is_safe_teleport_position(alt_target) then
                return alt_target
            end
        end
    end
    
    return nil
end

-- Determine teleport mode based on context
local function get_teleport_mode(best_target)
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
    if enemies_nearby and best_target then
        -- Combat mode if elite enemies nearby
        if is_enemies_nearby(6, "elite") then
            return "COMBAT"
        end
        return "EXPLORATION"
    end
    
    return "EXPLORATION"
end

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

-- Exploration mode movement function
local function cast_for_exploration_movement()
    -- Check if exploration movement is enabled
    if not menu_elements_sorc_base.exploration_movement:get() then
        return false;
    end

    -- Check if auto play mode is enabled
    local is_auto_play = my_utility.is_auto_play_enabled();
    if not is_auto_play then
        return false;
    end

    -- Check orbwalker mode, 3 is exploration mode
    local orb_mode = orbwalker.get_orb_mode();
    if orb_mode ~= 3 then
        return false;
    end

    local local_player = get_local_player();
    if not local_player then
        return false;
    end

    -- Check if skill is ready
    if not local_player:is_spell_ready(spell_id_tp) then
        return false;
    end

    -- Get player current position
    local player_position = get_player_position();
    
    -- Generate a forward movement target position (10 yards distance)
    local movement_distance = 10.0;
    local movement_direction = vec3:new(1, 0, 0); -- Default direction, can be adjusted as needed
    
    -- Can adjust teleport direction based on player's current movement direction
    -- Simplified here to teleport forward
    local target_position = player_position + movement_direction * movement_distance;

    -- Execute teleport
    if cast_spell.position(spell_id_tp, target_position, 0.3) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.4;
        console.print("[Exploration Mode] Teleport Movement Cast")
        return true;
    end

    return false;
end

local function logics(entity_list, target_selector_data, best_target)
    -- First check exploration mode movement
    if cast_for_exploration_movement() then
        return false; -- Don't block other skill execution
    end

    -- Make sure local_player is defined
    local local_player = get_local_player()
    if not local_player then
        return false
    end
    
    local menu_boolean = menu_elements_sorc_base.main_boolean:get();
    local priority_target = menu_elements_sorc_base.priority_target:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_tp);
                
    if not is_logic_allowed then
        return false;
    end

    if not local_player:is_spell_ready(spell_id_tp) then
        return false;
    end

    -- Tele Gtfo Logic
    if menu_elements_sorc_base.tele_gtfo:get() then
        local current_health = local_player:get_current_health();
        local max_health = local_player:get_max_health();
        local health_percentage = current_health / max_health;

        if health_percentage < 0.90 then
            local player_position = get_player_position();
            local safe_direction = vec3:new(1, 0, 0); -- Default safe direction
            local safe_distance = 10.0;  -- Distance Adjustments
            local safe_position = player_position:get_extended(safe_direction, safe_distance);

            -- No utility module available, use the position as is
            -- We could potentially add a small height adjustment here if needed

            cast_spell.position(spell_id_tp, safe_position, 0.3);
            next_time_allowed_cast = get_time_since_inject() + 0.1;
            console.print("Sorcerer Plugin, Casted Teleport due to I need to GTFO");
            return true;
        end
    end

    local player_position = get_player_position();
    -- Default enable_teleport to true if no special modes are active
    local enable_teleport = menu_elements_sorc_base.enable_teleport:get() or 
                           (not menu_elements_sorc_base.teleport_on_self:get() and 
                            not menu_elements_sorc_base.priority_target:get() and
                            not menu_elements_sorc_base.tele_gtfo:get());
    
    -- Short Range Teleport Range
    local adjusted_spell_max_range = spell_max_range;
    if menu_elements_sorc_base.short_range_tele:get() then
        adjusted_spell_max_range = 5.0;
    end

    -- Cast on Self
    if menu_elements_sorc_base.teleport_on_self:get() then
        cast_spell.self(spell_id_tp, 0.3);  
        next_time_allowed_cast = get_time_since_inject() + 0.4;
        console.print("Sorcerer Plugin, Casted Teleport on Self");
        return true;
    end
    
    -- Priority target mode with safe teleporting
    if menu_elements_sorc_base.priority_target:get() and target_selector_data then
        local best_target, target_type = get_priority_target(target_selector_data)
        
        if best_target then
            local teleport_mode = get_teleport_mode(best_target)
            local safe_position = select_safe_teleport_target(teleport_mode, best_target)
            
            if safe_position then
                if cast_spell.position(spell_id_tp, safe_position, 0.3) then
                    local current_time = get_time_since_inject()
                    next_time_allowed_cast = current_time + 0.4

                    console.print("Sorcerer Plugin, Safe Teleport to " .. target_type .. " [" .. teleport_mode .. "]")
                    return true
                end
            else
                console.print("No safe teleport position found for " .. target_type)
            end
        else
            console.print("No valid priority target found for Teleport")
        end
    end

    local keybind_ignore_hits = menu_elements_sorc_base.keybind_ignore_hits:get();
    local keybind_can_skip = keybind_ignore_hits and enable_teleport;

    local min_hits_menu = menu_elements_sorc_base.min_hits:get();

    -- Safe teleport logic for regular targets
    if not best_target then
        return false;
    end

    -- Use the best_target parameter that was passed to the function
    if not best_target:is_enemy() then
        return false;
    end
    
    -- Check if target is relevant (elite, champion, or boss)
    local is_relevant_target = best_target:is_elite() or best_target:is_champion() or best_target:is_boss();
    
    -- Only proceed if target is relevant or keybind_can_skip is true
    if not is_relevant_target and not keybind_can_skip then
        return false;
    end
    
    -- Use safe teleporting system
    local teleport_mode = get_teleport_mode(best_target)
    local safe_position = select_safe_teleport_target(teleport_mode, best_target, player_position)
    
    if not safe_position then
        console.print("No safe teleport position available")
        return false;
    end
    
    local cast_position_distance_sqr = safe_position:squared_dist_to_ignore_z(player_position);
    if cast_position_distance_sqr < 4.0 and not keybind_can_skip then
        return false;
    end

    cast_spell.position(spell_id_tp, safe_position, 0.3);
    local current_time = get_time_since_inject();
    next_time_allowed_cast = current_time + 0.4;

    console.print("Sorcerer Plugin, Safe Teleport [" .. teleport_mode .. "]");
    return true;

end

return 
{
    menu = menu,
    logics = logics,   
}

