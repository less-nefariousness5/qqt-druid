local local_player = get_local_player()
if local_player == nil then
    return
end

local character_id = local_player:get_character_class_id();
local is_necro = character_id == 6;
if not is_necro then
 return
end;

local menu = require("menu");
local spell_data = require("spell_data");

local spells =
{
    blood_mist                  = require("blood_mist"),
    bone_spear                  = require("bone_spear"),
    bone_splinters              = require("bone_splinters"),
    corpse_explosion            = require("corpse_explosion"),
    corpse_tendrils             = require("corpse_tendrils"),
    decrepify                   = require("decrepify"),
    hemorrhage                  = require("hemorrhage"),
    reap                        = require("reap"),
    blood_lance                 = require("blood_lance"),
    blood_surge                 = require("blood_surge"),
    blight                      = require("blight"),
    sever                       = require("sever"),
    bone_prison                 = require("bone_prison"),
    iron_maiden                 = require("iron_maiden"),
    bone_spirit                 = require("bone_spirit"),
    blood_wave                  = require("blood_wave"),
    army_of_the_dead            = require("army_of_the_dead"),
    bone_storm                  = require("bone_storm"),
    raise_skeleton              = require("raise_skeleton"),
    golem_control               = require("golem_control"),
    soulrift                    = require("soulrift"),
    decompose			= require("decompose"),
}

-- Define the order of spells for menu rendering
local spell_order = {
    "blood_mist", "golem_control", "raise_skeleton", "soulrift", "decrepify",
    "blood_wave", "army_of_the_dead", "corpse_tendrils", "bone_spear", "corpse_explosion",
    "decompose", "bone_splinters", "reap", "blood_lance", "blood_surge", "blight", "sever",
    "bone_prison", "iron_maiden", "bone_spirit", "bone_storm", "hemorrhage"
}

-- Centralized build configurations
local builds = {
    [0] = { -- Bloodwave (DoT)
        name = "Bloodwave (DoT)",
        rotation = { "corpse_tendrils", "blood_wave", "blight", "blood_surge", "corpse_explosion" }
    },
    [1] = { -- Ring of Power (Mages)
        name = "Ring of Power (Mages)",
        rotation = { "army_of_the_dead", "corpse_tendrils", "bone_spear", "corpse_explosion" }
    },
    [2] = { -- Shadowblight
        name = "Shadowblight",
        rotation = { "blight", "decompose", "sever", "corpse_tendrils", "bone_spear" }
    }
}

on_render_menu (function ()

    if not menu.main_tree:push("Necromancer: Season 9 v2.0") then
        return;
    end;

    menu.main_boolean:render("Enable Plugin", "");

    if menu.main_boolean:get() == false then
        menu.main_tree:pop();
        return;
    end;

    -- Build Selection Menu
    if menu.build_config_tree:push("Build Configuration") then
        local build_options = {"Bloodwave (DoT)", "Ring of Power (Mages)", "Shadowblight"}
        menu.build_selector:render("Select Build", build_options, "Choose your necromancer build")

        local selected_build = menu.build_selector:get()

        -- Global build configuration (applies to all builds)
        if menu.bloodwave_build_tree:push("Build Settings") then
            menu.build_aggressive_mode:render("Aggressive Mode", "Cast spells more frequently with lower thresholds")
            menu.build_elite_priority:render("Elite Priority", "Always prioritize elite/boss/champion targets")
            menu.build_mana_conservation:render("Mana Conservation", "Minimum mana percentage to maintain (0.15-0.50)", 2)


            menu.bloodwave_build_tree:pop()
        end

        menu.build_config_tree:pop()
    end

    -- Weighted Targeting System menu (imported from Sorcerer)
    if menu.weighted_targeting_tree:push("Weighted Targeting System") then
        menu.weighted_targeting_enabled:render("Enable Weighted Targeting", "Enable weighted system for prioritizing targets")

        if menu.weighted_targeting_enabled:get() then
            menu.scan_radius:render("Scan Radius", "Radius around character to scan for targets (1-30)", 1)
            menu.scan_refresh_rate:render("Refresh Rate", "Target scan refresh rate in seconds (0.1-1.0)", 1)
            menu.min_targets:render("Minimum Targets", "Minimum number of targets required (1-10)")
            menu.comparison_radius:render("Comparison Radius", "Radius to check nearby targets (0.1-6.0)", 1)

            menu.custom_weights_enabled:render("Custom Enemy Weights", "Enable to customize weights for different enemy types")

            if menu.custom_weights_enabled:get() then
                menu.boss_weight:render("Boss Weight", "Weight assigned to boss targets (1-100)")
                menu.elite_weight:render("Elite Weight", "Weight assigned to elite targets (1-100)")
                menu.champion_weight:render("Champion Weight", "Weight assigned to champion targets (1-100)")
                menu.any_weight:render("Normal Target Weight", "Weight assigned to normal targets (0-100)")
            end
        end

        menu.weighted_targeting_tree:pop()
    end;

    -- Get equipped spells
    local equipped_spells = get_equipped_spell_ids()
    table.insert(equipped_spells, spell_data.evade.spell_id) -- add evade to the list

    -- Create a lookup table for equipped spells
    local equipped_lookup = {}
    for _, spell_id in ipairs(equipped_spells) do
        equipped_lookup[spell_id] = true
    end

    -- Active spells menu (spells that are currently equipped)
    if menu.active_spells_tree:push("Active Spells") then
        -- Iterate through spell_order to maintain the defined order
        for _, spell_name in ipairs(spell_order) do
            -- Check if the spell exists in spells table, spell_data, and if it's equipped
            if spells[spell_name] and spell_data[spell_name] and spell_data[spell_name].spell_id and equipped_lookup[spell_data[spell_name].spell_id] then
                spells[spell_name].menu()
            end
        end
        menu.active_spells_tree:pop()
    end

    -- Inactive spells menu (spells that are not currently equipped)
    if menu.inactive_spells_tree:push("Inactive Spells") then
        -- Iterate through spell_order to maintain the defined order
        for _, spell_name in ipairs(spell_order) do
            -- Check if the spell exists in spells table, spell_data, and if it's not equipped
            if spells[spell_name] and spell_data[spell_name] and spell_data[spell_name].spell_id and not equipped_lookup[spell_data[spell_name].spell_id] then
                spells[spell_name].menu()
            end
        end
        menu.inactive_spells_tree:pop()
    end;

    menu.main_tree:pop();

end
)

local can_move = 0.0;
local cast_end_time = 0.0;

local blood_mist_buff_name = "Necromancer_BloodMist";
local blood_mist_buff_name_hash = blood_mist_buff_name;
local blood_mist_buff_name_hash_c = 493422;

local mount_buff_name = "Generic_SetCannotBeAddedToAITargetList";
local mount_buff_name_hash = mount_buff_name;
local mount_buff_name_hash_c = 1923;

local my_utility = require("my_utility");
local my_target_selector = require("my_target_selector");

local is_blood_mist = false
on_update(function ()

    local local_player = get_local_player();
    if not local_player then
        return;
    end

    if menu.main_boolean:get() == false then
        -- if plugin is disabled dont do any logic
        return;
    end;

    local current_time = get_time_since_inject()
    if current_time < cast_end_time then
        return;
    end;

    is_blood_mist = false;
    local local_player_buffs = local_player:get_buffs();
    for _, buff in ipairs(local_player_buffs) do
        --   console.print("buff name ", buff:name());
        --   console.print("buff hash ", buff.name_hash);
          if buff.name_hash == blood_mist_buff_name_hash_c then
              is_blood_mist = true;
              break;
          end
    end

    if not my_utility.is_action_allowed() then
        return;
    end

    -- Get selected build for rotation logic
    local selected_build_index = menu.build_selector:get()
    local selected_build = builds[selected_build_index]

    -- Priority 1: Essential survival/buffs (all builds)
    if spells.blood_mist.logics()then
        cast_end_time = current_time + 0.5;
        return;
    end;

    -- Build-specific minion management
    if selected_build_index == 1 and spells.golem_control and spells.golem_control.logics()then -- Ring of Power
        cast_end_time = current_time + 0.5;
        return;
    end;

    if selected_build_index == 1 and spells.raise_skeleton and spells.raise_skeleton.logics()then -- Ring of Power mages
        cast_end_time = current_time + 0.5;
        return;
    end;

    local screen_range = 16.0;
    local player_position = get_player_position();

    local collision_table = { true, 2.0 };
    local floor_table = { true, 5.0 };
    local angle_table = { false, 90.0 };

    local entity_list = my_target_selector.get_target_list(
        player_position,
        screen_range,
        collision_table,
        floor_table,
        angle_table);

    local target_selector_data = my_target_selector.get_target_selector_data(
        player_position,
        entity_list);

    if not target_selector_data.is_valid then
        return;
    end

    local is_auto_play_active = auto_play.is_active();
    local max_range = 10.0;
    if is_auto_play_active then
        max_range = 12.0;
    end

    local best_target = target_selector_data.closest_unit;

    if target_selector_data.has_elite then
        local unit = target_selector_data.closest_elite;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end
    end

    if target_selector_data.has_boss then
        local unit = target_selector_data.closest_boss;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end
    end

    if target_selector_data.has_champion then
        local unit = target_selector_data.closest_champion;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end
    end

    if not best_target then
        return;
    end

    local best_target_position = best_target:get_position();
    local distance_sqr = best_target_position:squared_dist_to_ignore_z(player_position);

    if distance_sqr > (max_range * max_range) then
        best_target = target_selector_data.closest_unit;
        local closer_pos = best_target:get_position();
        local distance_sqr_2 = closer_pos:squared_dist_to_ignore_z(player_position);
        if distance_sqr_2 > (max_range * max_range) then
            return;
        end
    end

    -- Build-Specific Rotation Logic
    if selected_build then
        for _, spell_name in ipairs(selected_build.rotation) do
            local spell = spells[spell_name]
            if spell and spell.logics(best_target, entity_list) then
                cast_end_time = current_time + 0.5
                return
            end
        end
    end

    -- Universal utility spells (all builds)
    if spells.soulrift and spells.soulrift.logics() then
        cast_end_time = current_time + 0.5;
        return;
    end;

    if spells.decrepify.logics()then
        cast_end_time = current_time + 0.50;
        return;
    end;

    if spells.bone_prison.logics(best_target)then
        cast_end_time = current_time + 0.4;
        return;
    end;

    if spells.iron_maiden and spells.iron_maiden.logics()then
        cast_end_time = current_time + 0.4;
        return;
    end;

    -- Fallback attacks (all builds)
    if spells.bone_splinters.logics(best_target)then
        cast_end_time = current_time + 0.5;
        return;
    end;

    if spells.hemorrhage.logics(best_target)then
        cast_end_time = current_time + 0.5;
        return;
    end;

    -- auto play engage far away monsters
    local move_timer = get_time_since_inject()
    if move_timer < can_move then
        return;
    end;

    local is_auto_play = my_utility.is_auto_play_enabled();
    if is_auto_play then
        local player_position = local_player:get_position();
        local is_dangerous_evade_position = evade.is_dangerous_position(player_position);
        if not is_dangerous_evade_position then
            local closer_target = target_selector.get_target_closer(player_position, 15.0);
            if closer_target then
                if is_blood_mist then
                    local closer_target_position = closer_target:get_position();
                    local move_pos = closer_target_position:get_extended(player_position, -5.0);
                    if pathfinder.move_to_cpathfinder(move_pos) then
                        cast_end_time = current_time + 0.40;
                        can_move = move_timer + 1.5;
                        --console.print("auto play move_to_cpathfinder - 111")
                    end
                else
                    local closer_target_position = closer_target:get_position();
                    local move_pos = closer_target_position:get_extended(player_position, 4.0);
                    if pathfinder.move_to_cpathfinder(move_pos) then
                        can_move = move_timer + 1.5;
                        --console.print("auto play move_to_cpathfinder - 222")
                    end
                end

            end
        end
    end

end);

local draw_player_circle = false;
local draw_enemy_circles = false;

on_render(function ()

    if menu.main_boolean:get() == false then
        return;
    end;

    local local_player = get_local_player();
    if not local_player then
        return;
    end

    local player_position = local_player:get_position();
    local player_screen_position = graphics.w2s(player_position);
    if player_screen_position:is_zero() then
        return;
    end

    if draw_player_circle then
        graphics.circle_3d(player_position, 8, color_white(85), 3.5, 144)
        graphics.circle_3d(player_position, 6, color_white(85), 2.5, 144)
    end

    if draw_enemy_circles then
        local enemies = actors_manager.get_enemy_npcs()

        for i,obj in ipairs(enemies) do
        local position = obj:get_position();
        local distance_sqr = position:squared_dist_to_ignore_z(player_position);
        local is_close = distance_sqr < (8.0 * 8.0);
            -- if is_close then
                graphics.circle_3d(position, 1, color_white(100));

                local future_position = prediction.get_future_unit_position(obj, 0.4);
                graphics.circle_3d(future_position, 0.5, color_yellow(100));
            -- end;
        end;
    end

    -- glow target -- quick pasted code cba about this game

    local screen_range = 16.0;
    local player_position = get_player_position();

    local collision_table = { false, 2.0 };
    local floor_table = { true, 5.0 };
    local angle_table = { false, 90.0 };

    local entity_list = my_target_selector.get_target_list(
        player_position,
        screen_range,
        collision_table,
        floor_table,
        angle_table);

    local target_selector_data = my_target_selector.get_target_selector_data(
        player_position,
        entity_list);

    if not target_selector_data.is_valid then
        return;
    end

    local is_auto_play_active = auto_play.is_active();
    local max_range = 10.0;
    if is_auto_play_active then
        max_range = 12.0;
    end

    local best_target = target_selector_data.closest_unit;

    if target_selector_data.has_elite then
        local unit = target_selector_data.closest_elite;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end
    end

    if target_selector_data.has_boss then
        local unit = target_selector_data.closest_boss;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end
    end

    if target_selector_data.has_champion then
        local unit = target_selector_data.closest_champion;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end
    end

    if not best_target then
        return;
    end

    if best_target and best_target:is_enemy()  then
        local glow_target_position = best_target:get_position();
        local glow_target_position_2d = graphics.w2s(glow_target_position);
        graphics.line(glow_target_position_2d, player_screen_position, color_red(180), 2.5)
        graphics.circle_3d(glow_target_position, 0.80, color_red(200), 2.0);
    end

end);

console.print("Lua Plugin - Necromancer Season 9 - Version 2.0 (Bloodwave/Ring of Power/Shadowblight)");
