local my_utility = require("my_utility/my_utility");
local movement_settings = require("movement_settings");

local menu_elements_evade = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_evade")),
    
    enable_evade          = checkbox:new(false, get_hash(my_utility.plugin_label .. "enable_evade_base")), -- 默认关闭
    exploration_movement  = checkbox:new(true, get_hash(my_utility.plugin_label .. "evade_exploration_movement")), -- 新增：探索时移动
    emergency_evade       = checkbox:new(true, get_hash(my_utility.plugin_label .. "emergency_evade")), -- 紧急闪避
    hp_threshold          = slider_float:new(0.1, 0.9, 0.5, get_hash(my_utility.plugin_label .. "evade_hp_threshold")), -- 生命值阈值
}

local function menu()
    if menu_elements_evade.tree_tab:push("Evade") then
        menu_elements_evade.main_boolean:render("Enable Spell", "")

        if menu_elements_evade.main_boolean:get() then
            menu_elements_evade.enable_evade:render("Enable Evade", "Enable or disable evade spell")
            
            if menu_elements_evade.enable_evade:get() then
                menu_elements_evade.exploration_movement:render("Exploration Movement", "Use evade as movement spell in exploration mode")
                -- 更新全局移动设置
                movement_settings.update_evade_exploration(menu_elements_evade.exploration_movement:get())
                
                menu_elements_evade.emergency_evade:render("Emergency Evade", "Automatically evade when health is low")
                
                if menu_elements_evade.emergency_evade:get() then
                    menu_elements_evade.hp_threshold:render("Health Threshold", "Trigger emergency evade when health falls below this percentage", 2)
                end
            end
        end

        menu_elements_evade.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local spell_id_evade = 337031; -- General Evade技能ID

-- 探索模式移动功能
local function cast_for_exploration_movement()
    -- 检查是否启用探索时移动
    if not menu_elements_evade.exploration_movement:get() then
        return false;
    end

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
    if not local_player:is_spell_ready(spell_id_evade) then
        return false;
    end

    -- 获取玩家当前位置
    local player_position = get_player_position();
    
    -- 生成一个前方的移动目标位置（距离5码，闪避距离比传送短）
    local movement_distance = 5.0;
    local movement_direction = vec3:new(1, 0, 0); -- 默认方向
    
    local target_position = player_position + movement_direction * movement_distance;

    -- 执行闪避
    if cast_spell.position(spell_id_evade, target_position, 0.2) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 0.3;
        if debug_enabled then
            console.print("[Exploration Mode] Evade movement cast");
        end
        return true;
    end

    return false;
end

-- 紧急闪避功能
local function emergency_evade_logic()
    if not menu_elements_evade.emergency_evade:get() then
        return false;
    end

    local local_player = get_local_player();
    if not local_player then
        return false;
    end

    -- 检查生命值
    local current_health = local_player:get_current_health();
    local max_health = local_player:get_max_health();
    local health_percentage = current_health / max_health;
    local threshold = menu_elements_evade.hp_threshold:get();

    if health_percentage <= threshold then
        -- 检查技能是否就绪
        if not local_player:is_spell_ready(spell_id_evade) then
            return false;
        end

        local player_position = get_player_position();
        local safe_direction = vec3:new(-1, 0, 0); -- 向后闪避
        local safe_distance = 8.0;
        local safe_position = player_position:get_extended(safe_direction, safe_distance);

        if cast_spell.position(spell_id_evade, safe_position, 0.2) then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + 0.3;
            if debug_enabled then
                console.print("[Emergency Evade] Health too low, executing evade");
            end
            return true;
        end
    end

    return false;
end

local function logics(best_target, target_selector_data)
    local menu_boolean = menu_elements_evade.main_boolean:get();
    if not menu_boolean then
        return false;
    end;

    -- 检查是否启用闪避
    if not menu_elements_evade.enable_evade:get() then
        return false;
    end;

    -- 基础技能可用性检查
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean,
                next_time_allowed_cast,
                spell_id_evade);

    if not is_logic_allowed then
        return false;
    end;

    -- 优先检查紧急闪避
    if emergency_evade_logic() then
        return false; -- 不阻断其他技能执行
    end

    -- 检查探索模式移动
    if cast_for_exploration_movement() then
        return false; -- 不阻断其他技能执行
    end

    return false;
end

return 
{
    menu = menu,
    logics = logics,   
}