-- 统一的移动服务接口
-- 解耦任务模块与探索器的直接依赖关系

local AStar = require "pathfinding.AStar"
local logger = require "core.logger"

local MovementService = {}

-- 私有状态
local explorer_instance = nil
local current_target = nil
local movement_history = {}
local max_history = 20

-- 初始化服务
-- @param explorer 探索器实例
function MovementService.init(explorer)
    explorer_instance = explorer
    logger.info("MovementService 已初始化")
end

-- 设置移动目标
-- @param target 目标位置或对象
function MovementService.set_target(target)
    if not target then
        logger.warn("MovementService: 尝试设置空目标")
        return false
    end
    
    current_target = target
    
    -- 记录移动历史
    table.insert(movement_history, 1, {
        target = target,
        time = get_time_since_inject(),
        player_pos = get_player_position()
    })
    
    -- 限制历史记录大小
    if #movement_history > max_history then
        table.remove(movement_history)
    end
    
    if explorer_instance then
        explorer_instance:clear_path_and_target()
        explorer_instance:set_custom_target(target)
        logger.debug("MovementService: 目标已设置")
        return true
    else
        logger.error("MovementService: Explorer实例未初始化")
        return false
    end
end

-- 移动到目标
-- @return 成功返回true，失败返回false
function MovementService.move_to_target()
    if not current_target then
        logger.warn("MovementService: 没有设置移动目标")
        return false
    end
    
    if not explorer_instance then
        logger.error("MovementService: Explorer实例未初始化")
        return false
    end
    
    explorer_instance:move_to_target()
    return true
end

-- 移动到对象
-- @param object 游戏对象
-- @param distance 目标距离（可选，默认2.0）
function MovementService.move_to_object(object, distance)
    if not object then
        logger.warn("MovementService: 尝试移动到空对象")
        return false
    end
    
    distance = distance or 2.0
    local object_pos = object:get_position()
    
    if not object_pos then
        logger.warn("MovementService: 无法获取对象位置")
        return false
    end
    
    -- 检查是否已经在目标附近
    local player_pos = get_player_position()
    local current_distance = player_pos:dist_to(object_pos)
    
    if current_distance <= distance then
        logger.debug("MovementService: 已在目标附近，距离: " .. string.format("%.2f", current_distance))
        return true
    end
    
    return MovementService.set_target(object_pos)
end

-- 移动到位置
-- @param position 目标位置
function MovementService.move_to_position(position)
    if not position then
        logger.warn("MovementService: 尝试移动到空位置")
        return false
    end
    
    return MovementService.set_target(position)
end

-- 清除当前目标
function MovementService.clear_target()
    current_target = nil
    if explorer_instance then
        explorer_instance:clear_path_and_target()
        logger.debug("MovementService: 目标已清除")
    end
end

-- 获取当前目标
-- @return 当前目标位置或nil
function MovementService.get_current_target()
    return current_target
end

-- 检查是否到达目标
-- @param tolerance 容差距离（可选，默认2.0）
-- @return 到达返回true，否则false
function MovementService.is_target_reached(tolerance)
    if not current_target then
        return true -- 没有目标视为已到达
    end
    
    tolerance = tolerance or 2.0
    local player_pos = get_player_position()
    
    local target_pos = current_target
    if type(current_target.get_position) == "function" then
        target_pos = current_target:get_position()
    end
    
    local distance = player_pos:dist_to(target_pos)
    return distance <= tolerance
end

-- 获取移动历史
-- @return 移动历史数组
function MovementService.get_movement_history()
    return movement_history
end

-- 清除移动历史
function MovementService.clear_history()
    movement_history = {}
    logger.debug("MovementService: 移动历史已清除")
end

-- 检查是否在移动中
-- @return 移动中返回true，否则false
function MovementService.is_moving()
    if not explorer_instance then
        return false
    end
    
    return current_target ~= nil and not MovementService.is_target_reached()
end

-- 强制停止移动
function MovementService.stop_movement()
    MovementService.clear_target()
    logger.info("MovementService: 强制停止移动")
end

-- 使用移动技能到目标
-- @param target 目标位置
-- @return 成功返回true，失败返回false
function MovementService.use_movement_spell(target)
    if not explorer_instance then
        logger.error("MovementService: Explorer实例未初始化")
        return false
    end
    
    if not target then
        target = current_target
    end
    
    if not target then
        logger.warn("MovementService: 没有可用的移动技能目标")
        return false
    end
    
    -- 调用explorer的移动技能方法
    if type(explorer_instance.movement_spell_to_target) == "function" then
        explorer_instance:movement_spell_to_target(target)
        logger.debug("MovementService: 使用移动技能到目标")
        return true
    end
    
    logger.warn("MovementService: Explorer不支持移动技能")
    return false
end

-- 获取服务状态
-- @return 状态信息表
function MovementService.get_status()
    return {
        has_target = current_target ~= nil,
        is_moving = MovementService.is_moving(),
        history_count = #movement_history,
        explorer_initialized = explorer_instance ~= nil
    }
end

-- 调试功能：打印状态
function MovementService.debug_status()
    local status = MovementService.get_status()
    logger.debug("MovementService 状态:")
    logger.debug("  有目标: " .. tostring(status.has_target))
    logger.debug("  正在移动: " .. tostring(status.is_moving))
    logger.debug("  历史记录: " .. status.history_count)
    logger.debug("  Explorer已初始化: " .. tostring(status.explorer_initialized))
end

return MovementService