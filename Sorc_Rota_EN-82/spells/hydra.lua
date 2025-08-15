local my_utility = require("my_utility/my_utility");

local menu_elements_hydra = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_hydra")),
    
    priority_target       = checkbox:new(false, get_hash(my_utility.plugin_label .. "hydra_priority_target_bool")),
    elite_only            = checkbox:new(false, get_hash(my_utility.plugin_label .. "hydra_elite_only_bool")),
    max_mana_only         = checkbox:new(false, get_hash(my_utility.plugin_label .. "max_mana_only_hydra")),
    min_mana_enabled      = checkbox:new(false, get_hash(my_utility.plugin_label .. "min_mana_enabled_hydra")),
    min_mana_threshold    = slider_int:new(0, 400, 100, get_hash(my_utility.plugin_label .. "min_mana_threshold_hydra")),
    auto_cast_enabled     = checkbox:new(false, get_hash(my_utility.plugin_label .. "hydra_auto_cast_enabled")),
    cast_delay_ms         = slider_int:new(0, 5000, 1000, get_hash(my_utility.plugin_label .. "hydra_cast_delay_ms")),
}

local function menu()
    
    if menu_elements_hydra.tree_tab:push("Hydra")then
        menu_elements_hydra.main_boolean:render("Enable Spell", "")
        
        if menu_elements_hydra.main_boolean:get() then
            menu_elements_hydra.priority_target:render("Priority Target", "Target priority: Boss > Champion > Elite > Normal")
            menu_elements_hydra.elite_only:render("Elite Only", "Only attack elite, champion and boss monsters")
        end
        
        menu_elements_hydra.max_mana_only:render("Cast Only at Full Mana", "Only cast Hydra at 100 percent mana")
        
        menu_elements_hydra.min_mana_enabled:render("Enable Minimum Mana", "Only cast Hydra when current mana is above threshold")
        if menu_elements_hydra.min_mana_enabled:get() then
            menu_elements_hydra.min_mana_threshold:render("Minimum Mana", "Cast Hydra only when current mana is above this value (0-400)")
        end
        
        menu_elements_hydra.auto_cast_enabled:render("Enable Auto Cast", "Automatically cast Hydra with set delay when enemies are present")
        if menu_elements_hydra.auto_cast_enabled:get() then
            menu_elements_hydra.cast_delay_ms:render("Cast Delay (ms)", "Set Hydra casting interval, range 0-5000 milliseconds")
        end
 
        menu_elements_hydra.tree_tab:pop()
    end
end

local spell_id_hydra = 146743
local next_time_allowed_cast = 0.0;
local last_auto_cast_time = 0.0;
local function logics(target)
    
    local menu_boolean = menu_elements_hydra.main_boolean:get();
    local elite_only = menu_elements_hydra.elite_only:get();
    local max_mana_only = menu_elements_hydra.max_mana_only:get();
    local min_mana_enabled = menu_elements_hydra.min_mana_enabled:get();
    local min_mana_threshold = menu_elements_hydra.min_mana_threshold:get();
    local auto_cast_enabled = menu_elements_hydra.auto_cast_enabled:get();
    local cast_delay_ms = menu_elements_hydra.cast_delay_ms:get();
    
    -- 只检查技能开关
    if not menu_boolean then
        return false;
    end;
    
    -- 仅精英模式检查
    if elite_only and target then
        local is_elite = target:is_elite() or target:is_champion() or target:is_boss()
        if not is_elite then
            return false;
        end
    end;
    
    -- 自动施放延迟检查
    if auto_cast_enabled then
        local current_time = get_time_since_inject();
        local delay_seconds = cast_delay_ms / 1000.0;
        
        if current_time - last_auto_cast_time < delay_seconds then
            return false;
        end
    end;
    
    -- 检查技能是否就绪
    local local_player = get_local_player();
    if not local_player or not local_player:is_spell_ready(spell_id_hydra) then
        return false;
    end;
    
    -- 检查法力值是否足够
    if not utility.is_spell_affordable(spell_id_hydra) then
        return false;
    end;
    
    -- 检查Orbwalker模式
    local current_orb_mode = orbwalker.get_orb_mode();
    if current_orb_mode == orb_mode.none then
        return false;
    end;
    
    local is_current_orb_mode_pvp = current_orb_mode == orb_mode.pvp;
    local is_current_orb_mode_clear = current_orb_mode == orb_mode.clear;
    
    if not is_current_orb_mode_pvp and not is_current_orb_mode_clear then
        return false;
    end;
    
    -- 检查角色状态（排除危险位置检查）
    if not my_utility.is_action_allowed() then
        return false;
    end;

    -- 当启用"仅在满法力时施放"时检查玩家法力值是否为100%
    if max_mana_only then
        local local_player = get_local_player();
        if not local_player then
            return false;
        end
        
        local current_mana = local_player:get_primary_resource_current();
        local max_mana = local_player:get_primary_resource_max();
        
        -- 仅在法力值为100%时施放
        if current_mana < max_mana then
            return false;
        end
    end;
    
    -- 当启用"最小mana"时检查玩家当前法力值是否高于设定值
    if min_mana_enabled then
        local local_player = get_local_player();
        if not local_player then
            return false;
        end
        
        local current_mana = local_player:get_primary_resource_current();
        
        -- 仅在当前法力值高于设定阈值时施放
        if current_mana < min_mana_threshold then
            return false;
        end
    end;

    local target_position = target:get_position();

    cast_spell.position(spell_id_hydra, target_position, 0.35) 
    
    -- 更新自动施放时间
    if auto_cast_enabled then
        last_auto_cast_time = get_time_since_inject();
        local delay_info = cast_delay_ms > 0 and (" (Delay: " .. cast_delay_ms .. "ms)") or "";
        if debug_enabled then console.print("Sorcerer Plugin, Hydra Auto Cast" .. delay_info); end
    else
        if debug_enabled then console.print("Sorcerer Plugin, Hydra"); end
    end
        
    return true;

end

return 
{
    menu = menu,
    logics = logics,   
}