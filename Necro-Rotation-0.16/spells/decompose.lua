local my_utility = require("my_utility/my_utility");
local spell_data = require("my_utility/spell_data");

local menu_elements_decompose = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_decompose_base")),
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "decompose_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "decompose_elite_only_bool")),
    max_range             = slider_float:new(8.0, 15.0, 12.0, get_hash(my_utility.plugin_label .. "decompose_max_range")),
    shadowblight_mode     = checkbox:new(true, get_hash(my_utility.plugin_label .. "decompose_shadowblight_mode"))
}

local function menu()
    if menu_elements_decompose.tree_tab:push("Decompose") then
        menu_elements_decompose.main_boolean:render("Enable Spell", "")
        
        if menu_elements_decompose.main_boolean:get() then
            menu_elements_decompose.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_decompose.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
            menu_elements_decompose.max_range:render("Max Range", "Maximum range to cast Decompose", 1)
            menu_elements_decompose.shadowblight_mode:render("Shadowblight Mode", "Optimized for shadow damage stacking")
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

    -- Elite filtering
    local elite_only = menu_elements_decompose.elite_only:get()
    if elite_only then
        if not target:is_boss() and not target:is_elite() and not target:is_champion() then
            return false;
        end
    end

    -- Shadowblight mode optimization - check for existing shadow effects
    local shadowblight_mode = menu_elements_decompose.shadowblight_mode:get()
    if shadowblight_mode then
        -- Prioritize targets without shadow effects for better stacking
        local target_buffs = target:get_buffs()
        local has_shadow_effects = false
        
        if target_buffs then
            for _, buff in ipairs(target_buffs) do
                local buff_name = buff:name()
                if buff_name and (string.find(buff_name, "Shadow") or string.find(buff_name, "Blight")) then
                    has_shadow_effects = true
                    break
                end
            end
        end
        
        -- Prefer fresh targets for better shadow stacking efficiency
        if has_shadow_effects and entity_list and #entity_list > 1 then
            return false; -- Let other spells handle targets with existing effects
        end
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