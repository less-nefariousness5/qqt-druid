local my_utility = require("my_utility/my_utility");
local spell_data = require("my_utility/spell_data");

local menu_elements_mist = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_blood_mist_base")),
    hp_threshold          = slider_float:new(0.1, 0.8, 0.30, get_hash(my_utility.plugin_label .. "blood_mist_hp_threshold")),
    emergency_only        = checkbox:new(false, get_hash(my_utility.plugin_label .. "blood_mist_emergency_only")),
    boss_priority         = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_mist_boss_priority"))
}

local function menu()
    if menu_elements_mist.tree_tab:push("Blood Mist") then
        menu_elements_mist.main_boolean:render("Enable Spell", "")

        if menu_elements_mist.main_boolean:get() then
            menu_elements_mist.hp_threshold:render("Health Threshold", "Cast when health drops below this percentage", 2)
            menu_elements_mist.emergency_only:render("Emergency Only", "Only use during critical health situations")
            menu_elements_mist.boss_priority:render("Boss Priority", "Always available during boss fights")
        end

        menu_elements_mist.tree_tab:pop()
    end 
end

local next_time_allowed_cast = 0.0;
local spell_id_blood_mist = 493422;
local function logics()
    -- Proper API validation sequence
    local menu_boolean = menu_elements_mist.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_blood_mist);

    if not is_logic_allowed then
        return false;
    end;
    
    local local_player = get_local_player();
    if not local_player then
        return false;
    end

    -- Check spell readiness with proper API
    if not local_player:is_spell_ready(spell_id_blood_mist) then
        return false;
    end

    -- Enhanced health checking
    local player_current_health = local_player:get_current_health();
    local player_max_health = local_player:get_max_health();
    
    if player_max_health <= 0 then
        return false;
    end

    local health_percentage = player_current_health / player_max_health;
    local hp_threshold = menu_elements_mist.hp_threshold:get();

    -- Emergency mode - more aggressive usage
    local emergency_only = menu_elements_mist.emergency_only:get()
    if emergency_only and health_percentage > 0.15 then -- Emergency = below 15% HP
        return false;
    elseif not emergency_only and health_percentage > hp_threshold then
        return false;
    end

    -- Boss priority - allow usage at higher HP during boss fights
    local boss_priority = menu_elements_mist.boss_priority:get()
    if boss_priority then
        -- Check for nearby bosses within reasonable range
        local player_position = local_player:get_position()
        if player_position then
            local enemies = actors_manager.get_enemy_npcs()
            for _, enemy in ipairs(enemies) do
                if enemy:is_boss() then
                    local boss_position = enemy:get_position()
                    local distance_sqr = boss_position:squared_dist_to_ignore_z(player_position)
                    if distance_sqr < (15.0 * 15.0) then -- Boss within 15 units
                        -- Allow Blood Mist at higher HP during boss fights
                        if health_percentage <= (hp_threshold + 0.2) then -- +20% threshold for bosses
                            break
                        end
                    end
                end
            end
        end
    end

    -- Human-like timing controls - survival spells should have longer delays
    local current_time = get_time_since_inject();
    local min_cast_interval = 0.25; -- Quarter second minimum for panic casts
    
    if current_time - next_time_allowed_cast < min_cast_interval then
        return false;
    end

    -- Safe cast with framework API
    local success = cast_spell.self(spell_id_blood_mist, 0.0);
    if success then
        next_time_allowed_cast = current_time + 2.5; -- Longer cooldown for survival
        console.print("[Blood Mist] Emergency cast at " .. math.floor(health_percentage * 100) .. "% HP");
        return true;
    end

    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}