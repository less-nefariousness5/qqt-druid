local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements_corpse_base = {
    tree_tab_tendrils               = tree_node:new(1),
    main_boolean_tendrils           = checkbox:new(true, get_hash(my_utility.plugin_label .. "tendrils_boolean_base")),
    min_hits                        = slider_int:new(0, 30, 3, get_hash(my_utility.plugin_label .. "tendrils_min_hits_base")),
    max_range                       = slider_float:new(5.0, 12.0, 10.0, get_hash(my_utility.plugin_label .. "corpse_tendrils_max_range")),
}

local function menu()
    if menu_elements_corpse_base.tree_tab_tendrils:push("Corpse Tendrils") then
        menu_elements_corpse_base.main_boolean_tendrils:render("Enable Spell", "")

        if menu_elements_corpse_base.main_boolean_tendrils:get() then
            menu_elements_corpse_base.min_hits:render("Min Hits", "Minimum enemies to group with Corpse Tendrils")
            menu_elements_corpse_base.max_range:render("Max Range", "Maximum range to cast Corpse Tendrils")
        end

        menu_elements_corpse_base.tree_tab_tendrils:pop()
    end
end

local spell_id_corpse_tendrils = 463349
local next_time_allowed_cast = 0.0

-- Use proper spell data from module
local corpse_tendrils_spell_data = spell_data.corpse_tendrils and spell_data.corpse_tendrils.data or nil;

local function logics()
    -- Proper API validation sequence
    local menu_boolean = menu_elements_corpse_base.main_boolean_tendrils:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id_corpse_tendrils
    )

    if not is_logic_allowed then
        return false
    end

    -- Validate spell data exists
    if not corpse_tendrils_spell_data then
        return false;
    end

    local local_player = get_local_player();
    if not local_player then
        return false;
    end

    -- Check spell readiness with proper API
    if not local_player:is_spell_ready(spell_id_corpse_tendrils) then
        return false;
    end

    -- Proper resource check
    local current_mana = local_player:get_primary_resource_current()
    local max_mana = local_player:get_primary_resource_max()
    if max_mana > 0 then
        local mana_percentage = current_mana / max_mana
        if mana_percentage < 0.30 then -- Crowd control is important
            return false;
        end
    end

    local player_position = local_player:get_position()
    if not player_position then
        return false;
    end

    -- Find corpses using framework API
    local actors = actors_manager.get_ally_actors()
    local best_corpse = nil
    local best_hits = 0

    for _, object in ipairs(actors) do
        if object:get_skin_name() == "Necro_Corpse" then
            local corpse_position = object:get_position()
            local max_range = menu_elements_corpse_base.max_range:get()
            local distance_sqr = corpse_position:squared_dist_to_ignore_z(player_position)

            if distance_sqr <= (max_range * max_range) then
                -- Use framework API for hit calculation
                local hits = utility.get_amount_of_units_inside_circle(corpse_position, 4.0)

                if hits > best_hits then
                    best_hits = hits
                    best_corpse = object
                end
            end
        end
    end

    -- Check minimum hits requirement
    local min_hits = menu_elements_corpse_base.min_hits:get()
    if best_hits < min_hits or not best_corpse then
        return false;
    end

    -- Human-like timing controls
    local current_time = get_time_since_inject();
    local min_cast_interval = 0.20; -- Crowd control should have some delay

    if current_time - next_time_allowed_cast < min_cast_interval then
        return false;
    end

    -- Safe cast with framework API
    local success = cast_spell.target(best_corpse, corpse_tendrils_spell_data, false);
    if success then
        next_time_allowed_cast = current_time + 0.30;
        console.print("[Corpse Tendrils] Cast successful, grouped: " .. best_hits .. " enemies");
        return true;
    end

    return false;
end

return {
    menu = menu,
    logics = logics,
}
