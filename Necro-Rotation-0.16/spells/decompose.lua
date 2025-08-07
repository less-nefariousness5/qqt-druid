local my_utility = require("my_utility/my_utility");
local spell_data = require("my_utility/spell_data");

local menu_elements_decompose =
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_decompose_base")),
    max_range             = slider_float:new(8.0, 15.0, 12.0, get_hash(my_utility.plugin_label .. "decompose_max_range")),
}

local function menu()
    if menu_elements_decompose.tree_tab:push("Decompose") then
        menu_elements_decompose.main_boolean:render("Enable Spell", "")

        if menu_elements_decompose.main_boolean:get() then
            menu_elements_decompose.max_range:render("Max Range", "Maximum range to cast Decompose", 1)
        end

        menu_elements_decompose.tree_tab:pop()
    end
end

local spell_id_decompose = 463175
local next_time_allowed_cast = 0.0;

-- Use proper spell data from module
local decompose_spell_data = spell_data.decompose and spell_data.decompose.data or nil;

local function logics(target, entity_list)
    -- Proper API validation sequence
    local menu_boolean = menu_elements_decompose.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean,
                next_time_allowed_cast,
                spell_id_decompose);

    if not is_logic_allowed then
        return false;
    end;

    -- Validate spell data exists
    if not decompose_spell_data then
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

    -- Check spell readiness with proper API
    if not local_player:is_spell_ready(spell_id_decompose) then
        return false;
    end

    -- Proper resource check - Decompose is expensive
    local current_mana = local_player:get_primary_resource_current()
    local max_mana = local_player:get_primary_resource_max()
    if max_mana > 0 then
        local mana_percentage = current_mana / max_mana
        if mana_percentage < 0.35 then -- High mana requirement for channeled spell
            return false;
        end
    end

    -- Range validation
    local target_position = target:get_position()
    local player_position = local_player:get_position()

    if not target_position or not player_position then
        return false;
    end

    local max_range = menu_elements_decompose.max_range:get()
    local distance_sqr = target_position:squared_dist_to_ignore_z(player_position);
    if distance_sqr > (max_range * max_range) then
        return false;
    end

    -- Wall collision check using framework API
    local has_wall_collision = target_selector.is_wall_collision(player_position, target, 1.0);
    if has_wall_collision then
        return false;
    end

    -- Human-like timing controls
    local current_time = get_time_since_inject();
    local min_cast_interval = 0.18; -- Slightly longer for channeled spell

    if current_time - next_time_allowed_cast < min_cast_interval then
        return false;
    end

    -- Safe cast with framework API
    local success = cast_spell.target(target, decompose_spell_data, false);
    if success then
        next_time_allowed_cast = current_time + 0.5; -- Moderate cooldown for DoT spell
        console.print("[Decompose] Cast successful on " .. (target:is_boss() and "BOSS" or target:is_elite() and "ELITE" or "enemy"));
        return true;
    end

    return false;
end

return
{
    menu = menu,
    logics = logics,
}
