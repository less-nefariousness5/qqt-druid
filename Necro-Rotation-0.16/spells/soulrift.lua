local my_utility = require("my_utility/my_utility")

-- 菜单元素定义
local menu_elements_soulrift =
{
    tree_tab                  = tree_node:new(1),
    enable_spell              = checkbox:new(true, get_hash(my_utility.plugin_label .. "enable_spell_soulrift")),
    min_targets               = slider_int:new(1, 10, 3, get_hash(my_utility.plugin_label .. "min_enemies_to_cast_soulrift")),
    health_percentage         = slider_int:new(0, 100, 75, get_hash(my_utility.plugin_label .. "soulrift_health_percentage")),
    boss_range                = slider_float:new(5.0, 20.0, 10.0, get_hash(my_utility.plugin_label .. "soulrift_boss_range")),
    force_on_boss             = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_force_on_boss")),
}

-- 技能ID
local spell_id_soulrift = 1644584

-- 逻辑变量
local next_time_allowed_cast = 0.0
local last_cast_time = 0.0

-- 菜单函数
local function menu()
    if menu_elements_soulrift.tree_tab:push("Soulrift") then
        menu_elements_soulrift.enable_spell:render("Enable Spell", "")

        if menu_elements_soulrift.enable_spell:get() then
            menu_elements_soulrift.min_targets:render("Min Enemies Around", "Amount of targets to cast the spell", 0)
            menu_elements_soulrift.health_percentage:render("Max Health %", "Cast when health below this %", 0)
            menu_elements_soulrift.boss_range:render("Boss Detection Range", "Range to detect boss targets", 0)
            menu_elements_soulrift.force_on_boss:render("Force Cast on Boss", "Ignore conditions when boss is present", 0)
        end

        menu_elements_soulrift.tree_tab:pop()
    end
end

-- 检查附近是否有Boss
local function has_boss_in_range(range)
    local player_pos = get_player_position()
    if not player_pos then
        return false
    end

    local enemies = actors_manager.get_enemy_npcs()
    for _, enemy in ipairs(enemies) do
        if enemy:is_boss() and enemy:get_current_health() > 0 then
            local enemy_pos = enemy:get_position()
            local distance_sqr = enemy_pos:squared_dist_to_ignore_z(player_pos)
            if distance_sqr <= (range * range) then
                return true
            end
        end
    end

    return false
end

-- 逻辑函数
local function logics()
    if not menu_elements_soulrift.enable_spell:get() then
        return false
    end

    local is_allowed = my_utility.is_spell_allowed(
        true,
        next_time_allowed_cast,
        spell_id_soulrift
    )

    if not is_allowed then
        return false
    end

    local local_player = get_local_player()
    if not local_player then
        return false
    end

    -- Boss priority
    if menu_elements_soulrift.force_on_boss:get() then
        local boss_range = menu_elements_soulrift.boss_range:get()
        if has_boss_in_range(boss_range) then
            if cast_spell.self(spell_id_soulrift, 0.0) then
                console.print("Necromancer Plugin: Casted Soulrift on BOSS target")
                last_cast_time = get_time_since_inject()
                next_time_allowed_cast = last_cast_time + 0.5
                return true
            end
        end
    end

    -- Regular casting conditions
    local current_health = local_player:get_current_health()
    local max_health = local_player:get_max_health()
    local health_percentage = (current_health / max_health) * 100

    if health_percentage > menu_elements_soulrift.health_percentage:get() then
        return false
    end

    local player_pos = get_player_position()
    if not player_pos then
        return false
    end

    local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 3.0, 3.0, false)
    local enemy_count = area_data.n_hits

    if enemy_count < menu_elements_soulrift.min_targets:get() then
        return false
    end

    if cast_spell.self(spell_id_soulrift, 0.0) then
        console.print("Necromancer Plugin: Casted Soulrift on " .. enemy_count .. " enemies")
        last_cast_time = get_time_since_inject()
        next_time_allowed_cast = last_cast_time + 0.5
        return true
    end

    return false
end

return {
    menu = menu,
    logics = logics
}
