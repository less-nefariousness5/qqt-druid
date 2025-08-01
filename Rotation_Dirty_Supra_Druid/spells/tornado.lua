local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements =
{
    tree_tab       = tree_node:new(1),
    main_boolean   = checkbox:new(false, get_hash(my_utility.plugin_label .. "tornado_base_main_bool")),
    targeting_mode = combo_box:new(3, get_hash(my_utility.plugin_label .. "tornado_base_targeting_mode")),
}

local function menu()
    if menu_elements.tree_tab:push("Tornado") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
        end

        menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 1.1;
local next_time_allowed_move = 0.0;
local move_delay = 0.5; -- Adjust this value to control movement frequency

local function logics(target)
    if not target then return false end;
    local menu_boolean = menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.tornado.spell_id);

    if not is_logic_allowed then return false end;

    -- Checking for target distance
    local in_range = my_utility.is_in_range(target, my_utility.get_melee_range())
    if not in_range then
        -- Check if we can move again
        local current_time = get_time_since_inject();
        if current_time >= next_time_allowed_move then
            -- move to target
            local target_position = target:get_position()
            pathfinder.force_move_raw(target_position)
            next_time_allowed_move = current_time + move_delay;
        end
        return false;
    end

    if cast_spell.target(target, spell_data.tornado.spell_id, 0, false) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;

        console.print("Cast Tornado - Target: " ..
            my_utility.targeting_modes[menu_elements.targeting_mode:get() + 1]);
        return true;
    end;

    return false;
end

return
{
    menu = menu,
    logics = logics,
    menu_elements = menu_elements
}