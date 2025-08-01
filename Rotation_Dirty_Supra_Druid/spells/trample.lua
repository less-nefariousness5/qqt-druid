local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local max_spell_range = 19
local menu_elements =
{
    tree_tab                = tree_node:new(1),
    main_boolean            = checkbox:new(false, get_hash(my_utility.plugin_label .. "_trample_main_boolean")),
    targeting_mode          = combo_box:new(1, get_hash(my_utility.plugin_label .. "_trample_targeting_mode")),
    mobility_only           = checkbox:new(false, get_hash(my_utility.plugin_label .. "_trample_mobility_only")),
    min_target_range        = slider_float:new(3, max_spell_range - 1, 3,
        get_hash(my_utility.plugin_label .. "_trample_min_target_range")),
}

local function menu()
    if menu_elements.tree_tab:push("Trample") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
            menu_elements.mobility_only:render("Only use for mobility", "")
            if menu_elements.mobility_only:get() then
                menu_elements.min_target_range:render("Minimum Target Range",
                    "\n     Must be lower than Max Targeting Range     \n\n", 1)
            end
        end

        menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;

local function logics(target)
    if not target then return false end;
    local menu_boolean = menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.trample.spell_id);

    if not is_logic_allowed then return false end;

    local mobility_only = menu_elements.mobility_only:get();
    if mobility_only then
        if not my_utility.is_in_range(target, max_spell_range) or my_utility.is_in_range(target, menu_elements.min_target_range:get()) then
            return false
        end
    end

    if cast_spell.target(target, spell_data.trample.spell_id, 0, false) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
        console.print("Cast Trample - Target: " ..
            my_utility.targeting_modes[menu_elements.targeting_mode:get() + 1] .. 
            ", Mobility Only: " .. tostring(mobility_only));
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
