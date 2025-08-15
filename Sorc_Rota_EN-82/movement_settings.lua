-- 移动技能设置模块
-- 用于在main.lua中访问各个技能的移动设置

local movement_settings = {
    -- 存储各技能的移动设置状态
    evade_exploration_movement = false,
    teleport_exploration_movement = false,
    manashield_exploration_cast = false,
}

-- 更新设置的函数
function movement_settings.update_evade_exploration(enabled)
    movement_settings.evade_exploration_movement = enabled
end

function movement_settings.update_teleport_exploration(enabled)
    movement_settings.teleport_exploration_movement = enabled
end

function movement_settings.update_manashield_exploration(enabled)
    movement_settings.manashield_exploration_cast = enabled
end

-- 获取设置的函数
function movement_settings.get_evade_exploration()
    return movement_settings.evade_exploration_movement
end

function movement_settings.get_teleport_exploration()
    return movement_settings.teleport_exploration_movement
end

function movement_settings.get_manashield_exploration()
    return movement_settings.manashield_exploration_cast
end

return movement_settings