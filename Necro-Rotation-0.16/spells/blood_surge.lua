local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements_blood_surge =
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_blood_surge_base")),
    min_targets           = slider_int:new(1, 15, 3, get_hash(my_utility.plugin_label .. "blood_surge_min_targets")),
    health_threshold      = slider_float:new(0.50, 1.0, 0.80, get_hash(my_utility.plugin_label .. "blood_surge_health_threshold"))
}

local function menu()
    if menu_elements_blood_surge.tree_tab:push("Blood Surge") then
        menu_elements_blood_surge.main_boolean:render("Enable Spell", "")

        if menu_elements_blood_surge.main_boolean:get() then
            menu_elements_blood_surge.min_targets:render("Min Enemies Around", "Minimum nearby enemies to cast Blood Surge")
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

    -- Proper resource check
    local current_mana = local_player:get_primary_resource_current()
    local max_mana = local_player:get_primary_resource_max()
    if max_mana > 0 then
        local mana_percentage = current_mana / max_mana
        if mana_percentage < 0.25 then
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

    local health_threshold = menu_elements_blood_surge.health_threshold:get()

    -- Check health for Overwhelming Blood stacks (Blood Surge mechanic)
    local current_health = local_player:get_current_health()
    local max_health = local_player:get_max_health()
    if max_health > 0 then
        local health_percentage = current_health / max_health
        if health_percentage < health_threshold then
            return false; -- Need to be healthy for Overwhelming Blood
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
        console.print("[Blood Surge] Cast successful, enemies: " .. nearby_enemies);
        return true;
    end

    return false;
end

return
{
    menu = menu,
    logics = logics,
}
