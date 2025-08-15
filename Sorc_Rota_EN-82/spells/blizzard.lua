--this does sometimes throw an error into the console but it does not impede the work of it. works just fine
--120.81 : ...cuments\diablo\scripts\base_sorcerer\spells/blizzard.lua:123: attempt to perform arithmetic on global 'current_time' (a nil value)
--stack traceback:
--...cuments\diablo\scripts\base_sorcerer\spells/blizzard.lua:123: in function 'logics'
--...dummydum\Documents\diablo\scripts\base_sorcerer\main.lua:200: in function <...dummydum\Documents\diablo\scripts\base_sorcerer\main.lua:90> 

local my_utility = require("my_utility/my_utility");

local menu_elements_blizzard = 
{
    blizz_sub                       = tree_node:new(1),
    blizz_boolean                   = checkbox:new(true, get_hash(my_utility.plugin_label .. "blizz_base_boolean")),
    
    enable_blizzard                 = checkbox:new(false, get_hash(my_utility.plugin_label .. "enable_blizzard_base")),
    priority_target                 = checkbox:new(false, get_hash(my_utility.plugin_label .. "blizzard_priority_target_bool")),
    elite_only                      = checkbox:new(false, get_hash(my_utility.plugin_label .. "blizzard_elite_only_bool")),
    blizz_mode                      = combo_box:new(0, get_hash(my_utility.plugin_label .. "blizz_cast_modes")),
    min_hits_slider                 = slider_int:new(0, 30, 5, get_hash(my_utility.plugin_label .. "_min_hits_slider_blizz_base")),

    allow_elite_single_target       = checkbox:new(true, get_hash(my_utility.plugin_label .. "allow_elite_single_target_bizz_base")),
}

local function menu()
    if menu_elements_blizzard.blizz_sub:push("Blizzard") then
        menu_elements_blizzard.blizz_boolean:render("Enable Spell", "")

        if menu_elements_blizzard.blizz_boolean:get() then
            menu_elements_blizzard.enable_blizzard:render("Enable Blizzard", "Enable or disable active Blizzard casting")
            menu_elements_blizzard.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_blizzard.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
            local dropbox_options = {"Combo & Clear", "Combo Only", "Clear Only"}
            menu_elements_blizzard.blizz_mode:render("Cast Mode", dropbox_options, "")
            menu_elements_blizzard.min_hits_slider:render("Min Hit Count", "")
            menu_elements_blizzard.allow_elite_single_target:render("Always Cast on Single Elite", "")
        end

        menu_elements_blizzard.blizz_sub:pop()
    end
end


local blizzard_buff_name = "Sorcerer_Blizzard";

local blizzard_buff_name_hashed_c = 291403;

local spell_id_blizzard = 291403;

local next_time_allowed_cast = 0.0;

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    local elite_only = menu_elements_blizzard.elite_only:get()
    
    -- Check for boss targets first (highest priority)
    if target_selector_data and target_selector_data.has_boss then
        best_target = target_selector_data.closest_boss
        target_type = "Boss"
        return best_target, target_type
    end
    
    -- Then check for champion targets
    if target_selector_data and target_selector_data.has_champion then
        best_target = target_selector_data.closest_champion
        target_type = "Champion"
        return best_target, target_type
    end
    
    -- Then check for elite targets
    if target_selector_data and target_selector_data.has_elite then
        best_target = target_selector_data.closest_elite
        target_type = "Elite"
        return best_target, target_type
    end
    
    -- Finally, use any available target (only if elite_only is false)
    if not elite_only and target_selector_data and target_selector_data.closest_unit then
        best_target = target_selector_data.closest_unit
        target_type = "Regular"
        return best_target, target_type
    end
    
    return nil, "none"
end

local function logics(best_target, target_selector_data)
    
    local menu_boolean = menu_elements_blizzard.blizz_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_blizzard);

    if not is_logic_allowed then
    return false;
    end;
    
    -- Default enable_blizzard to true if priority target is not active
    local enable_blizzard = menu_elements_blizzard.enable_blizzard:get() or 
                           (not menu_elements_blizzard.priority_target:get());
    
    -- Priority Targeting Mode for area skills like Blizzard
    if menu_elements_blizzard.priority_target:get() and target_selector_data then
        local priority_best_target, target_type = get_priority_target(target_selector_data)
        
        if priority_best_target then
            -- For area skills, cast at the priority target's position
            local priority_target_position = priority_best_target:get_position()
            
            if cast_spell.position(spell_id_blizzard, priority_target_position, 0.40) then
                if debug_enabled then console.print("[PRIORITY] Blizzard cast at " .. target_type .. " target: " .. priority_best_target:get_skin_name()) end
                local current_time = get_time_since_inject()
                next_time_allowed_cast = current_time + 0.3
                return true
            end
        else
            if debug_enabled then console.print("[PRIORITY] No valid priority target found for Blizzard") end
        end
        
        return false
    end

    local local_player = get_local_player();
    local current_resource = local_player:get_primary_resource_current();
    local max_resource = local_player:get_primary_resource_max();
    local resource_percentage = current_resource / max_resource; 
    local is_low_resources = resource_percentage < 0.2;

    if is_low_resources then
        return false;
    end;

    local circle_radius = 3.0; 
    local player_position = get_player_position();
    local area_data = target_selector.get_most_hits_target_circular_area_heavy(player_position, 9.0, circle_radius)
    local best_target = area_data.main_target;
    
    if not best_target then
        return;
    end

    local best_target_position = best_target:get_position();
    local best_cast_data = my_utility.get_best_point(best_target_position, circle_radius, area_data.victim_list);

    local best_hit_list = best_cast_data.victim_list

    local is_single_target_allowed = false;

    if menu_elements_blizzard.allow_elite_single_target:get() then
        for _, unit in ipairs(best_hit_list) do
            local current_health_percentage = unit:get_current_health() / unit:get_max_health() * 100

            if unit:is_boss() and current_health_percentage > 22 then
                is_single_target_allowed = true
                break 
            end
        
            if unit:is_elite() and current_health_percentage > 45 then
                is_single_target_allowed = true
                break 
            end
        end
    end

    local best_cast_hits = best_cast_data.hits;
    if best_cast_hits < menu_elements_blizzard.min_hits_slider:get() and not is_single_target_allowed then
   
        return false
    end

    local blizzard_count = 0

    for _, unit in ipairs(best_hit_list) do
        
        local buffs = unit:get_buffs()

        for _, buff in ipairs(buffs) do
            if buff.name_hash == blizzard_buff_name_hashed_c then
                blizzard_count = blizzard_count + 1
                break 
            end
        end
    end

    local percentage_with_buff = (blizzard_count / best_cast_hits);

   -- local is_allowed = percentage_with_buff < 0.25;

   -- if not is_allowed then                                --dont need this personally for blizzard build as that is your damage and you want to spam them as much as you can
    --    return false;
    --end


    local best_cast_position = best_cast_data.point;
    if cast_spell.position(spell_id_blizzard, best_cast_position, 0.40) then
        if debug_enabled then console.print("Sorcerer Plugin, Casted Blizzard, Target " .. best_target:get_skin_name() .. " Hits: " .. best_cast_hits); end
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.3; -- fixed an oopsie that chaser did where he wrote time instead of current_time
        return true;
    end
    
    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}