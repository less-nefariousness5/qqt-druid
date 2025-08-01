-- 高级反卡系统
-- 专门解决薄墙卡墙、角落震荡等问题

local logger = require "core.logger"

local AntiStuckSystem = {}
AntiStuckSystem.__index = AntiStuckSystem

-- 配置参数
local CONFIG = {
    position_history_size = 20,     -- 记录最近20个位置
    oscillation_threshold = 3,      -- 震荡检测阈值
    stuck_detection_time = 1.0,     -- 1秒检测间隔（快速响应）
    escape_attempt_radius = 8,      -- 逃脱尝试半径
    max_escape_attempts = 5,        -- 最大逃脱尝试次数
    thin_wall_detection_precision = 0.5  -- 薄墙检测精度
}

function AntiStuckSystem:new()
    local obj = {
        -- 位置历史记录
        position_history = {},
        
        -- 卡住状态
        stuck_state = {
            is_stuck = false,
            stuck_start_time = 0,
            stuck_position = nil,
            escape_attempts = 0,
            last_escape_time = 0
        },
        
        -- 震荡检测
        oscillation_detector = {
            pattern_buffer = {},
            detected_oscillations = 0,
            last_oscillation_time = 0
        },
        
        -- 统计信息
        stats = {
            total_stuck_events = 0,
            total_escape_attempts = 0,
            successful_escapes = 0
        }
    }
    
    setmetatable(obj, AntiStuckSystem)
    logger.info("AntiStuckSystem 已初始化，快速响应模式")
    return obj
end

-- 记录位置历史
function AntiStuckSystem:record_position(position)
    local current_time = get_time_since_inject()
    
    table.insert(self.position_history, {
        position = {x = position:x(), y = position:y(), z = position:z()},
        timestamp = current_time
    })
    
    -- 限制历史记录大小
    if #self.position_history > CONFIG.position_history_size then
        table.remove(self.position_history, 1)
    end
end

-- 检测是否在震荡（来回移动）
function AntiStuckSystem:detect_oscillation()
    if #self.position_history < 6 then
        return false, "历史记录不足"
    end
    
    local recent_positions = {}
    for i = math.max(1, #self.position_history - 5), #self.position_history do
        table.insert(recent_positions, self.position_history[i].position)
    end
    
    -- 检测A-B-A-B模式
    local oscillation_count = 0
    for i = 1, #recent_positions - 2 do
        local pos1 = recent_positions[i]
        local pos3 = recent_positions[i + 2]
        
        local distance = math.sqrt((pos1.x - pos3.x)^2 + (pos1.y - pos3.y)^2)
        if distance < 1.0 then  -- 回到了相似位置
            oscillation_count = oscillation_count + 1
        end
    end
    
    local is_oscillating = oscillation_count >= CONFIG.oscillation_threshold
    
    if is_oscillating then
        self.oscillation_detector.detected_oscillations = self.oscillation_detector.detected_oscillations + 1
        self.oscillation_detector.last_oscillation_time = get_time_since_inject()
        logger.debug("检测到位置震荡，震荡计数: " .. oscillation_count)
    end
    
    return is_oscillating, string.format("震荡计数: %d", oscillation_count)
end

-- 检测是否完全卡住
function AntiStuckSystem:detect_complete_stuck()
    if #self.position_history < 10 then
        return false, "历史记录不足"
    end
    
    local recent_positions = {}
    for i = math.max(1, #self.position_history - 9), #self.position_history do
        table.insert(recent_positions, self.position_history[i].position)
    end
    
    -- 计算最近10个位置的平均移动距离
    local total_movement = 0
    for i = 2, #recent_positions do
        local prev = recent_positions[i-1]
        local curr = recent_positions[i]
        local distance = math.sqrt((prev.x - curr.x)^2 + (prev.y - curr.y)^2)
        total_movement = total_movement + distance
    end
    
    local avg_movement = total_movement / (#recent_positions - 1)
    local is_stuck = avg_movement < 0.3  -- 平均移动距离很小
    
    if is_stuck then
        logger.debug("检测到完全卡住，平均移动距离: " .. string.format("%.3f", avg_movement))
    end
    
    return is_stuck, string.format("平均移动: %.3f", avg_movement)
end

-- 检测薄墙问题
function AntiStuckSystem:detect_thin_wall_issue(current_pos, target_pos)
    if not target_pos then return false end
    
    local direct_distance = math.sqrt(
        (target_pos:x() - current_pos:x())^2 + 
        (target_pos:y() - current_pos:y())^2
    )
    
    -- 如果目标很近但到不了，可能是薄墙问题
    if direct_distance < 5 then
        -- 检查直线路径上是否有不可行走的点
        local steps = math.ceil(direct_distance / CONFIG.thin_wall_detection_precision)
        local blocked_points = 0
        
        for i = 1, steps do
            local t = i / steps
            local check_pos = vec3:new(
                current_pos:x() + (target_pos:x() - current_pos:x()) * t,
                current_pos:y() + (target_pos:y() - current_pos:y()) * t,
                current_pos:z()
            )
            check_pos = utility.set_height_of_valid_position(check_pos)
            
            if not utility.is_point_walkeable(check_pos) then
                blocked_points = blocked_points + 1
            end
        end
        
        local blockage_ratio = blocked_points / steps
        local is_thin_wall = blockage_ratio > 0.3 and blockage_ratio < 0.8  -- 部分阻挡
        
        if is_thin_wall then
            logger.debug(string.format("检测到薄墙问题，阻挡比例: %.2f", blockage_ratio))
        end
        
        return is_thin_wall, string.format("阻挡比例: %.2f", blockage_ratio)
    end
    
    return false, "目标距离正常"
end

-- 综合卡住检测
function AntiStuckSystem:check_if_stuck(current_pos, target_pos)
    self:record_position(current_pos)
    
    local current_time = get_time_since_inject()
    local stuck_reasons = {}
    
    -- 检测1：震荡检测
    local is_oscillating, osc_reason = self:detect_oscillation()
    if is_oscillating then
        table.insert(stuck_reasons, "位置震荡: " .. osc_reason)
    end
    
    -- 检测2：完全卡住
    local is_completely_stuck, stuck_reason = self:detect_complete_stuck()
    if is_completely_stuck then
        table.insert(stuck_reasons, "完全卡住: " .. stuck_reason)
    end
    
    -- 检测3：薄墙问题
    local has_thin_wall_issue, wall_reason = self:detect_thin_wall_issue(current_pos, target_pos)
    if has_thin_wall_issue then
        table.insert(stuck_reasons, "薄墙问题: " .. wall_reason)
    end
    
    local is_stuck = #stuck_reasons > 0
    
    -- 更新卡住状态
    if is_stuck and not self.stuck_state.is_stuck then
        -- 开始卡住
        self.stuck_state.is_stuck = true
        self.stuck_state.stuck_start_time = current_time
        self.stuck_state.stuck_position = {x = current_pos:x(), y = current_pos:y(), z = current_pos:z()}
        self.stats.total_stuck_events = self.stats.total_stuck_events + 1
        
        logger.info("检测到卡住: " .. table.concat(stuck_reasons, ", "))
    elseif not is_stuck and self.stuck_state.is_stuck then
        -- 脱困成功
        local stuck_duration = current_time - self.stuck_state.stuck_start_time
        logger.info(string.format("脱困成功，卡住时长: %.2f秒", stuck_duration))
        self:reset_stuck_state()
        self.stats.successful_escapes = self.stats.successful_escapes + 1
    end
    
    return is_stuck, stuck_reasons
end

-- 智能逃脱策略
function AntiStuckSystem:attempt_escape(current_pos)
    local current_time = get_time_since_inject()
    
    -- 防止逃脱尝试太频繁
    if current_time - self.stuck_state.last_escape_time < 0.5 then
        return false, "逃脱冷却中"
    end
    
    if self.stuck_state.escape_attempts >= CONFIG.max_escape_attempts then
        return false, "已达最大逃脱尝试次数"
    end
    
    self.stuck_state.escape_attempts = self.stuck_state.escape_attempts + 1
    self.stuck_state.last_escape_time = current_time
    self.stats.total_escape_attempts = self.stats.total_escape_attempts + 1
    
    -- 逃脱策略1：随机方向移动
    local escape_strategies = {
        self:try_random_direction_escape,
        self:try_backward_escape,
        self:try_perpendicular_escape,
        self:try_movement_spell_escape
    }
    
    local strategy_index = ((self.stuck_state.escape_attempts - 1) % #escape_strategies) + 1
    local success, reason = escape_strategies[strategy_index](self, current_pos)
    
    logger.info(string.format("逃脱尝试 %d/%d: %s - %s", 
        self.stuck_state.escape_attempts, CONFIG.max_escape_attempts,
        success and "成功" or "失败", reason))
    
    return success, reason
end

-- 逃脱策略1：随机方向
function AntiStuckSystem:try_random_direction_escape(current_pos)
    local directions = {
        {x = 1, y = 0}, {x = -1, y = 0}, {x = 0, y = 1}, {x = 0, y = -1},
        {x = 1, y = 1}, {x = -1, y = 1}, {x = 1, y = -1}, {x = -1, y = -1}
    }
    
    -- 随机选择方向
    local direction = directions[math.random(#directions)]
    local escape_pos = vec3:new(
        current_pos:x() + direction.x * CONFIG.escape_attempt_radius,
        current_pos:y() + direction.y * CONFIG.escape_attempt_radius,
        current_pos:z()
    )
    escape_pos = utility.set_height_of_valid_position(escape_pos)
    
    if utility.is_point_walkeable(escape_pos) then
        if pathfinder and pathfinder.request_move then
            pathfinder.request_move(escape_pos)
            return true, "随机方向逃脱"
        else
            logger.warn("pathfinder模块不可用，无法执行随机方向逃脱")
            return false, "pathfinder不可用"
        end
    end
    
    return false, "随机方向不可行走"
end

-- 逃脱策略2：后退
function AntiStuckSystem:try_backward_escape(current_pos)
    if #self.position_history < 5 then
        return false, "历史记录不足"
    end
    
    -- 回到5步之前的位置
    local old_pos = self.position_history[#self.position_history - 4].position
    local escape_pos = vec3:new(old_pos.x, old_pos.y, old_pos.z)
    
    if utility.is_point_walkeable(escape_pos) then
        if pathfinder and pathfinder.request_move then
            pathfinder.request_move(escape_pos)
            return true, "后退逃脱"
        else
            return false, "pathfinder不可用"
        end
    end
    
    return false, "历史位置不可用"
end

-- 逃脱策略3：垂直方向
function AntiStuckSystem:try_perpendicular_escape(current_pos)
    if #self.position_history < 2 then
        return false, "无法计算移动方向"
    end
    
    local last_pos = self.position_history[#self.position_history - 1].position
    local movement_dir = {
        x = current_pos:x() - last_pos.x,
        y = current_pos:y() - last_pos.y
    }
    
    -- 计算垂直方向
    local perpendicular_dirs = {
        {x = -movement_dir.y, y = movement_dir.x},  -- 逆时针90度
        {x = movement_dir.y, y = -movement_dir.x}   -- 顺时针90度
    }
    
    for _, perp_dir in ipairs(perpendicular_dirs) do
        local escape_pos = vec3:new(
            current_pos:x() + perp_dir.x * CONFIG.escape_attempt_radius,
            current_pos:y() + perp_dir.y * CONFIG.escape_attempt_radius,
            current_pos:z()
        )
        escape_pos = utility.set_height_of_valid_position(escape_pos)
        
        if utility.is_point_walkeable(escape_pos) then
            if pathfinder and pathfinder.request_move then
                pathfinder.request_move(escape_pos)
                return true, "垂直方向逃脱"
            else
                return false, "pathfinder不可用"
            end
        end
    end
    
    return false, "垂直方向均不可行走"
end

-- 逃脱策略4：使用移动技能
function AntiStuckSystem:try_movement_spell_escape(current_pos)
    -- 如果有MovementService，尝试使用移动技能
    if MovementService and MovementService.use_movement_spell then
        -- 寻找较远的可行走点
        for radius = 10, 20, 5 do
            for angle = 0, 360, 45 do
                local radian = math.rad(angle)
                local escape_pos = vec3:new(
                    current_pos:x() + math.cos(radian) * radius,
                    current_pos:y() + math.sin(radian) * radius,
                    current_pos:z()
                )
                escape_pos = utility.set_height_of_valid_position(escape_pos)
                
                if utility.is_point_walkeable(escape_pos) then
                    local success = MovementService.use_movement_spell(escape_pos)
                    if success then
                        return true, "移动技能逃脱"
                    end
                end
            end
        end
    end
    
    return false, "移动技能不可用或无有效目标"
end

-- 重置卡住状态
function AntiStuckSystem:reset_stuck_state()
    self.stuck_state = {
        is_stuck = false,
        stuck_start_time = 0,
        stuck_position = nil,
        escape_attempts = 0,
        last_escape_time = 0
    }
end

-- 获取统计信息
function AntiStuckSystem:get_statistics()
    return {
        total_stuck_events = self.stats.total_stuck_events,
        total_escape_attempts = self.stats.total_escape_attempts,
        successful_escapes = self.stats.successful_escapes,
        escape_success_rate = self.stats.total_escape_attempts > 0 and 
                             (self.stats.successful_escapes / self.stats.total_escape_attempts * 100) or 0,
        currently_stuck = self.stuck_state.is_stuck,
        current_escape_attempts = self.stuck_state.escape_attempts
    }
end

-- 调试信息
function AntiStuckSystem:debug_status()
    local stats = self:get_statistics()
    logger.debug("=== AntiStuck 状态 ===")
    logger.debug(string.format("卡住事件: %d次", stats.total_stuck_events))
    logger.debug(string.format("逃脱尝试: %d次 (成功率: %.1f%%)", 
        stats.total_escape_attempts, stats.escape_success_rate))
    logger.debug(string.format("当前状态: %s", stats.currently_stuck and "卡住" or "正常"))
    logger.debug("====================")
end

return AntiStuckSystem