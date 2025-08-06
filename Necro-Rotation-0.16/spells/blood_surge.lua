local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements_blood_surge = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_blood_surge_base")),
    min_targets           = slider_int:new(1, 15, 3, get_hash(my_utility.plugin_label .. "blood_surge_min_targets")),
    bloodwave_priority    = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_surge_bloodwave_priority")),
    elite_boost          = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_surge_elite_boost")),
    ring_support_mode     = checkbox:new(false, get_hash(my_utility.plugin_label .. "blood_surge_ring_support")),
    health_threshold      = slider_float:new(0.50, 1.0, 0.80, get_hash(my_utility.plugin_label .. "blood_surge_health_threshold"))
}

local function menu()
    if menu_elements_blood_surge.tree_tab:push("Blood Surge") then
        menu_elements_blood_surge.main_boolean:render("Enable Spell", "")

        if menu_elements_blood_surge.main_boolean:get() then
            menu_elements_blood_surge.min_targets:render("Min Enemies Around", "Minimum nearby enemies to cast Blood Surge")
            menu_elements_blood_surge.bloodwave_priority:render("Bloodwave Priority", "Higher priority in Bloodwave builds")
            menu_elements_blood_surge.elite_boost:render("Elite Boost", "Always cast when elite/boss enemies are nearby")
            menu_elements_blood_surge.ring_support_mode:render("Ring of Power Support", "Use as support skill for minion builds")
            menu_elements_blood_surge.health_threshold:render("Health Threshold", "Cast when above this health % (for Overwhelming Blood)", 2)
        end

        menu_elements_blood_surge.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local spell_id_blood_surge = 592163;

-- Use proper spell data from module  
local blood_surge_spell_data = spell_data.blood_surge and spell_data.blood_surge.data or nil;
local function logics()
    -- Proper API validation sequence
    local menu_boolean = menu_elements_blood_surge.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_blood_surge);

    if not is_logic_allowed then
        return false;
    end;

    -- Validate spell data exists
    if not blood_surge_spell_data then
        return false;
    end

    local local_player = get_local_player();
    if not local_player then
        return false;
    end

    -- Check spell readiness with proper API
    if not local_player:is_spell_ready(spell_id_blood_surge) then
        return false;
    end

    -- Proper resource check with build integration
    local build_settings = my_utility.get_build_settings()
    local current_mana = local_player:get_primary_resource_current()
    local max_mana = local_player:get_primary_resource_max()
    if max_mana > 0 then
        local mana_percentage = current_mana / max_mana
        local mana_threshold = build_settings.mana_conservation + 0.05 -- Slightly higher for resource spender
        if mana_percentage < mana_threshold then
            return false;
        end
    end

    local player_pos = local_player:get_position()
    if not player_pos then
        return false;
    end

    -- Use framework API for area detection - Blood Surge is a self-cast AoE
    local surge_radius = 2.0 -- Self-cast AoE radius
    local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, surge_radius, surge_radius, false)
    
    if not area_data then
        return false;
    end

    local nearby_enemies = area_data.n_hits or 0
    local min_targets = menu_elements_blood_surge.min_targets:get()

    -- Elite boost - always cast if elite/boss nearby regardless of count
    local elite_boost = menu_elements_blood_surge.elite_boost:get()
    if elite_boost then
        local enemies = actors_manager.get_enemy_npcs()
        for _, enemy in ipairs(enemies) do
            if enemy:is_boss() or enemy:is_elite() or enemy:is_champion() then
                local enemy_position = enemy:get_position()
                local distance_sqr = enemy_position:squared_dist_to_ignore_z(player_pos)
                if distance_sqr <= (surge_radius * surge_radius) then
                    -- Elite within range, allow casting
                    nearby_enemies = math.max(nearby_enemies, 1)
                    break
                end
            end
        end
    end

    -- Ring of Power support mode logic
    local ring_support = menu_elements_blood_surge.ring_support_mode:get()
    local health_threshold = menu_elements_blood_surge.health_threshold:get()
    
    if ring_support and build_settings.selected_build == 1 then -- Ring of Power build
        -- Check health for Overwhelming Blood stacks (Blood Surge mechanic)
        local current_health = local_player:get_current_health()
        local max_health = local_player:get_max_health()
        if max_health > 0 then
            local health_percentage = current_health / max_health
            if health_percentage < health_threshold then
                return false; -- Need to be healthy for Overwhelming Blood
            end
        end
        
        -- In Ring of Power, use Blood Surge more conservatively as support
        min_targets = math.max(2, min_targets) -- Ensure at least 2 targets
        
        -- Prioritize when minions need help or for burst moments
        local minion_support_needed = false
        local enemies = actors_manager.get_enemy_npcs()
        for _, enemy in ipairs(enemies) do
            if (enemy:is_boss() or enemy:is_elite()) and enemy:get_position():squared_dist_to_ignore_z(player_pos) <= (8.0 * 8.0) then
                minion_support_needed = true
                break
            end
        end
        
        if not minion_support_needed and nearby_enemies < (min_targets + 1) then
            return false; -- Be more selective in Ring of Power mode
        end
    else
        -- Standard/Bloodwave mode - check build integration
        if build_settings.aggressive_mode then
            min_targets = math.max(1, min_targets - 1) -- Lower threshold in aggressive mode
        end
    end
    
    if nearby_enemies < min_targets then
        return false;
    end

    -- Human-like timing controls
    local current_time = get_time_since_inject();
    local min_cast_interval = 0.16; -- Self-cast spells can be slightly faster
    
    if current_time - next_time_allowed_cast < min_cast_interval then
        return false;
    end

    -- Safe cast with framework API - Blood Surge is a self-cast spell
    local success = cast_spell.self(spell_id_blood_surge, 0.0);
    if success then
        next_time_allowed_cast = current_time + 0.4;
        local mode_text = ring_support and " (Ring Support)" or ""
        console.print("[Blood Surge] Cast successful, enemies: " .. nearby_enemies .. mode_text);
        return true;
    end

    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}