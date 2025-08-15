local my_utility = require("my_utility/my_utility");
local movement_settings = require("movement_settings");

local menu_elements_sorc_base = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_flame_shield")),
    
    enable_flame_shield   = checkbox:new(true, get_hash(my_utility.plugin_label .. "enable_flame_shield_base")), -- Default enabled
    auto_cast_mode        = checkbox:new(true, get_hash(my_utility.plugin_label .. "auto_cast_manashield")), -- New: Auto cast mode
    exploration_cast      = checkbox:new(true, get_hash(my_utility.plugin_label .. "exploration_cast_manashield")), -- New: Cast during exploration
    hp_usage_shield       = slider_float:new(0.0, 1.0, 0.30, get_hash(my_utility.plugin_label .. "percent_in_which_flame_shield_will_cast")),
    cast_when_ice_armor_down = checkbox:new(true, get_hash(my_utility.plugin_label .. "cast_when_ice_armor_down")),
    belial_mode           = checkbox:new(false, get_hash(my_utility.plugin_label .. "flame_shield_belial_mode")),
    belial_delay_before_cast = slider_float:new(0.5, 3.0, 1.0, get_hash(my_utility.plugin_label .. "flame_shield_belial_delay_before_cast")),
}

local function menu()
    if menu_elements_sorc_base.tree_tab:push("Flame Shield") then
        menu_elements_sorc_base.main_boolean:render("Enable Spell", "")

        if menu_elements_sorc_base.main_boolean:get() then
            menu_elements_sorc_base.enable_flame_shield:render("Enable Flame Shield Casting", "Enable or disable active Flame Shield casting")
            
            if menu_elements_sorc_base.enable_flame_shield:get() then
                menu_elements_sorc_base.auto_cast_mode:render("Auto Cast Mode", "Automatically cast when skill is available, controlled by in-game skill cooldown")
                menu_elements_sorc_base.exploration_cast:render("Exploration Movement Cast", "Automatically cast Flame Shield in exploration mode like a movement skill")
                -- Update global movement settings
                movement_settings.update_manashield_exploration(menu_elements_sorc_base.exploration_cast:get())
                
                -- Only show conditional settings in non-auto mode
                if not menu_elements_sorc_base.auto_cast_mode:get() then
                    menu_elements_sorc_base.hp_usage_shield:render("Min Health Percent to Cast", "", 2)
                    menu_elements_sorc_base.cast_when_ice_armor_down:render("Cast When Ice Armor Down", "")
                end
            end
        end

        menu_elements_sorc_base.belial_mode:render("Belial Mode", "Override: Cast when enemy skill 2140755 is detected")
        if menu_elements_sorc_base.belial_mode:get() then
            menu_elements_sorc_base.belial_delay_before_cast:render("Delay Before Cast", "", 2)
        end
        menu_elements_sorc_base.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local spell_id_flame_shield = 167341

local function is_ice_armor_active()
    local local_player = get_local_player()
    local buff_name_check = "Sorcerer_IceArmor"

    if not local_player then return false end

    local buffs = local_player:get_buffs()
    if not buffs then return false end

    for _, buff in ipairs(buffs) do
        if buff:name() == buff_name_check then
            return true
        end
    end
    return false
end

local function is_flame_shield_active()
    local local_player = get_local_player()
    local buff_name_check = "Sorcerer_FlameShield"

    if not local_player then return false end

    local buffs = local_player:get_buffs()
    if not buffs then return false end

    for _, buff in ipairs(buffs) do
        if buff:name() == buff_name_check then
            return true
        end
    end
    return false
end

local belial_flame_shield_detect_time_2140755 = nil
local belial_flame_shield_detect_time_2147837 = nil
local function belial_logic()
    -- This function overrides normal logic if enabled. It checks all enemy NPCs for spell ID 2140755 and casts Flame Shield if seen.
    local menu_boolean = menu_elements_sorc_base.main_boolean:get();
    if not menu_boolean then belial_flame_shield_detect_time = nil; return false end
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id_flame_shield);
    if not is_logic_allowed then
        belial_flame_shield_detect_time = nil;
        -- Do not return here; allow other spells to be processed
    end

    -- Separate detection and timers for each spell id
    local detected_2140755 = false
    if actors_manager and actors_manager.get_enemy_npcs then
        local enemies = actors_manager.get_enemy_npcs()
        if enemies then
            for _, enemy in pairs(enemies) do
                if enemy and enemy.get_active_spell_id then
                    local active_spell_id = enemy:get_active_spell_id()
                    if active_spell_id == 2140755 then
                        detected_2140755 = true
                    end
                end
            end
        end
    end
    local now = get_time_since_inject()
    -- 2140755 logic (1s delay)
    if detected_2140755 then
        if not belial_flame_shield_detect_time_2140755 then
            belial_flame_shield_detect_time_2140755 = now
            return false
        elseif (now - belial_flame_shield_detect_time_2140755) >= (menu_elements_sorc_base.belial_delay_before_cast:get() or 1.0) then
            belial_flame_shield_detect_time_2140755 = nil
            if cast_spell.self(spell_id_flame_shield, 0.0) then
                local current_time = get_time_since_inject();
                next_time_allowed_cast = current_time + 0.1;
                if debug_enabled then console.print("Flame Shield: Cast due to Belial enemy spell 2140755! (1s delayed, non-blocking)") end
                -- Do not return true, allow other spells to continue
            end
        else
            return false
        end
    else
        belial_flame_shield_detect_time_2140755 = nil
    end
    return false
end

-- 探索模式释放功能
local function cast_during_exploration()
    -- 检查是否是自动游戏模式
    local is_auto_play = my_utility.is_auto_play_enabled();
    if not is_auto_play then
        return false;
    end

    -- 检查轨道移动器模式，3是探索模式
    local orb_mode = orbwalker.get_orb_mode();
    if orb_mode ~= 3 then
        return false;
    end

    local local_player = get_local_player();
    if not local_player then
        return false;
    end

    -- 检查技能是否就绪
    if not local_player:is_spell_ready(spell_id_flame_shield) then
        return false;
    end

    -- 在探索模式下自动释放魔兴
    if cast_spell.self(spell_id_flame_shield, 0.0) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.1;
        if debug_enabled then console.print("[Exploration Mode] Flame Shield auto cast") end
        return true;
    end

    return false;
end

local function logics(best_target, target_selector_data)
    -- 优先检查探索模式释放（需要同时启用自动释放模式和探索时移动释放）
    if menu_elements_sorc_base.auto_cast_mode:get() and menu_elements_sorc_base.exploration_cast:get() then
        if cast_during_exploration() then
            return false; -- 不阻断其他技能执行
        end
    end

    if menu_elements_sorc_base.belial_mode:get() then
        return belial_logic()
    end
    
    local menu_boolean = menu_elements_sorc_base.main_boolean:get();
    if not menu_boolean then
        return false;
    end;

    -- 检查是否启用魔兴施法
    if not menu_elements_sorc_base.enable_flame_shield:get() then
        return false;
    end;

    -- 基础技能可用性检查（包括冷却时间、法力值等）
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean,
                next_time_allowed_cast,
                spell_id_flame_shield);

    if not is_logic_allowed then
        return false;
    end;

    local local_player = get_local_player();
    if not local_player then
        return false;
    end;

    local should_cast_manashield = false;

    -- 自动释放模式：只要技能可用就释放
    if menu_elements_sorc_base.auto_cast_mode:get() then
        should_cast_manashield = true;
    else
        -- 条件释放模式：按原来的条件判断
        local player_current_health = local_player:get_current_health();
        local player_max_health = local_player:get_max_health();
        local health_percentage = player_current_health / player_max_health;
        local menu_min_percentage = menu_elements_sorc_base.hp_usage_shield:get();

        should_cast_manashield = health_percentage <= menu_min_percentage or menu_elements_sorc_base.hp_usage_shield:get() >= 1.0

        if menu_elements_sorc_base.cast_when_ice_armor_down:get() then
            should_cast_manashield = should_cast_manashield or not is_ice_armor_active()
        end
    end

    -- Check if Flame Shield is already active
    if is_flame_shield_active() then
        return false;
    end

    if should_cast_manashield then
        if cast_spell.self(spell_id_flame_shield, 0.0) then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + 0.1;
            if debug_enabled then console.print("[SKILL-BUFF] Flame Shield cast") end
            return true;
        end;
    end;

    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}