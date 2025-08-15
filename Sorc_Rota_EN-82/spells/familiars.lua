local my_utility = require("my_utility/my_utility");

local menu_elements_familiars = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_familiars")),
    
    auto_cast_enabled     = checkbox:new(false, get_hash(my_utility.plugin_label .. "familiars_auto_cast_enabled")),
    cast_delay_ms         = slider_int:new(0, 5000, 1000, get_hash(my_utility.plugin_label .. "familiars_cast_delay_ms")),
}

local function menu()
    
    if menu_elements_familiars.tree_tab:push("Familiars")then
        menu_elements_familiars.main_boolean:render("Enable Spell", "")
        
        if menu_elements_familiars.main_boolean:get() then
        end
        
        menu_elements_familiars.auto_cast_enabled:render("Enable Auto Cast", "Automatically cast Familiars at set intervals when enemies are present")
        if menu_elements_familiars.auto_cast_enabled:get() then
            menu_elements_familiars.cast_delay_ms:render("Cast Delay (ms)", "Set Familiars casting interval, range 0-5000 milliseconds")
        end
 
        menu_elements_familiars.tree_tab:pop()
    end
end

local spell_id_familiars = 1627075
local next_time_allowed_cast = 0.0;
local last_auto_cast_time = 0.0;
local function logics(best_target, target_selector_data)
    
    local menu_boolean = menu_elements_familiars.main_boolean:get();
    local auto_cast_enabled = menu_elements_familiars.auto_cast_enabled:get();
    local cast_delay_ms = menu_elements_familiars.cast_delay_ms:get();
    
    -- 只检查技能开关
    if not menu_boolean then
        return false;
    end;
    
    -- 自动施放延迟检查
    if auto_cast_enabled then
        local current_time = get_time_since_inject();
        local delay_seconds = cast_delay_ms / 1000.0;
        
        if current_time - last_auto_cast_time < delay_seconds then
            return false;
        end
    end;
    
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_familiars);

    if not is_logic_allowed then
        return false;
    end;

    if not best_target then
        return false;
    end;

    local target_position = best_target:get_position();

    cast_spell.position(spell_id_familiars, target_position, 0.35) 
    local current_time = get_time_since_inject();
    next_time_allowed_cast = current_time + 5;
    
    -- 更新自动施放时间
    if auto_cast_enabled then
        last_auto_cast_time = get_time_since_inject();
        local delay_info = cast_delay_ms > 0 and (" (延迟: " .. cast_delay_ms .. "ms)") or "";
        console.print("Sorcerer Plugin, Familiars Auto Cast" .. delay_info);
    else
        console.print("Sorcerer Plugin, Familiars");
    end
        
    return true;

end

return 
{
    menu = menu,
    logics = logics,   
}