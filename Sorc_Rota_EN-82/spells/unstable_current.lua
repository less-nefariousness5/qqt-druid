local my_utility = require("my_utility/my_utility")

local menu_elements_unstable_base = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_unstable_currents_base")),
    
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "unstable_current_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "unstable_current_elite_only_bool")),
    min_max_targets       = slider_int:new(0, 30, 5, get_hash(my_utility.plugin_label .. "min_max_number_of_targets_for_cast_base"))
}

local function menu()
    
    if menu_elements_unstable_base.tree_tab:push("Unstable Currents") then
        menu_elements_unstable_base.main_boolean:render("Enable Spell", "")

        if menu_elements_unstable_base.main_boolean:get() then
            menu_elements_unstable_base.priority_target:render("Priority Target", "Cast only when high-value targets are detected")
            menu_elements_unstable_base.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
            menu_elements_unstable_base.min_max_targets:render("Min Nearby Enemies", "Number of targets required to cast this spell")
        end

        menu_elements_unstable_base.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local spell_id_unstable_current = 517417
local function logics()

    local menu_boolean = menu_elements_unstable_base.main_boolean:get();
    local elite_only = menu_elements_unstable_base.elite_only:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_unstable_current);

    if not is_logic_allowed then
    return false;
    end;
    
    local player_pos = get_player_position()
    local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 9.0, 9.0, false)
    local units = area_data.n_hits

    if units < menu_elements_unstable_base.min_max_targets:get() then
        return false;
    end;
    
    -- Elite only mode check: ensure there are elite monsters around
    if elite_only then
        local enemy_list = target_selector.get_near_target_list(player_pos, 9.0)
        local has_elite = false
        for _, enemy in pairs(enemy_list) do
            if enemy:is_elite() or enemy:is_champion() or enemy:is_boss() then
                has_elite = true
                break
            end
        end
        if not has_elite then
            return false;
        end
    end;

    if cast_spell.self(spell_id_unstable_current, 0.0) then
        
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.2;
        return true;
    end;


    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}