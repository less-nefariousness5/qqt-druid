local my_utility = require("my_utility/my_utility")

local menu_elements_mighty_throw =
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_mighty_throw")),
    enable_combo_rotation = checkbox:new(true, get_hash(my_utility.plugin_label .. "enable_combo_rotation_mighty_throw")),
    combo_boss_mode       = checkbox:new(true, get_hash(my_utility.plugin_label .. "combo_boss_mode_mighty_throw")),
}

local function menu()
    if menu_elements_mighty_throw.tree_tab:push("Mighty Throw") then
        menu_elements_mighty_throw.main_boolean:render("Enable Spell", "")
        
        if menu_elements_mighty_throw.main_boolean:get() then
            menu_elements_mighty_throw.enable_combo_rotation:render("Enable Combo Rotation", "Use 12-second empowered rotation sequence")
            
            if menu_elements_mighty_throw.enable_combo_rotation:get() then
                menu_elements_mighty_throw.combo_boss_mode:render("Boss Detection", "Automatically adjust rotation for bosses (no Hammer of Ancients)")
            end
        end
        
        menu_elements_mighty_throw.tree_tab:pop()
    end
end

-- Buff tracking constants from D4 data
local EMPOWERING_BUFF_HASH = 270276116  -- Stacking buff (1-12)
local EMPOWERED_BUFF_HASH = 387682295   -- Ready-to-cast buff

local next_time_allowed_cast = 0.0
local spell_id_mighty_throw = 213593  -- Mighty Throw spell ID

local spell_data_mighty_throw = spell_data:new(
    2.0,                        -- radius
    25.0,                       -- range
    0.8,                        -- cast_delay
    0.6,                        -- projectile_speed
    true,                       -- has_collision
    spell_id_mighty_throw,      -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.targeted     -- targeting_type
)

local function check_mighty_throw_buffs()
    local local_player = get_local_player()
    if not local_player then return 0, false end
    
    local buffs = local_player:get_buffs()
    local empowering_stacks = 0
    local is_empowered = false
    
    for _, buff in ipairs(buffs) do
        if buff.name_hash == EMPOWERING_BUFF_HASH then
            empowering_stacks = buff:get_stacks() or 0
        elseif buff.name_hash == EMPOWERED_BUFF_HASH then
            is_empowered = true
        end
    end
    
    return empowering_stacks, is_empowered
end

local function is_boss_nearby(target_selector_data)
    return target_selector_data and target_selector_data.has_boss
end

local function logics(target, entity_list, target_selector_data)
    local menu_boolean = menu_elements_mighty_throw.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id_mighty_throw)

    if not is_logic_allowed then
        return false
    end

    -- If combo rotation is disabled, use simple logic
    if not menu_elements_mighty_throw.enable_combo_rotation:get() then
        if cast_spell.target(target, spell_data_mighty_throw, false) then
            local current_time = get_time_since_inject()
            next_time_allowed_cast = current_time + 0.3
            return true
        end
        return false
    end

    -- Combo rotation logic - only cast when empowered
    local empowering_stacks, is_empowered = check_mighty_throw_buffs()
    
    if is_empowered then
        if cast_spell.target(target, spell_data_mighty_throw, false) then
            local current_time = get_time_since_inject()
            next_time_allowed_cast = current_time + 0.3
            return true
        end
    end

    return false
end

return
{
    menu = menu,
    logics = logics,
    check_mighty_throw_buffs = check_mighty_throw_buffs,
    is_boss_nearby = is_boss_nearby,
    menu_elements = menu_elements_mighty_throw,
}