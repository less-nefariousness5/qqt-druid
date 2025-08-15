local my_utility = require("my_utility/my_utility");

local menu_elements_inferno = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_inferno_base")),
    
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "inferno_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "inferno_elite_only_bool")),
    crackling_energy_snapshot = checkbox:new(false, get_hash(my_utility.plugin_label .. "crackling_energy_snapshot_inferno")),
    
    -- Minimum Targets feature
    minimum_targets_enabled = checkbox:new(false, get_hash(my_utility.plugin_label .. "inferno_minimum_targets_enabled")),
    minimum_targets_count = slider_int:new(1, 15, 3, get_hash(my_utility.plugin_label .. "inferno_minimum_targets_count")),
    scan_radius = slider_int:new(1, 20, 12, get_hash(my_utility.plugin_label .. "inferno_scan_radius")),
}

local function menu()
    
    if menu_elements_inferno.tree_tab:push("Inferno") then
        menu_elements_inferno.main_boolean:render("Enable Spell", "")
        
        if menu_elements_inferno.main_boolean:get() then
            menu_elements_inferno.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_inferno.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
            menu_elements_inferno.crackling_energy_snapshot:render("Crackling Energy Snapshot", "Enable crackling energy optimized special casting logic")
            
            -- Minimum Targets options
            menu_elements_inferno.minimum_targets_enabled:render("Enable Minimum Targets", "Only cast when minimum number of targets are present")
            if menu_elements_inferno.minimum_targets_enabled:get() then
                menu_elements_inferno.minimum_targets_count:render("Minimum Targets Count", "Minimum number of targets required to cast (1-15)")
                menu_elements_inferno.scan_radius:render("Scan Radius", "Radius to scan for targets in yards (1-20)")
            end
        end

        menu_elements_inferno.tree_tab:pop();
    end
end

local spell_id_inferno = 294198
local next_time_allowed_cast = 0.0;
local function logics(target)

    local menu_boolean = menu_elements_inferno.main_boolean:get();
    local elite_only = menu_elements_inferno.elite_only:get();
    local crackling_energy_snapshot_enabled = menu_elements_inferno.crackling_energy_snapshot:get();
    local minimum_targets_enabled = menu_elements_inferno.minimum_targets_enabled:get();
    local minimum_targets_count = menu_elements_inferno.minimum_targets_count:get();
    local scan_radius = menu_elements_inferno.scan_radius:get();
    
    -- Check if we're in Crackling Energy loop and need to end it after casting inferno
    local is_in_crackling_energy_loop = crackling_energy_snapshot_enabled and my_utility.is_crackling_energy_loop_active();
    
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_inferno);

    if not is_logic_allowed then
        return false;
    end;
    
    -- Minimum targets check
    if minimum_targets_enabled then
        local player_position = get_player_position();
        local enemies = actors_manager.get_enemy_npcs();
        local target_count = 0;
        -- Use user-defined scan radius (converted from int to float)
        
        for _, enemy in ipairs(enemies) do
            if enemy and enemy:is_enemy() then
                local enemy_position = enemy:get_position();
                local distance_sqr = enemy_position:squared_dist_to_ignore_z(player_position);
                
                if distance_sqr <= (scan_radius * scan_radius) then
                    -- Apply elite_only filter if enabled
                    if elite_only then
                        if enemy:is_elite() or enemy:is_champion() or enemy:is_boss() then
                            target_count = target_count + 1;
                        end
                    else
                        target_count = target_count + 1;
                    end
                end
            end
        end
        
        if target_count < minimum_targets_count then
            return false;
        end
    end
    
    -- Elite only mode check (for single target validation)
    if elite_only and target then
        local is_elite = target:is_elite() or target:is_champion() or target:is_boss()
        if not is_elite then
            return false;
        end
    end;

    local target_position = target:get_position();

    cast_spell.position(spell_id_inferno, target_position, 0.02)
    local current_time = get_time_since_inject();
    next_time_allowed_cast = current_time + 0.1;
    
    -- If we were in Crackling Energy loop, end it after casting inferno
    if is_in_crackling_energy_loop then
        my_utility.end_crackling_energy_loop();
        console.print("Sorcerer Plugin, Casted Inferno - Crackling Energy Snapshot Complete");
    else
        console.print("Sorcerer Plugin, Casted Inferno");
    end
    
    return true;

end

local function get_crackling_energy_snapshot_enabled()
    return menu_elements_inferno.crackling_energy_snapshot:get()
end

return 
{
    menu = menu,
    logics = logics,
    get_crackling_energy_snapshot_enabled = get_crackling_energy_snapshot_enabled
}