local my_utility = require("my_utility/my_utility");
local spell_data = require("my_utility/spell_data");

local menu_elements_blood_wave = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_blood_wave_base")),
    min_max_targets       = slider_int:new(0, 30, 3, get_hash(my_utility.plugin_label .. "min_max_blood_wave_base")),
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "blood_wave_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "blood_wave_elite_only_bool"))
}

local function menu()
    if menu_elements_blood_wave.tree_tab:push("Blood Wave") then
        menu_elements_blood_wave.main_boolean:render("Enable Spell", "")

        if menu_elements_blood_wave.main_boolean:get() then
            menu_elements_blood_wave.min_max_targets:render("Min Enemies Hit", "Minimum targets required to cast Blood Wave")
            menu_elements_blood_wave.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_blood_wave.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
 
        menu_elements_blood_wave.tree_tab:pop()
    end
end

local spell_id_blood_wave = 658216
local next_time_allowed_cast = 0.0;

-- Use proper spell data from module
local blood_wave_spell_data = spell_data.blood_wave and spell_data.blood_wave.data or nil;

local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = menu_elements_blood_wave.elite_only:get()
    
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

local function logics(target)
    -- Proper API validation sequence
    local menu_boolean = menu_elements_blood_wave.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_blood_wave);

    if not is_logic_allowed then
        return false;
    end;

    -- Validate spell data exists
    if not blood_wave_spell_data then
        return false;
    end

    -- Enhanced target validation
    if not target or not target:is_enemy() then
        return false;
    end

    local local_player = get_local_player();
    if not local_player then
        return false;
    end

    local player_pos = local_player:get_position();
    if not player_pos then
        return false;
    end

    -- Proper resource check with build integration
    local build_settings = my_utility.get_build_settings()
    local current_mana = local_player:get_primary_resource_current()
    local max_mana = local_player:get_primary_resource_max()
    if max_mana > 0 then
        local mana_percentage = current_mana / max_mana
        local mana_threshold = build_settings.mana_conservation
        if mana_percentage < mana_threshold then
            return false;
        end
    end

    -- Use framework API for area targeting
    local destination_range = 10.0
    local area_data = target_selector.get_most_hits_target_rectangle_area_heavy(player_pos, destination_range, 2.2)
    
    if not area_data or not area_data.main_target then
        return false;
    end

    local best_target_position = area_data.main_target:get_position();
    if not best_target_position then
        return false;
    end

    -- Optimized hit calculation
    local best_cast_data = my_utility.get_best_point_rec(best_target_position, 2.0, 2.0, area_data.victim_list);
    
    -- Build-integrated target requirements
    local required_targets = menu_elements_blood_wave.min_max_targets:get()
    if build_settings.aggressive_mode then
        required_targets = math.max(1, required_targets - 1) -- Lower threshold in aggressive mode
    end
    
    if best_cast_data.hits < required_targets then
        return false;
    end

    -- Safe casting with proper error handling
    local cast_position = best_cast_data.point;
    if not cast_position then
        cast_position = best_target_position;
    end

    -- Human-like timing delay
    local current_time = get_time_since_inject();
    local min_cast_interval = 0.15; -- Minimum realistic cast interval
    
    if current_time - next_time_allowed_cast < min_cast_interval then
        return false;
    end

    -- Safe cast with framework API
    local success = cast_spell.position(spell_id_blood_wave, cast_position, 0.3)
    if success then
        next_time_allowed_cast = current_time + 0.4;
        console.print("[Blood Wave] Cast successful, hits: " .. best_cast_data.hits);
        return true;
    end

    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}