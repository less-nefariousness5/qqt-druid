local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements_blight_base = {
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_blight_base")),
    max_range             = slider_float:new(5.0, 12.0, 9.0, get_hash(my_utility.plugin_label .. "blight_max_range")),
}

local function menu()
    if menu_elements_blight_base.tree_tab:push("Blight") then
        menu_elements_blight_base.main_boolean:render("Enable Spell", "")

        if menu_elements_blight_base.main_boolean:get() then
            menu_elements_blight_base.max_range:render("Max Range", "Maximum range to cast Blight")
        end

        menu_elements_blight_base.tree_tab:pop()
    end
end

local blight_spell_id = 481293
local next_time_allowed_cast = 0.0

-- Use proper spell data from module
local blight_spell_data = spell_data.blight and spell_data.blight.data or nil;

local function logics(target)
    -- Proper API validation sequence
    local menu_boolean = menu_elements_blight_base.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        blight_spell_id
    )

    if not is_logic_allowed then
        return false
    end

    -- Validate spell data exists
    if not blight_spell_data then
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
    if not local_player:is_spell_ready(blight_spell_id) then
        return false;
    end

    -- Proper resource check
    local current_mana = local_player:get_primary_resource_current()
    local max_mana = local_player:get_primary_resource_max()
    if max_mana > 0 then
        local mana_percentage = current_mana / max_mana
        if mana_percentage < 0.25 then -- Blight is important for Shadowblight builds
            return false;
        end
    end

    -- Range validation with configurable distance
    local target_position = target:get_position()
    local player_position = local_player:get_position()

    if not target_position or not player_position then
        return false;
    end

    local max_range = menu_elements_blight_base.max_range:get()
    local distance_sqr = target_position:squared_dist_to_ignore_z(player_position);
    if distance_sqr > (max_range * max_range) then
        return false;
    end

    -- Wall collision check using framework API
    local has_wall_collision = target_selector.is_wall_collision(player_position, target, 0.5);
    if has_wall_collision then
        return false;
    end

    -- Human-like timing controls
    local current_time = get_time_since_inject();
    local min_cast_interval = 0.12; -- Slightly faster for DoT stacking

    if current_time - next_time_allowed_cast < min_cast_interval then
        return false;
    end

    -- Safe cast with framework API
    local success = cast_spell.target(target, blight_spell_data, false);
    if success then
        next_time_allowed_cast = current_time + 0.15;
        console.print("[Blight] Cast successful on " .. (target:is_boss() and "BOSS" or target:is_elite() and "ELITE" or "enemy"));
        return true;
    end

    return false;
end

return {
    menu = menu,
    logics = logics,
}
