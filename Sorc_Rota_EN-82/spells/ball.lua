local my_utility = require("my_utility/my_utility");

local menu_elements = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_ball_lightning")),
    
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "ball_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "ball_elite_only_bool")),
    crackling_energy_snapshot = checkbox:new(false, get_hash(my_utility.plugin_label .. "crackling_energy_snapshot_ball")),
}

local function menu()
    
    if menu_elements.tree_tab:push("Ball Lightning") then
       menu_elements.main_boolean:render("Enable Spell", "")
       
       if menu_elements.main_boolean:get() then
           menu_elements.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
           menu_elements.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
           menu_elements.crackling_energy_snapshot:render("Crackling Energy Snapshot", "Enable special casting logic optimized for Crackling Energy")
       end

       menu_elements.tree_tab:pop()
    end
end

local spell_id_ball = 514030
local next_time_allowed_cast = 0.0;
local function logics(target)

    local menu_boolean = menu_elements.main_boolean:get();
    local elite_only = menu_elements.elite_only:get();
    local crackling_energy_snapshot_enabled = menu_elements.crackling_energy_snapshot:get();
    
    -- Check if we're in Crackling Energy loop and need to end it after casting ball
    local is_in_crackling_energy_loop = crackling_energy_snapshot_enabled and my_utility.is_crackling_energy_loop_active();
    
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_ball);

    if not is_logic_allowed then
        return false;
    end;
    
    -- Elite only mode check
    if elite_only and target then
        local is_elite = target:is_elite() or target:is_champion() or target:is_boss()
        if not is_elite then
            return false;
        end
    end;

    local target_position = target:get_position();

    cast_spell.position(spell_id_ball, target_position, 0.02)
    local current_time = get_time_since_inject();
    next_time_allowed_cast = current_time + 0.1;
    
    -- If we were in Crackling Energy loop, end it after casting ball
    if is_in_crackling_energy_loop then
        my_utility.end_crackling_energy_loop();
        if debug_enabled then console.print("Sorcerer Plugin, Casted Ball - Crackling Energy Snapshot Complete"); end
    else
        if debug_enabled then console.print("Sorcerer Plugin, Casted Ball Lightning"); end
    end
    
    return true;

end

local function get_crackling_energy_snapshot_enabled()
    return menu_elements.crackling_energy_snapshot:get()
end

return 
{
    menu = menu,
    logics = logics,
    get_crackling_energy_snapshot_enabled = get_crackling_energy_snapshot_enabled
}