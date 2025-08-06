local my_utility = require("my_utility/my_utility");
local spell_data = require("my_utility/spell_data");

local menu_elements_spear_base =
{
    tree_tab_bone                       = tree_node:new(1),
    main_boolean_bone                   = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_bone_spear_base")),
    priority_target                     = checkbox:new(true, get_hash(my_utility.plugin_label .. "bone_spear_priority_target_bool")),
    elite_only                          = checkbox:new(false, get_hash(my_utility.plugin_label .. "bone_spear_elite_only_bool")),
    min_hits_slider                     = slider_int:new(0, 30, 3, get_hash(my_utility.plugin_label .. "bone_spear_min_hits_slider")),
    max_range                           = slider_float:new(5.0, 12.0, 10.0, get_hash(my_utility.plugin_label .. "bone_spear_max_range")),
}

local function menu()
    if menu_elements_spear_base.tree_tab_bone:push("Bone Spear") then
        menu_elements_spear_base.main_boolean_bone:render("Enable Spell", "")
        
        if menu_elements_spear_base.main_boolean_bone:get() then
            menu_elements_spear_base.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_spear_base.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
            menu_elements_spear_base.min_hits_slider:render("Min Hits", "Minimum enemies to hit with Bone Spear")
            menu_elements_spear_base.max_range:render("Max Range", "Maximum range to cast Bone Spear")
        end

        menu_elements_spear_base.tree_tab_bone:pop()
    end
end

local spell_id_bone_spear = 432879
local next_time_allowed_cast = 0.0;

-- Use proper spell data from module
local bone_spear_spell_data = spell_data.bone_spear and spell_data.bone_spear.data or nil;
local my_target_selector = require("my_utility/my_target_selector");

local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = menu_elements_spear_base.elite_only:get()
    
    if target_selector_data and target_selector_data.has_boss then
        best_target = target_selector_data.closest_boss
        target_type = "Boss"
        return best_target, target_type
    end
    
    if target_selector_data and target_selector_data.has_champion then
        best_target = target_selector_data.closest_champion
        target_type = "Champion"
        return best_target, target_type
    end
    
    if target_selector_data and target_selector_data.has_elite then
        best_target = target_selector_data.closest_elite
        target_type = "Elite"
        return best_target, target_type
    end
    
    if not elite_only and target_selector_data and target_selector_data.closest_unit then
        best_target = target_selector_data.closest_unit
        target_type = "Regular"
        return best_target, target_type
    end
    
    return nil, "none"
end

local function logics(target, entity_list)
    -- Proper API validation sequence
    local menu_boolean = menu_elements_spear_base.main_boolean_bone:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean,
                next_time_allowed_cast,
                spell_id_bone_spear);

    if not is_logic_allowed then
        return false;
    end;

    -- Validate spell data exists
    if not bone_spear_spell_data then
        return false;
    end

    local local_player = get_local_player();
    if not local_player then
        return false;
    end

    -- Check spell readiness with proper API
    if not local_player:is_spell_ready(spell_id_bone_spear) then
        return false;
    end

    -- Proper resource validation
    local current_resource = local_player:get_primary_resource_current();
    local max_resource = local_player:get_primary_resource_max();
    if max_resource > 0 then
        local resource_percentage = current_resource / max_resource;
        if resource_percentage < 0.20 then
            return false;
        end
    end

    local player_pos = local_player:get_position();
    if not player_pos then
        return false;
    end

    -- Use framework API for area targeting
    local rectangle_width = 2.0;
    local rectangle_length = menu_elements_spear_base.max_range:get()
    
    local area_data = my_target_selector.get_most_hits_rectangle(player_pos, rectangle_length, rectangle_width)
    if not area_data or not area_data.main_target then
        return false;
    end

    local best_target = area_data.main_target;
    if not best_target:is_enemy() then
        return false;
    end

    -- Enhanced target validation
    local best_target_position = best_target:get_position();
    if not best_target_position then
        return false;
    end

    -- Distance check
    local distance_sqr = best_target_position:squared_dist_to_ignore_z(player_pos);
    local max_range = menu_elements_spear_base.max_range:get()
    if distance_sqr > (max_range * max_range) then
        return false;
    end

    -- Optimized hit calculation
    local best_cast_data = my_utility.get_best_point_rec(best_target_position, 1.0, 1.0, area_data.victim_list);
    local best_hit_list = best_cast_data.victim_list

    -- Minimum hits check
    local min_hits = menu_elements_spear_base.min_hits_slider:get()
    if #best_hit_list < min_hits then
        return false;
    end

    -- Priority target check
    local allow_priority = menu_elements_spear_base.priority_target:get()
    if allow_priority then
        for _, unit in ipairs(best_hit_list) do
            if unit:is_boss() or unit:is_elite() or unit:is_champion() then
                local current_health_percentage = unit:get_current_health() / unit:get_max_health()
                if current_health_percentage > 0.05 then -- 5% health minimum
                    break -- Allow casting for high-value targets
                end
            end
        end
    end

    -- Wall collision check using framework API
    local best_cast_position = best_cast_data.point;
    if target_selector.is_wall_collision(player_pos, best_target, 1.0) then
        return false;
    end

    -- Human-like timing controls
    local current_time = get_time_since_inject();
    local min_cast_interval = 0.15; -- Human-realistic minimum interval
    
    if current_time - next_time_allowed_cast < min_cast_interval then
        return false;
    end

    -- Safe cast with framework API
    local success = cast_spell.position(spell_id_bone_spear, best_cast_position, 0.3)
    if success then
        next_time_allowed_cast = current_time + 0.25;
        console.print("[Bone Spear] Cast successful, hits: " .. #best_hit_list);
        return true;
    end

    return false;
end

return
{
    menu = menu,
    logics = logics,
}