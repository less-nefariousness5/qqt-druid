-- 独立的A*寻路算法模块
-- 分离自explorer.lua以提高代码组织性和可复用性

local MinHeap = require "pathfinding.MinHeap"

local AStar = {}

-- A*寻路配置
local config = {
    max_iterations = 666,  -- 最大迭代次数，防止无限循环
    grid_size = 2,         -- 网格大小
    diagonal_cost = 1.414, -- 对角线移动成本 (sqrt(2))
    straight_cost = 1.0    -- 直线移动成本
}

-- 方向向量（8个方向）
local directions = {
    { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 },
    { x = 1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = 1 }, { x = -1, y = -1 }
}

-- 生成网格键值
-- @param point 3D位置向量
-- @return 字符串键值
local function get_grid_key(point)
    return math.floor(point:x() / config.grid_size) .. "," ..
           math.floor(point:y() / config.grid_size) .. "," ..
           math.floor(point:z() / config.grid_size)
end

-- 计算两点间距离（启发式函数）
-- @param a 起始点
-- @param b 目标点
-- @return 距离值
local function heuristic(a, b)
    local dx = a:x() - b:x()
    local dy = a:y() - b:y()
    local dz = a:z() - b:z()
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- 计算移动成本
-- @param from 起始点
-- @param to 目标点
-- @return 移动成本
local function get_movement_cost(from, to)
    local dx = math.abs(from:x() - to:x())
    local dy = math.abs(from:y() - to:y())
    
    -- 对角线移动
    if dx > 0 and dy > 0 then
        return config.diagonal_cost
    end
    -- 直线移动
    return config.straight_cost
end

-- 获取邻居节点
-- @param point 当前点
-- @param goal 目标点
-- @param last_movement_direction 上一次移动方向
-- @return 邻居节点列表
local function get_neighbors(point, goal, last_movement_direction)
    local neighbors = {}
    
    for _, dir in ipairs(directions) do
        local neighbor = vec3:new(
            point:x() + dir.x * config.grid_size,
            point:y() + dir.y * config.grid_size,
            point:z()
        )
        
        -- 设置有效高度
        neighbor = utility.set_height_of_valid_position(neighbor)
        
        -- 检查是否可行走
        if utility.is_point_walkeable(neighbor) then
            -- 避免立即返回（除非没有其他选择）
            if not last_movement_direction or
               (dir.x ~= -last_movement_direction.x or dir.y ~= -last_movement_direction.y) then
                table.insert(neighbors, neighbor)
            end
        end
    end
    
    -- 如果没有有效邻居且有上次移动方向，允许返回
    if #neighbors == 0 and last_movement_direction then
        local back_direction = vec3:new(
            point:x() - last_movement_direction.x * config.grid_size,
            point:y() - last_movement_direction.y * config.grid_size,
            point:z()
        )
        back_direction = utility.set_height_of_valid_position(back_direction)
        if utility.is_point_walkeable(back_direction) then
            table.insert(neighbors, back_direction)
        end
    end
    
    return neighbors
end

-- 重构路径
-- @param came_from 路径记录表
-- @param current 当前节点
-- @param path_angle 路径角度阈值（弧度）
-- @return 过滤后的路径
local function reconstruct_path(came_from, current, path_angle)
    local path = { current }
    while came_from[get_grid_key(current)] do
        current = came_from[get_grid_key(current)]
        table.insert(path, 1, current)
    end
    
    -- 路径过滤：移除不必要的中间点
    if #path <= 2 then
        return path
    end
    
    local filtered_path = { path[1] }
    local angle_threshold = path_angle or math.rad(45) -- 默认45度
    
    for i = 2, #path - 1 do
        local prev = path[i - 1]
        local curr = path[i]
        local next = path[i + 1]
        
        local dir1 = { x = curr:x() - prev:x(), y = curr:y() - prev:y() }
        local dir2 = { x = next:x() - curr:x(), y = next:y() - curr:y() }
        
        -- 计算角度
        local dot_product = dir1.x * dir2.x + dir1.y * dir2.y
        local magnitude1 = math.sqrt(dir1.x^2 + dir1.y^2)
        local magnitude2 = math.sqrt(dir2.x^2 + dir2.y^2)
        
        if magnitude1 > 0 and magnitude2 > 0 then
            local angle = math.acos(math.max(-1, math.min(1, dot_product / (magnitude1 * magnitude2))))
            
            -- 保留方向变化较大的点
            if angle > angle_threshold then
                table.insert(filtered_path, curr)
            end
        end
    end
    
    table.insert(filtered_path, path[#path])
    return filtered_path
end

-- 主要的A*寻路函数
-- @param start 起始位置
-- @param goal 目标位置
-- @param options 选项表 {max_iterations, path_angle, last_movement_direction}
-- @return 路径数组，如果没有找到路径则返回nil
function AStar.find_path(start, goal, options)
    options = options or {}
    local max_iterations = options.max_iterations or config.max_iterations
    local path_angle = options.path_angle
    local last_movement_direction = options.last_movement_direction
    
    -- 初始化
    local closed_set = {}
    local came_from = {}
    local g_score = { [get_grid_key(start)] = 0 }
    local f_score = { [get_grid_key(start)] = heuristic(start, goal) }
    local iterations = 0
    
    -- 创建开放集（优先队列）
    local open_set = MinHeap.new(function(a, b)
        local a_score = f_score[get_grid_key(a)] or math.huge
        local b_score = f_score[get_grid_key(b)] or math.huge
        return a_score < b_score
    end)
    
    open_set:push(start)
    
    -- 主循环
    while not open_set:empty() do
        iterations = iterations + 1
        if iterations > max_iterations then
            -- console.print("A*: 达到最大迭代次数，中止寻路")
            break
        end
        
        local current = open_set:pop()
        local current_key = get_grid_key(current)
        
        -- 检查是否到达目标
        if heuristic(current, goal) < config.grid_size then
            return reconstruct_path(came_from, current, path_angle)
        end
        
        closed_set[current_key] = true
        
        -- 检查所有邻居
        for _, neighbor in ipairs(get_neighbors(current, goal, last_movement_direction)) do
            local neighbor_key = get_grid_key(neighbor)
            
            if not closed_set[neighbor_key] then
                local tentative_g_score = (g_score[current_key] or math.huge) + get_movement_cost(current, neighbor)
                
                if not g_score[neighbor_key] or tentative_g_score < g_score[neighbor_key] then
                    came_from[neighbor_key] = current
                    g_score[neighbor_key] = tentative_g_score
                    f_score[neighbor_key] = g_score[neighbor_key] + heuristic(neighbor, goal)
                    
                    if not open_set:contains(neighbor) then
                        open_set:push(neighbor)
                    end
                end
            end
        end
    end
    
    return nil -- 没有找到路径
end

-- 配置函数
function AStar.set_grid_size(size)
    config.grid_size = size
end

function AStar.set_max_iterations(iterations)
    config.max_iterations = iterations
end

function AStar.get_config()
    return config
end

-- 快速路径验证
-- @param start 起始点
-- @param goal 目标点
-- @return true如果可能有路径，false如果明显无路径
function AStar.can_reach(start, goal)
    local distance = heuristic(start, goal)
    return distance > 0 and distance < 1000 -- 简单的距离检查
end

return AStar