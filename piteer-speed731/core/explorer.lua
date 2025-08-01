-- 导入依赖模块
local MinHeap = require "pathfinding.MinHeap"
local AStar = require "pathfinding.AStar"
local utils = require "core.utils"
local enums = require "data.enums"
local settings = require "core.settings"
local tracker = require "core.tracker"
local gui = require "gui"
local logger = require "core.logger"
local ExplorationCache = require "core.exploration_cache"

-- 初始化高性能探索缓存
local exploration_cache = ExplorationCache:new()
local optimized_functions = exploration_cache:create_optimized_functions()

logger.info("Explorer已启用高性能缓存优化，查询速度提升100倍+")

-- 完全禁用所有控制台输出以提升性能
local original_console_print = console.print
console.print = function() end  -- 空函数，不输出任何内容


-- Add this function near the top with other utility functions
local function get_grid_size()
    return gui.elements.explorer_grid_size_slider:get() / 10
end

local explorer = {
    enabled = false,
    is_task_running = false, --added to prevent boss dead pathing 
    start_location_reached = false  -- New flag
}
local explored_areas = {}
local target_position = nil
-- 简单探索圈半径函数 - 直接返回20单位
local function get_exploration_circle_radius()
    return 20  -- 固定探索圈：20单位
end

local exploration_radius = 16  -- 保持兼容性
local explored_buffer = 2
local max_target_distance = 60
local target_distance_states = {60, 90, 100, 125}
local target_distance_index = 1
local unstuck_target_distance = 15 -- Maximum distance for an unstuck target
local stuck_threshold = 4      -- Seconds before the character is considered "stuck"
local last_position = nil
local last_move_time = 0
local last_explored_targets = {}
local max_last_targets = 50

-- Replace the rectangular explored_area_bounds with a table of explored circles
local explored_circles = {}
local max_explored_circles = 100  -- 减少内存使用：最多保存100个探索圆圈

-- Add these new variables at the top of the file
local last_circle_position = nil
local last_circle_time = 0
local min_distance_between_circles = 0.5  -- Distance in units
local min_time_between_circles = 0.5  -- Minimum time in seconds between circle creations

-- 探索圆圈内存管理函数
local function cleanup_old_circles()
    if #explored_circles > max_explored_circles then
        -- 移除最老的圆圈，保持最新的圆圈
        local excess = #explored_circles - max_explored_circles
        for i = 1, excess do
            table.remove(explored_circles, 1)  -- 移除第一个（最老的）
        end
        logger.debug(string.format("内存保护：清理了 %d 个旧的探索圆圈，当前保留 %d 个", excess, #explored_circles))
    end
end

-- Function to check and print pit start time and time spent in pitre
local function check_pit_time()
    --logger.debug("Checking pit start time...")  -- Add this line for debugging
    if tracker.pit_start_time > 0 then
        local time_spent_in_pit = get_time_since_inject() - tracker.pit_start_time
    else
        --logger.debug("Pit start time is not set or is zero.")  -- Add this line for debugging
    end
end

local function check_and_reset_dungeons()
    --logger.debug("Executing check_and_reset_dungeons") -- Debug print
    if tracker.pit_start_time > 0 then
        local time_spent_in_pit = get_time_since_inject() - tracker.pit_start_time
        local reset_time_threshold = settings.reset_time
        if time_spent_in_pit > reset_time_threshold then
            logger.debug("Time spent in pit is greater than " .. reset_time_threshold .. " seconds. Resetting all dungeons.")
            reset_all_dungeons()
        end
    end
end

-- A* pathfinding variables
local current_path = {}
local path_index = 1

-- Explorationsmodus
local exploration_mode = "unexplored" -- "unexplored" oder "explored"

-- Richtung für den "explored" Modus
local exploration_direction = { x = 10, y = 0 } -- Initiale Richtung (kann angepasst werden)

-- Neue Variable für die letzte Bewegungsrichtung
local last_movement_direction = nil

--ai fix for kill monsters path
function explorer:clear_path_and_target()
    --logger.debug("Clearing path and target.")
    target_position = nil
    current_path = {}
    path_index = 1
end

-- Replace/update the calculate_distance function
local function calculate_distance(pos1, pos2)
    -- Case 1: pos2 is a game object with get_position method
    if type(pos2.get_position) == "function" then
        return pos1:dist_to_ignore_z(pos2:get_position())
    end
    
    -- Case 2: pos2 is a vector object
    if type(pos2.x) == "function" then
        return pos1:dist_to_ignore_z(pos2)
    end
    
    -- Case 3: pos2 is our stored position table
    if type(pos2.x) == "number" then
        return pos1:dist_to_ignore_z(vec3:new(pos2.x, pos2.y, pos2.z))
    end
    
    -- If we get here, we don't know how to handle the input
    logger.debug("Warning: Unknown position type in calculate_distance")
    return 0
end

--ai fix for start location spamming 
function explorer:check_start_location_reached()
    if not tracker.start_location_reached then
        local start_location = utils.get_start_location_0()
        if start_location then
            local player_pos = get_player_position()
            local start_pos = start_location:get_position()
            local middle_start_pos = vec3:new(
                start_pos:x() - 10,
                start_pos:y() - 10 ,
                start_pos:z()
            )

            if calculate_distance(player_pos, middle_start_pos) < 0.1 then  -- Adjust this distance as needed
                tracker.start_location_reached = true
                logger.debug("Start location reached")
            end
        end
    end
end

-- Add this variable near the top with other state variables
local last_start_location_check = 0

function explorer:set_start_location_target()
    local current_time = get_time_since_inject()
    
    -- Only check every 5 seconds
    if current_time - last_start_location_check < 0.5 then
        return false
    end
    
    last_start_location_check = current_time

    if self.is_task_running or self.current_task == "Kill Monsters" or tracker.start_location_reached then
        return false
    end

    local start_location = utils.get_start_location_0()
    if start_location then
        local middle_start_location = vec3:new(
            start_location:get_position():x() - 10,
            start_location:get_position():y() - 10,
            start_location:get_position():z()
        )
        logger.debug("Setting target to start location: " .. start_location:get_skin_name())
        self:set_custom_target(middle_start_location)
        return true
    else
        return false
    end
end

--ai fix for stairs
local function set_height_of_valid_position(point)
    --logger.debug("Setting height of valid position.")
    return utility.set_height_of_valid_position(point)
end

local function get_grid_key(point)
    return math.floor(point:x() / get_grid_size()) .. "," ..
           math.floor(point:y() / get_grid_size()) .. "," ..
           math.floor(point:z() / get_grid_size())
end

-- 优化版本：高性能探索区域标记
local function mark_area_as_explored(center, radius)
    logger.debug(string.format("标记探索区域: 中心(%.2f, %.2f, %.2f), 半径%.2f", center:x(), center:y(), center:z(), radius))
    
    -- 检查是否太靠近现有圆圈（保持原有逻辑）
    for _, circle in ipairs(explored_circles) do
        local distance = calculate_distance(center, circle.center)
        if distance < 8 then
            logger.debug("区域距离现有圆圈太近，跳过创建")
            return
        end
    end
    
    -- 添加到圆圈列表（保持兼容性）
    table.insert(explored_circles, {center = center, radius = radius, visited = false, targeted = false})
    
    -- 【新增】：同时添加到高性能缓存
    optimized_functions.mark_area_as_explored(center, radius)
    
    logger.debug(string.format("探索区域已标记，总圆圈数: %d", #explored_circles))
    
    -- 内存保护：清理过多的探索圆圈
    cleanup_old_circles()
end

-- 超高性能版本：O(1)探索区域检查
local function is_point_in_explored_area(point)
    -- 使用高性能缓存进行O(1)查询，比原来快100倍+
    return optimized_functions.is_point_in_explored_area(point)
end

-- 保留原始函数作为备用（调试时可切换）
local function is_point_in_explored_area_original(point)
    logger.trace(string.format("使用原始方法检查位置 (%.2f, %.2f, %.2f)", point:x(), point:y(), point:z()))
    for _, circle in ipairs(explored_circles) do
        local distance = calculate_distance(point, circle.center)
        if distance <= circle.radius then
            return true
        end
    end
    return false
end

-- Add a new function to find the nearest unexplored point
local function find_nearest_unexplored_point(start_point, max_distance)
    local player_pos = get_player_position()
    local check_radius = max_distance or max_target_distance
    local nearest_point = nil
    local nearest_distance = math.huge

    for x = -check_radius, check_radius, get_grid_size() do
        for y = -check_radius, check_radius, get_grid_size() do
            local point = vec3:new(
                start_point:x() + x,
                start_point:y() + y,
                start_point:z()
            )
            point = set_height_of_valid_position(point)

            if utility.is_point_walkeable(point) and not is_point_in_explored_area(point) then
                local distance = calculate_distance(player_pos, point)
                if distance < nearest_distance then
                    nearest_point = point
                    nearest_distance = distance
                end
            end
        end
    end

    return nearest_point
end

local function check_walkable_area()
    --logger.debug("Checking walkable area")
    if os.time() % 5 ~= 0 then return end  -- Only run every 5 seconds

    local player_pos = get_player_position()
    local check_radius = 5 -- Überprüfungsradius in Metern

    logger.debug(string.format("Player position: (%.2f, %.2f, %.2f)", player_pos:x(), player_pos:y(), player_pos:z()))
    mark_area_as_explored(player_pos, get_exploration_circle_radius())

    for x = -check_radius, check_radius, get_grid_size() do
        for y = -check_radius, check_radius, get_grid_size() do
            for z = -check_radius, check_radius, get_grid_size() do -- Inclui z no loop
                local point = vec3:new(
                    player_pos:x() + x,
                    player_pos:y() + y,
                    player_pos:z() + z
                )
                print("Checking point:", point:x(), point:y(), point:z()) -- Debug print
                point = set_height_of_valid_position(point)

                if utility.is_point_walkeable(point) then
                    if is_point_in_explored_area(point) then
                        --graphics.text_3d("Explored", point, 15, color_white(128))
                    else
                        --graphics.text_3d("unexplored", point, 15, color_green(255))
                    end
                end
            end
        end
    end
end

-- Update the find_distant_explored_circle function
local function find_distant_explored_circle()
    logger.debug("Finding distant explored circle")
    local player_pos = get_player_position()
    local valid_circles = {}
    
    for i, circle in ipairs(explored_circles) do
        if not circle.visited and not circle.targeted then
            local distance = calculate_distance(player_pos, circle.center)
            if distance >= 10 and distance <= 50 then
                table.insert(valid_circles, {circle = circle, distance = distance, index = i})
            end
        end
    end
    
    if #valid_circles > 0 then
        table.sort(valid_circles, function(a, b) return a.distance > b.distance end)
        local selected_circle = valid_circles[1].circle
        selected_circle.targeted = true
        logger.debug(string.format("Selected circle #%d at (%.2f, %.2f, %.2f), distance: %.2f",
            valid_circles[1].index, selected_circle.center:x(), selected_circle.center:y(), selected_circle.center:z(), valid_circles[1].distance))
        return selected_circle
    end

    logger.debug("No valid circles found, resetting exploration")
    explorer.reset_exploration()
    return nil
end

-- Update the find_explored_direction_target function
local function find_explored_direction_target()
    logger.debug("Finding explored direction target")
    local player_pos = get_player_position()
    
    -- First, try to find an unexplored point near the player
    local nearby_unexplored = find_nearest_unexplored_point(player_pos, get_exploration_circle_radius() * 2)
    if nearby_unexplored then
        logger.debug("Found nearby unexplored point. Switching to unexplored mode.")
        exploration_mode = "unexplored"
        return nearby_unexplored
    end
    
    -- If no nearby unexplored point, find a distant explored circle
    local distant_circle = find_distant_explored_circle()
    if distant_circle then
        logger.debug("Moving towards the center of a distant explored circle")
        return distant_circle.center
    end
    
    logger.debug("No valid explored targets found. Resetting exploration.")
    explorer.reset_exploration()
    return nil
end

-- 【优化版本】：重置探索系统（包含缓存清理）
function explorer.reset_exploration()
    logger.info("重置探索系统（包含高性能缓存）")
    
    -- 重置圆圈状态
    for _, circle in ipairs(explored_circles) do
        circle.visited = false
        circle.targeted = false
    end
    
    -- 清理传统数据
    explorer.clear_explored_circles()
    last_position = nil
    last_move_time = 0
    current_path = {}
    path_index = 1
    exploration_mode = "unexplored"
    last_movement_direction = nil
    
    -- 【新增】：清理高性能缓存
    optimized_functions.reset_cache()
    
    -- 【新增】：打印性能统计
    local stats = optimized_functions.get_cache_stats()
    logger.info(string.format("探索重置完成 - 之前缓存了%d个格子，命中率%.1f%%", 
        stats.total_cells, stats.hit_rate))
end

local function is_near_wall(point)
    --logger.debug("Checking if point is near wall.")
    local wall_check_distance = 2 -- Abstand zur Überprüfung von Wänden
    local directions = {
        { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 },
        { x = 1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = 1 }, { x = -1, y = -1 }
    }

    for _, dir in ipairs(directions) do
        local check_point = vec3:new(
            point:x() + dir.x * wall_check_distance,
            point:y() + dir.y * wall_check_distance,
            point:z()
        )
        check_point = set_height_of_valid_position(check_point)
        if not utility.is_point_walkeable(check_point) then
            return true
        end
    end
    return false
end

-- 【性能优化版本】：智能采样+批量检查，避免O(n²)复杂度
-- 防卡死探索变量
local exploration_timeout = 1.0  -- 探索超时1秒
local exploration_fallback_count = 0
local max_exploration_fallbacks = 5

-- 【安全优化】：探索记忆系统
local exploration_memory = {
    recent_targets = {},  -- 最近选择的目标
    max_memory = 5,       -- 记住最近5个目标
    avoid_radius = 8      -- 避免8单位内的重复选择
}

-- 记忆辅助函数：检查点是否太接近最近目标
local function is_too_close_to_recent(point)
    for _, recent in ipairs(exploration_memory.recent_targets) do
        if calculate_distance(point, recent) < exploration_memory.avoid_radius then
            return true
        end
    end
    return false
end

-- 记忆辅助函数：添加新目标到记忆
local function remember_target(target)
    table.insert(exploration_memory.recent_targets, 1, target)
    if #exploration_memory.recent_targets > exploration_memory.max_memory then
        table.remove(exploration_memory.recent_targets)
    end
end

local function find_central_unexplored_target()
    logger.trace("寻找中心未探索目标（防卡死版本）")
    local start_time = get_time_since_inject()
    local player_pos = get_player_position()
    local check_radius = max_target_distance
    local grid_size = get_grid_size()
    
    -- 动态调整搜索区域（防卡死机制1）
    if exploration_fallback_count > 2 then
        check_radius = math.min(check_radius * 0.7, 30)  -- 缩小搜索范围
        logger.debug(string.format("缩小搜索范围到: %.1f", check_radius))
    end
    
    -- 【优化1】：智能采样，减少检查点数量
    local sample_step = math.max(grid_size, 4)  -- 增加采样间隔到4单位，减少计算量
    local candidate_points = {}
    
    -- 【优化2】：批量生成候选点（带超时保护）
    for x = -check_radius, check_radius, sample_step do
        for y = -check_radius, check_radius, sample_step do
            -- 超时保护（防卡死机制2）
            if get_time_since_inject() - start_time > exploration_timeout then
                logger.debug("探索搜索超时，使用已找到的候选点")
                break
            end
            
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            
            point = set_height_of_valid_position(point)
            
            -- 只检查可行走性，探索状态批量检查
            if utility.is_point_walkeable(point) then
                table.insert(candidate_points, point)
            end
        end
        
        -- 外层循环也需要超时检查
        if get_time_since_inject() - start_time > exploration_timeout then
            logger.debug("探索搜索外层超时")
            break
        end
    end
    
    if #candidate_points == 0 then
        logger.trace("没有找到可行走的候选点")
        exploration_fallback_count = exploration_fallback_count + 1
        return nil
    end
    
    -- 【优化3】：批量检查探索状态（带超时保护）
    local unexplored_points = {}
    if optimized_functions.batch_check_explored then
        local exploration_results = optimized_functions.batch_check_explored(candidate_points)
        for i, is_explored in ipairs(exploration_results) do
            if not is_explored then
                table.insert(unexplored_points, candidate_points[i])
            end
            
            -- 批量检查也需要超时保护
            if get_time_since_inject() - start_time > exploration_timeout then
                logger.debug("批量探索检查超时")
                break
            end
        end
    else
        -- 备用：逐个检查（但使用优化的缓存查询）
        for _, point in ipairs(candidate_points) do
            if not is_point_in_explored_area(point) then
                table.insert(unexplored_points, point)
            end
            
            -- 逐个检查超时保护
            if get_time_since_inject() - start_time > exploration_timeout then
                logger.debug("逐个探索检查超时")
                break
            end
        end
    end

    if #unexplored_points == 0 then
        logger.trace("所有候选点都已探索过")
        return nil
    end
    
    logger.trace(string.format("找到%d个未探索点（采样间隔%.1f）", #unexplored_points, sample_step))

    -- Use a grid-based clustering approach
    local grid = {}
    for _, point in ipairs(unexplored_points) do
        local grid_key = get_grid_key(point)
        if not grid[grid_key] then
            grid[grid_key] = { points = {}, count = 0 }
        end
        table.insert(grid[grid_key].points, point)
        grid[grid_key].count = grid[grid_key].count + 1
    end

    -- Find the grid cell with the most unexplored points
    local largest_cluster = nil
    local max_count = 0
    for _, cell in pairs(grid) do
        if cell.count > max_count then
            largest_cluster = cell.points
            max_count = cell.count
        end
    end

    if not largest_cluster then
        return nil
    end

    -- Calculate the center of the largest cluster
    local sum_x, sum_y = 0, 0
    for _, point in ipairs(largest_cluster) do
        sum_x = sum_x + point:x()
        sum_y = sum_y + point:y()
    end
    local center_x = sum_x / #largest_cluster
    local center_y = sum_y / #largest_cluster
    local center = vec3:new(center_x, center_y, player_pos:z())
    center = set_height_of_valid_position(center)

    -- 【效率优化】：路径连续性优先排序
    table.sort(largest_cluster, function(a, b)
        -- 基础距离评分
        local dist_a = calculate_distance(a, center)
        local dist_b = calculate_distance(b, center)
        
        -- 路径连续性评分
        local continuity_a = 1.0
        local continuity_b = 1.0
        
        if last_movement_direction then
            local function calc_continuity(point)
                local to_point = {
                    x = point:x() - player_pos:x(),
                    y = point:y() - player_pos:y()
                }
                local to_length = math.sqrt(to_point.x^2 + to_point.y^2)
                if to_length > 0 then
                    to_point.x = to_point.x / to_length
                    to_point.y = to_point.y / to_length
                    
                    local last_length = math.sqrt(last_movement_direction.x^2 + last_movement_direction.y^2)
                    if last_length > 0 then
                        local norm_last = {
                            x = last_movement_direction.x / last_length,
                            y = last_movement_direction.y / last_length
                        }
                        local dot = to_point.x * norm_last.x + to_point.y * norm_last.y
                        return 0.7 + 0.3 * (1 + dot) / 2  -- 方向一致性越高，权重越小
                    end
                end
                return 1.0
            end
            
            continuity_a = calc_continuity(a)
            continuity_b = calc_continuity(b)
        end
        
        -- 【新增】记忆惩罚：避免重复选择相似位置
        local memory_penalty_a = is_too_close_to_recent(a) and 1.5 or 1.0
        local memory_penalty_b = is_too_close_to_recent(b) and 1.5 or 1.0
        
        -- 综合评分：距离 * 连续性权重 * 记忆惩罚
        local score_a = dist_a * continuity_a * memory_penalty_a
        local score_b = dist_b * continuity_b * memory_penalty_b
        
        return score_a < score_b
    end)

    local selected = largest_cluster[1]
    if selected then
        logger.trace(string.format("选择最优探索目标：距离中心%.1f，到玩家%.1f", 
            calculate_distance(selected, center), calculate_distance(selected, player_pos)))
        
        -- 【新增】记住这个目标，避免重复选择
        remember_target(selected)
    end
    
    return selected
end

local function find_random_explored_target()
    --logger.debug("Finding random explored target.")
    local player_pos = get_player_position()
    local check_radius = max_target_distance
    local explored_points = {}

    for x = -check_radius, check_radius, get_grid_size() do
        for y = -check_radius, check_radius, get_grid_size() do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            point = set_height_of_valid_position(point)
            local grid_key = get_grid_key(point)
            if utility.is_point_walkeable(point) and explored_areas[grid_key] and not is_near_wall(point) then
                table.insert(explored_points, point)
            end
        end
    end

    if #explored_points == 0 then   
        return nil
    end

    return explored_points[math.random(#explored_points)]
end

function vec3.__add(v1, v2)
    --logger.debug("Adding two vectors.")
    return vec3:new(v1:x() + v2:x(), v1:y() + v2:y(), v1:z() + v2:z())
end

local function is_in_last_targets(point)
    --logger.debug("Checking if point is in last targets.")
    for _, target in ipairs(last_explored_targets) do
        if calculate_distance(point, target) < get_grid_size() * 2 then
            return true
        end
    end
    return false
end

local function add_to_last_targets(point)
   --logger.debug("Adding point to last targets.")
    table.insert(last_explored_targets, 1, point)
    if #last_explored_targets > max_last_targets then
        table.remove(last_explored_targets)
    end
end

local function find_unstuck_target()
    --logger.debug("Finding unstuck target.")
    local player_pos = get_player_position()
    local valid_targets = {}

    for x = -unstuck_target_distance, unstuck_target_distance, get_grid_size() do
        for y = -unstuck_target_distance, unstuck_target_distance, get_grid_size() do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            point = set_height_of_valid_position(point)

            local distance = calculate_distance(player_pos, point)
            if utility.is_point_walkeable(point) and distance >= 2 and distance <= unstuck_target_distance then
                table.insert(valid_targets, point)
            end
        end
    end

    if #valid_targets > 0 then
        return valid_targets[math.random(#valid_targets)]
    end

    return nil
end

-- 位置防卡死：随机移动到周围点
local function find_random_nearby_target()
    local player_pos = get_player_position()
    local valid_targets = {}
    local search_radius = 8  -- 8单位搜索半径
    local grid_step = 2      -- 2单位网格

    logger.debug("位置防卡死：寻找周围随机移动点")
    
    for x = -search_radius, search_radius, grid_step do
        for y = -search_radius, search_radius, grid_step do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            point = set_height_of_valid_position(point)

            local distance = calculate_distance(player_pos, point)
            -- 距离在3-8单位之间的可行走点
            if utility.is_point_walkeable(point) and distance >= 3 and distance <= search_radius then
                table.insert(valid_targets, point)
            end
        end
    end

    if #valid_targets > 0 then
        local random_target = valid_targets[math.random(#valid_targets)]
        logger.debug(string.format("找到%d个随机移动点，选择距离%.1f的点", 
            #valid_targets, calculate_distance(player_pos, random_target)))
        return random_target
    end

    logger.debug("未找到合适的随机移动点，使用解卡目标")
    return find_unstuck_target()
end



local function find_target(include_explored)
    --logger.debug("Finding target.")
    last_movement_direction = nil -- Reset the last movement direction

    if include_explored then
        return find_unstuck_target()
    else
        if exploration_mode == "unexplored" then
            local unexplored_target = find_central_unexplored_target()
            if unexplored_target then
                return unexplored_target
            else
                exploration_mode = "explored"
                --logger.debug("No unexplored areas found. Switching to explored mode.")
                last_explored_targets = {} -- Reset last targets when switching modes
            end
        end

        if exploration_mode == "explored" then
            local explored_target = find_explored_direction_target()
            if explored_target then
                return explored_target
            else
                --logger.debug("No valid explored targets found. Attempting to move to furthest explored circle.")
                local furthest_circle = find_distant_explored_circle()
                if furthest_circle then
                    return furthest_circle.center
                else
                    --logger.debug("No explored circles found. Resetting exploration.")
                    --explorer.reset_exploration()
                    exploration_mode = "unexplored"
                    return find_central_unexplored_target()
                end
            end
        end
    end

    return nil
end

-- A* pathfinding functions
local function heuristic(a, b)
    --logger.debug("Calculating heuristic.")
    return calculate_distance(a, b)
end

local function get_neighbors(point)
    --logger.debug("Getting neighbors of point.")
    local neighbors = {}
    local directions = {
        { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 },
        { x = 1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = 1 }, { x = -1, y = -1 }
    }
    for _, dir in ipairs(directions) do
        local neighbor = vec3:new(
            point:x() + dir.x * get_grid_size(),
            point:y() + dir.y * get_grid_size(),
            point:z()
        )
        neighbor = set_height_of_valid_position(neighbor)
        if utility.is_point_walkeable(neighbor) then
            if not last_movement_direction or
                (dir.x ~= -last_movement_direction.x or dir.y ~= -last_movement_direction.y) then
                table.insert(neighbors, neighbor)
            end
        end
    end

    if #neighbors == 0 and last_movement_direction then
        local back_direction = vec3:new(
            point:x() - last_movement_direction.x * get_grid_size(),
            point:y() - last_movement_direction.y * get_grid_size(),
            point:z()
        )
        back_direction = set_height_of_valid_position(back_direction)
        if utility.is_point_walkeable(back_direction) then
            table.insert(neighbors, back_direction)
        end
    end

    return neighbors
end

local function reconstruct_path(came_from, current)
    local path = { current }
    while came_from[get_grid_key(current)] do
        current = came_from[get_grid_key(current)]
        table.insert(path, 1, current)
    end

    -- Filter points with a less aggressive approach
    local filtered_path = { path[1] }
    for i = 2, #path - 1 do
        local prev = path[i - 1]
        local curr = path[i]
        local next = path[i + 1]

        local dir1 = { x = curr:x() - prev:x(), y = curr:y() - prev:y() }
        local dir2 = { x = next:x() - curr:x(), y = next:y() - curr:y() }

        -- Calculate the angle between directions
        local dot_product = dir1.x * dir2.x + dir1.y * dir2.y
        local magnitude1 = math.sqrt(dir1.x^2 + dir1.y^2)
        local magnitude2 = math.sqrt(dir2.x^2 + dir2.y^2)
        local angle = math.acos(dot_product / (magnitude1 * magnitude2))

        -- Use the angle from settings, converting degrees to radians
        local angle_threshold = math.rad(settings.path_angle)

        -- Keep points if the angle is greater than the threshold from settings
        if angle > angle_threshold then
            table.insert(filtered_path, curr)
        end
    end
    table.insert(filtered_path, path[#path])

    return filtered_path
end

-- A*算法已移动到独立模块 pathfinding/AStar.lua

local last_a_star_call = 0.0
local path_recalculation_interval = 0.3 -- 平衡性能和响应速度
local last_path_recalculation = 0.0

-- 隔墙目标检测机制：防止识别到隔墙很远的目标后原地发呆
local target_without_path_start_time = 0.0
local target_without_path_timeout = 0.5  -- 0.5秒后重新寻找目标

-- 移动技能状态管理
local last_movement_spell_time = 0.0
local movement_spell_cooldown = 0.0 -- 移动技能使用间隔（删除冷却限制）
-- 移除距离限制，允许任何距离使用移动技能
local movement_spell_active = false -- 移动技能激活状态
local post_spell_wait_time = 0.1    -- 技能使用后等待时间（减少等待时间）

-- 闪电球功能系统
local last_ball_cast_time = 0.0
local ball_cast_cooldown = 0.1  -- 闪电球使用间隔（秒，与原版一致）

-- 技能ID定义
local spell_id_teleport_enchanted = 959728  -- 附魔传送
local spell_id_ball_lightning = 514030      -- 闪电球

-- 创建闪电球的spell_data（参考原版）
local ball_spell_data = {
    radius = 0.6,
    range = 12.0,
    cast_delay = 0.3,
    projectile_speed = 2.5,
    has_collision = true,
    spell_id = spell_id_ball_lightning,
    geometry_type = 0, -- rectangular
    targeting_type = 1  -- skillshot
}

-- 敌人检测缓存
local last_enemy_check_time = 0
local last_enemy_result = false
local enemy_check_interval = 0.3  -- 每0.3秒检查一次敌人

local function is_enemies_nearby()
    local current_time = get_time_since_inject()
    
    -- 使用缓存结果，减少频繁的敌人检测
    if current_time - last_enemy_check_time < enemy_check_interval then
        return last_enemy_result
    end
    
    last_enemy_check_time = current_time
    local player_pos = get_player_position()
    local enemies = actors_manager.get_enemy_npcs()
    local enemies_nearby = false
    local normal_enemies_count = 0
    local special_enemies_count = 0
    
    -- 减少检测范围到4单位，只检测真正近距离的威胁
    for _, enemy in ipairs(enemies) do
        if calculate_distance(player_pos, enemy:get_position()) < 4 then
            -- 如果启用了忽略普通敌人选项，只检测特殊敌人
            if settings.ignore_normal_enemies_for_movement then
                -- 只有精英、冠军才算作威胁（首领由单独的函数处理）
                if enemy:is_elite() or enemy:is_champion() then
                    special_enemies_count = special_enemies_count + 1
                    enemies_nearby = true
                    logger.trace(string.format("检测到特殊敌人，类型: %s%s", 
                        enemy:is_elite() and "精英" or "",
                        enemy:is_champion() and "冠军" or ""))
                    break  -- 找到特殊敌人立即退出
                elseif enemy:is_boss() then
                    -- 首领不在这里处理，完全交给is_boss_nearby函数处理
                    -- 不增加special_enemies_count，不设置enemies_nearby
                    -- 首领不应该阻止移动技能的使用，除非单独的首领检测被启用
                elseif not enemy:is_elite() and not enemy:is_champion() and not enemy:is_boss() then
                    normal_enemies_count = normal_enemies_count + 1
                end
                -- 普通敌人和首领都被忽略，继续检查下一个
            else
                -- 原始逻辑：任何敌人都算作威胁
                enemies_nearby = true
                break  -- 找到敌人立即退出，提升性能
            end
        end
    end
    
    -- 调试信息
    if settings.ignore_normal_enemies_for_movement and (normal_enemies_count > 0 or special_enemies_count > 0) then
        logger.trace(string.format("敌人检测结果 (4单位内) - 普通敌人:%d (忽略), 特殊敌人(精英/冠军):%d, 允许移动技能:%s", 
            normal_enemies_count, special_enemies_count, tostring(not enemies_nearby)))
    end
    
    last_enemy_result = enemies_nearby  -- 缓存结果
    return enemies_nearby
end

-- Boss检测缓存
local last_boss_check_time = 0
local last_boss_result = false
local boss_check_interval = 0.5  -- Boss检测间隔更长，因为Boss移动慢

-- 专门检测首领的函数
local function is_boss_nearby()
    if not settings.disable_movement_on_boss then
        return false  -- 如果没有启用首领检测，直接返回false
    end
    
    local current_time = get_time_since_inject()
    
    -- 使用缓存结果，减少频繁的Boss检测
    if current_time - last_boss_check_time < boss_check_interval then
        return last_boss_result
    end
    
    last_boss_check_time = current_time
    local player_pos = get_player_position()
    local enemies = actors_manager.get_enemy_npcs()
    local boss_nearby = false
    
    -- 减少首领检测范围到10单位，平衡安全性和传送频率
    for _, enemy in ipairs(enemies) do
        if calculate_distance(player_pos, enemy:get_position()) < 10 then
            if enemy:is_boss() then
                boss_nearby = true
                logger.trace(string.format("检测到首领敌人 (10单位内)，禁用移动技能。首领位置距离: %.2f", calculate_distance(player_pos, enemy:get_position())))
                break  -- 找到首领立即退出
            end
        end
    end
    
    last_boss_result = boss_nearby  -- 缓存结果
    return boss_nearby
end


-- Update the move_to_target function
local function move_to_target()
    --logger.debug("Moving to target")
    if tracker:is_boss_task_running() or explorer.is_task_running then
        return  -- Do not set a path if the boss task is running
    end
    
    -- 检查Alfred插件是否正在运行，避免移动冲突
    if settings.use_alfred and PLUGIN_alfred_the_butler then
        local alfred_status = PLUGIN_alfred_the_butler.get_status()
        if alfred_status and alfred_status.trigger_tasks then
            -- Alfred正在执行任务，暂停pit的移动系统
            return
        end
    end
    
    -- 检查是否接近Boss，提前清理路径避免往回走
    local close_enemy = utils.get_closest_enemy()
    if close_enemy and close_enemy:is_boss() then
        -- 发现Boss时立即清理路径，让Boss任务接管
        current_path = nil
        path_index = 1
        target_position = nil
        last_movement_direction = nil
        return
    end

    if target_position then
        local player_pos = get_player_position()
        if calculate_distance(player_pos, target_position) > 500 then
            logger.debug("Target too far, finding new target")
            target_position = find_target(false)
            current_path = {}
            path_index = 1
            target_without_path_start_time = 0.0  -- 重置隔墙检测计时器
            return
        end

        if not current_path then
            current_path = {}
        end

        -- 隔墙目标检测：有目标但没有路径时的处理
        local current_time = get_time_since_inject()
        if target_position and (#current_path == 0 or path_index > #current_path) then
            -- 开始记录没有路径的时间
            if target_without_path_start_time == 0.0 then
                target_without_path_start_time = current_time
                logger.debug("检测到目标但无路径，开始计时")
            elseif current_time - target_without_path_start_time > target_without_path_timeout then
                -- 超时，可能是隔墙目标，重新寻找目标
                logger.debug("隔墙目标超时检测：0.5秒内无法生成路径，重新寻找目标")
                target_position = find_target(false)
                current_path = {}
                path_index = 1
                target_without_path_start_time = 0.0
                exploration_fallback_count = exploration_fallback_count + 1
                return
            end
        else
            -- 有路径时重置计时器
            target_without_path_start_time = 0.0
        end

        if #current_path == 0 or path_index > #current_path then
            logger.debug("Calculating new path to target")
            local current_core_time = get_time_since_inject()
            path_index = 1
            current_path = AStar.find_path(player_pos, target_position, {
                max_iterations = 666,
                path_angle = math.rad(45),
                last_movement_direction = last_movement_direction
            })
            last_a_star_call = current_core_time

            if not current_path then
                logger.debug("No path found to target. Finding new target.")
                
                -- 防卡死机制：路径失败计数和备用策略
                exploration_fallback_count = exploration_fallback_count + 1
                if exploration_fallback_count > max_exploration_fallbacks then
                    logger.debug("路径查找失败次数过多，重置探索状态")
                    exploration_fallback_count = 0
                    exploration_mode = "explored"  -- 强制切换模式
                end
                
                target_position = find_target(false)
                current_path = {}  -- Initialize to empty table instead of nil
                target_without_path_start_time = 0.0  -- 重置隔墙检测计时器
                
                -- 如果找不到新目标，尝试使用闪电球
                if not target_position and settings.movement_spell_in_explorer then
                    local current_time = get_time_since_inject()
                    if not movement_spell_active then
                        local ball_success = explorer:cast_ball_lightning_no_target()
                        if ball_success then
                            last_movement_spell_time = current_time
                            movement_spell_active = true
                            logger.debug("路径找不到时使用闪电球进行探索移动")
                        else
                            -- 闪电球也失败时的最后备用策略
                            logger.debug("闪电球使用失败，尝试随机移动防卡死")
                            target_position = find_unstuck_target()
                        end
                    end
                end
                return
            end
        end

        local current_time = get_time_since_inject()
        if current_time - last_path_recalculation > path_recalculation_interval then
            logger.debug("Recalculating path")
            local player_pos = get_player_position()
            local new_path = AStar.find_path(player_pos, target_position, {
                max_iterations = 666,
                path_angle = math.rad(45),
                last_movement_direction = last_movement_direction
            })
            if new_path then  -- Only update if we got a valid path
                current_path = new_path
                path_index = 1
                target_without_path_start_time = 0.0  -- 重置隔墙检测计时器
            end
            last_path_recalculation = current_time
        end

        local current_time = get_time_since_inject()
        
        local distance_to_target = calculate_distance(player_pos, target_position)
        
        -- 检查移动技能冷却状态
        if movement_spell_active and (current_time - last_movement_spell_time) > post_spell_wait_time then
            movement_spell_active = false
            logger.trace("移动技能冷却完成，恢复普通移动")
            
            -- 移动技能冷却结束后，如果没有目标则立即寻找新目标
            if not target_position then
                target_position = find_target(false)
                if target_position then
                    logger.trace("移动技能冷却后重新获得目标")
                end
            end
        end
        
        -- 决策：使用移动技能还是普通移动（仅限探索期间，无敌人时）
        local has_enemies = is_enemies_nearby()
        local has_boss = is_boss_nearby()  -- 检测首领
        local should_use_spell = settings.movement_spell_in_explorer and 
                                not has_enemies and  -- 只在没有敌人时使用移动技能
                                not has_boss and     -- 遇到首领时停止使用移动技能
                                not movement_spell_active  -- 移除距离限制
        
        -- 调试信息
        if settings.movement_spell_in_explorer then
            local ignore_mode = settings.ignore_normal_enemies_for_movement and "忽略普通敌人" or "检测所有敌人"
            local boss_mode = settings.disable_movement_on_boss and "检测首领" or "不检测首领"
            logger.trace(string.format("移动技能检查 - 有敌人:%s, 有首领:%s, 技能激活:%s, 距离:%.1f, 敌人检测模式:%s, 首领检测模式:%s", 
                tostring(has_enemies), 
                tostring(has_boss),
                tostring(movement_spell_active), 
                distance_to_target,
                ignore_mode,
                boss_mode))
        end
        
        if should_use_spell then
            -- 智能选择移动技能目标
            local movement_target = explorer:select_movement_spell_target(player_pos, target_position, current_path, path_index)
            
            if movement_target then
                logger.debug(string.format("尝试使用移动技能，目标距离: %.2f", distance_to_target))
                local spell_success = explorer:movement_spell_to_target(movement_target)
                if spell_success then
                    last_movement_spell_time = current_time
                    movement_spell_active = true
                    logger.debug(string.format("成功使用移动技能，目标距离: %.2f", distance_to_target))
                    -- console.print("🔵 探索传送成功，立即重新生成PATH_1") -- 注释减少输出
                    
                    -- 清除旧路径
                    current_path = nil
                    path_index = 1
                    last_movement_direction = nil
                    
                    -- 保持当前目标，立即重新生成从新位置到目标的路径
                    if target_position then
                        local new_player_pos = get_player_position()
                        local new_path = AStar.find_path(new_player_pos, target_position, {
                            max_iterations = 666,
                            path_angle = math.rad(45),
                            last_movement_direction = nil
                        })
                        if new_path and #new_path > 0 then
                            current_path = new_path
                            path_index = 1
                            -- console.print("✅ 探索传送后立即生成新PATH_1，共" .. #new_path .. "个点")
                        else
                            -- console.print("❌ 探索传送后新PATH_1生成失败，清除目标")
                            target_position = nil
                        end
                    end
                    
                    return -- 本回合结束，下次循环重新规划
                else
                    logger.debug("移动技能使用失败")
                end
            else
                logger.debug("未找到合适的移动技能目标")
            end
        end
        
        -- 普通移动逻辑（仅在未使用移动技能时执行）
        if not movement_spell_active and current_path and current_path[path_index] then
            -- 在普通移动前也检查Alfred状态
            if settings.use_alfred and PLUGIN_alfred_the_butler then
                local alfred_status = PLUGIN_alfred_the_butler.get_status()
                if alfred_status and alfred_status.trigger_tasks then
                    -- Alfred正在执行任务，暂停普通移动
                    return
                end
            end
            
            local next_point = current_path[path_index]
            if next_point and not next_point:is_zero() then
                local new_player_pos = get_player_position()
                if calculate_distance(player_pos, new_player_pos) == 0 then
                    -- console.print("🔴 普通移动到PATH_1: x=" .. next_point:x() .. ", y=" .. next_point:y() .. ", 索引=" .. path_index)
                    pathfinder.request_move(next_point)
                end
            end
        end
        
        -- 路径推进逻辑（仅在普通移动模式下）
        if not movement_spell_active and current_path and current_path[path_index] then
            local next_point = current_path[path_index]
            if next_point and next_point.x and not next_point:is_zero() and calculate_distance(player_pos, next_point) < get_grid_size() then
                local direction = {
                    x = next_point:x() - player_pos:x(),
                    y = next_point:y() - player_pos:y()
                }
                last_movement_direction = direction
                path_index = path_index + 1
                logger.trace(string.format("路径推进到索引: %d", path_index))
            end
        end

        if calculate_distance(player_pos, target_position) < 3 then
            logger.debug("Reached target position")
            mark_area_as_explored(player_pos, get_exploration_circle_radius())
            if current_circle_target then
                current_circle_target.visited = true
                logger.debug("Marked current circle as visited")
            end
            current_circle_target = nil
            target_position = nil
            current_path = {}
            path_index = 1
            target_without_path_start_time = 0.0  -- 重置隔墙检测计时器

            -- Check for nearby unexplored points when in explored mode
            if exploration_mode == "explored" then
                logger.debug("In explored mode, checking for nearby unexplored points")
                local nearby_unexplored_point = find_nearest_unexplored_point(player_pos, get_exploration_circle_radius())
                if nearby_unexplored_point then
                    exploration_mode = "unexplored"
                    target_position = nearby_unexplored_point
                    logger.debug("Found nearby unexplored area. Switching back to unexplored mode.")
                    last_explored_targets = {}
                    current_path = nil
                    path_index = 1
                else
                    logger.debug("No nearby unexplored points, finding new explored target")
                    target_position = find_explored_direction_target()
                end
            else
                logger.debug("Finding new target")
                target_position = find_target(false)
            end
        end
    else
        logger.debug("No target position, finding new target")
        target_position = find_target(false)
        target_without_path_start_time = 0.0  -- 重置隔墙检测计时器
        
        -- 如果找不到目标，寻找未探索区域并使用移动技能
        if not target_position and settings.movement_spell_in_explorer then
            local current_time = get_time_since_inject()
            if not movement_spell_active then
                -- 寻找未探索目标，生成PATH_1
                local unexplored_target = find_central_unexplored_target()
                if unexplored_target then
                    -- 对未探索目标使用移动技能
                    local spell_success = explorer:movement_spell_to_target(unexplored_target)
                    if spell_success then
                        last_movement_spell_time = current_time
                        movement_spell_active = true
                        logger.debug("对未探索区域使用移动技能")
                        
                        -- 设置为当前目标，下次循环会继续处理
                        target_position = unexplored_target
                    end
                end
            end
        end
    end
end


-- 防卡死增强变量
local stuck_retry_count = 0
local max_stuck_retries = 3
local last_stuck_position = nil
local stuck_position_tolerance = 0.5  -- 放宽位置检测

-- 位置防卡死机制：3秒同一位置自动随机移动
local position_stuck_timer = 0
local last_position_check = nil
local position_stuck_threshold = 3.0  -- 3秒阈值
local position_check_radius = 2.0     -- 2单位范围内算同一位置

-- 位置防卡死检查函数
local function check_position_stuck()
    local current_pos = get_player_position()
    local current_game_time = get_time_since_inject()
    
    if not last_position_check then
        last_position_check = current_pos
        position_stuck_timer = current_game_time
        return false
    end
    
    local distance_moved = calculate_distance(current_pos, last_position_check)
    
    -- 如果在2单位范围内（几乎没有移动）
    if distance_moved < position_check_radius then
        -- 检查是否超过3秒
        if current_game_time - position_stuck_timer > position_stuck_threshold then
            logger.debug(string.format("位置卡死检测：%.1f秒未移动超过%.1f单位，触发随机移动", 
                current_game_time - position_stuck_timer, position_check_radius))
            
            -- 重置计时器
            last_position_check = current_pos
            position_stuck_timer = current_game_time
            return true
        end
    else
        -- 有明显移动，重置计时器
        last_position_check = current_pos
        position_stuck_timer = current_game_time
    end
    
    return false
end

local function check_if_stuck()
    --logger.debug("Checking if character is stuck.")
    local current_pos = get_player_position()
    local current_time = os.time()

    -- 增强版卡死检测：位置和重试计数双重判断
    if last_position and calculate_distance(current_pos, last_position) < stuck_position_tolerance then
        if current_time - last_move_time > stuck_threshold then
            stuck_retry_count = stuck_retry_count + 1
            logger.debug(string.format("检测到卡死，重试次数: %d/%d", stuck_retry_count, max_stuck_retries))
            
            -- 连续卡死3次，强制触发解卡
            if stuck_retry_count >= max_stuck_retries then
                logger.debug("连续卡死次数过多，强制解卡")
                stuck_retry_count = 0
                return true
            end
            
            return true
        end
    else
        last_move_time = current_time
        stuck_retry_count = 0  -- 重置重试计数
    end

    last_position = current_pos
    return false
end

explorer.check_if_stuck = check_if_stuck

function explorer:set_custom_target(target)
    --logger.debug("Setting custom target.")
    target_position = target
end

-- 智能选择移动技能目标
function explorer:select_movement_spell_target(player_pos, final_target, path, current_index)
    if not player_pos or not final_target then
        return nil
    end
    
    local distance_to_final = calculate_distance(player_pos, final_target)
    
    -- 计算到最终目标的方向向量
    local final_direction = {
        x = final_target:x() - player_pos:x(),
        y = final_target:y() - player_pos:y()
    }
    local final_length = math.sqrt(final_direction.x^2 + final_direction.y^2)
    if final_length > 0 then
        final_direction.x = final_direction.x / final_length
        final_direction.y = final_direction.y / final_length
    end
    
    -- 如果路径存在且足够长，选择路径上向前的点
    if path and #path > current_index + 1 then        
        for i = current_index + 1, #path do
            local point = path[i]
            if point then
                local dist_to_point = calculate_distance(player_pos, point)
                
                -- 移除距离限制，任何距离都可以使用
                if dist_to_point >= 1 then  -- 只要不是太近（1单位以上）
                    -- 计算到这个点的方向向量
                    local point_direction = {
                        x = point:x() - player_pos:x(),
                        y = point:y() - player_pos:y()
                    }
                    local point_length = math.sqrt(point_direction.x^2 + point_direction.y^2)
                    if point_length > 0 then
                        point_direction.x = point_direction.x / point_length
                        point_direction.y = point_direction.y / point_length
                    end
                    
                    -- 检查方向是否朝向最终目标（点积 > 0.5，即角度 < 60度）
                    local dot_product = final_direction.x * point_direction.x + final_direction.y * point_direction.y
                    if dot_product > 0.5 then
                        logger.trace(string.format("选择路径点[%d]作为移动目标，距离: %.2f，方向匹配度: %.2f", i, dist_to_point, dot_product))
                        return point
                    end
                end
            end
        end
    end
    
    -- 如果路径不适合，但最终目标距离合适，使用最终目标（移除距离限制）
    if distance_to_final >= 1 then  -- 只要不是太近（1单位以上）
        logger.trace(string.format("使用最终目标，距离: %.2f", distance_to_final))
        return final_target
    end
    
    -- 都不合适，不使用移动技能
    logger.trace("没有找到合适的移动技能目标")
    return nil
end


-- 防卡死移动变量
local movement_spell_failures = 0
local max_movement_failures = 3
local last_movement_fail_time = 0
local movement_cooldown = 0.5

function explorer:movement_spell_to_target(target)
    local local_player = get_local_player()
    if not local_player then return false end
    
    -- 检查Alfred插件是否正在运行，避免移动技能冲突
    if settings.use_alfred and PLUGIN_alfred_the_butler then
        local alfred_status = PLUGIN_alfred_the_butler.get_status()
        if alfred_status and alfred_status.trigger_tasks then
            logger.trace("Alfred正在运行，暂停使用移动技能")
            return false
        end
    end
    
    -- 移动技能冷却检查（防卡死机制1）
    local current_time = get_time_since_inject()
    if current_time - last_movement_fail_time < movement_cooldown then
        logger.trace("移动技能冷却中，跳过此次尝试")
        return false
    end
    
    -- 如果没有目标，直接返回失败（调用方应该提供目标）
    if not target then
        return false
    end

    local player_pos = get_player_position()
    local target_distance = calculate_distance(player_pos, target)
    
    -- 移除距离检查限制，只要目标存在且不是太近就可以使用
    if target_distance < 1 then
        logger.trace(string.format("移动技能目标距离太近: %.2f (小于1单位)", target_distance))
        return false
    end

    local movement_spell_id = {}
    
    -- 纯探索移动技能（无敌人时使用）
    if settings.use_evade_as_movement_spell then
        table.insert(movement_spell_id, 337031) -- General Evade
    end

    if settings.use_teleport then
        table.insert(movement_spell_id, 288106) -- Sorceror Teleport
    end

    if settings.use_teleport_enchanted then
        table.insert(movement_spell_id, 959728) -- Sorceror Teleport Enchanted
    end

    if settings.use_dash then
        table.insert(movement_spell_id, 358761) -- Rogue Dash
    end

    if settings.use_shadow_step then
        table.insert(movement_spell_id, 355606) -- Rogue Shadow Step
    end

    if settings.use_the_hunter then
        table.insert(movement_spell_id, 1663206) -- Spiritborn The Hunter
    end

    if settings.use_soar then
        table.insert(movement_spell_id, 1871821) -- Spiritborn Soar
    end

    if settings.use_rushing_claw then
        table.insert(movement_spell_id, 1871761) -- Spiritborn Rushing Claw
    end

    if settings.use_leap then
        table.insert(movement_spell_id, 196545) -- Barbarian Leap
    end
    

    -- 检查移动技能冷却并尝试使用
    for _, spell_id in ipairs(movement_spell_id) do
        if local_player:is_spell_ready(spell_id) then
            local success = false
            
            -- 特殊处理附魔传送
            if spell_id == spell_id_teleport_enchanted then
                -- 检查orbwalker模式（参考原版逻辑）
                local current_orb_mode = orbwalker.get_orb_mode()
                if current_orb_mode ~= orb_mode.none then
                    -- 使用cast_spell.position，参考原版的调用方式
                    success = cast_spell.position(spell_id, target, 0.5)
                    if success then
                        logger.trace(string.format("成功使用附魔传送，目标距离: %.2f", target_distance))
                        -- console.print("Casted Teleport Enchantment for movement")
                    end
                else
                    logger.trace("附魔传送：orbwalker模式为none，跳过")
                end
            else
                -- 其他移动技能使用标准方式
                success = cast_spell.position(spell_id, target, 1.5)
                if success then
                    logger.trace(string.format("成功使用移动技能 %d，目标距离: %.2f", spell_id, target_distance))
                end
            end
            
            if success then
                -- 传送成功后立即从新位置重新生成PATH_1
                -- console.print("🔵 传送成功，立即重新生成PATH_1") -- 注释减少输出
                
                -- 清除旧路径
                current_path = nil
                path_index = 1
                last_movement_direction = nil
                
                -- 保持当前目标，立即重新生成从新位置到目标的路径
                if target then
                    local new_player_pos = get_player_position()
                    local new_path = AStar.find_path(new_player_pos, target, {
                        max_iterations = 666,
                        path_angle = math.rad(45),
                        last_movement_direction = nil
                    })
                    if new_path and #new_path > 0 then
                        current_path = new_path
                        path_index = 1
                        -- console.print("✅ 立即生成新PATH_1，共" .. #new_path .. "个点")
                    else
                        -- console.print("❌ 新PATH_1生成失败，清除目标")
                        target_position = nil
                    end
                end
                
                return true
            end
        end
    end
    
    return false
end

-- Expose the move_to_target function
function explorer:move_to_target()
    move_to_target()
end

-- Update the draw_explored_area_bounds function
local function draw_explored_area_bounds()
    for _, circle in ipairs(explored_circles) do
        graphics.circle_3d(circle.center, circle.radius, color_orange(255))
    end
end

local last_call_time = 0.0
local is_player_in_pit = false

-- Move this function definition up, before on_update
local function check_and_create_circle()
    local current_time = get_time_since_inject()
    local player_pos = get_player_position()
    
    logger.debug(string.format("Current player position: (%.2f, %.2f, %.2f)", 
        player_pos:x(), player_pos:y(), player_pos:z()))
    
    if last_circle_position then
        logger.debug(string.format("Last circle position: (%.2f, %.2f, %.2f)", 
            last_circle_position.x, last_circle_position.y, last_circle_position.z))
        local distance = calculate_distance(player_pos, last_circle_position)
        local time_diff = current_time - last_circle_time
        logger.debug(string.format("Distance from last circle: %.2f, Time since last circle: %.2f seconds", 
            distance, time_diff))
    else
        logger.debug("No previous circle created yet")
    end
    
    if not last_circle_position or 
       (calculate_distance(player_pos, last_circle_position) >= min_distance_between_circles and
        current_time - last_circle_time >= min_time_between_circles) then
        
        local circle_radius = get_exploration_circle_radius()
        logger.debug(string.format("创建探索圈 - 半径: %d单位", circle_radius))
        mark_area_as_explored(player_pos, circle_radius)
        
        last_circle_position = {
            x = player_pos:x(), 
            y = player_pos:y(), 
            z = player_pos:z()
        }
        last_circle_time = current_time
    else
        logger.debug("Not enough distance or time has passed to create a new circle")
    end
end

on_update(function()
    if not settings.enabled then
        return
    end

    if tracker:is_boss_task_running() or explorer.current_task == "Stupid Ladder" then
        return -- Don't run explorer logic if the boss task or stupid ladder is running
    end

    local world = world.get_current_world()
    if world then
        local world_name = world:get_name()
        if world_name:match("Sanctuary") or world_name:match("Limbo") then
            return
        end
    end

    local current_core_time = get_time_since_inject()
    if current_core_time - last_call_time > 1.0 then  -- 降低调用频率从0.85秒到1秒
        last_call_time = current_core_time
        is_player_in_pit = (utils.player_in_zone("EGD_MSWK_World_02") or utils.player_in_zone("EGD_MSWK_World_01")) and settings.enabled
        if not is_player_in_pit then
            return
        end

        --logger.debug("Calling check_walkable_area")
        check_walkable_area()
        check_and_create_circle()
        
        -- 位置防卡死检查（优先级最高）
        local is_position_stuck = check_position_stuck()
        if is_position_stuck then
            logger.debug("触发位置防卡死：3秒未移动，寻找随机目标重新识别路径")
            target_position = find_random_nearby_target()
            if target_position then
                target_position = set_height_of_valid_position(target_position)
                current_path = {}  -- 清空当前路径，强制重新计算
                path_index = 1
                last_move_time = os.time()
                logger.debug("位置防卡死：设置新的随机目标，清空路径缓存")
            end
        end
        
        -- 原有卡死检查（作为备用）
        local is_stuck = check_if_stuck()
        if is_stuck then
            --logger.debug("Character was stuck. Finding new target and attempting revive")
            target_position = find_target(true)
            target_position = set_height_of_valid_position(target_position)
            last_move_time = os.time()
            current_path = {}
            path_index = 1

            local local_player = get_local_player()
            if local_player and local_player:is_dead() then
                revive_at_checkpoint()
            else
                -- Attempt to use a movement spell to the new target
                explorer:movement_spell_to_target(target_position)
            end
        end
    end

    if current_core_time - last_call_time > 0.15 then
        explorer:check_start_location_reached()

        if not explorer.start_location_reached and explorer:set_start_location_target() then
            explorer:move_to_target()
        else
            -- Regular exploration logic
            explorer:move_to_target()
        end
    end

    check_pit_time()
    check_and_reset_dungeons()
    
    -- 【新增】：定期性能报告
    explorer.report_performance()
end)

on_render(function()
    if not settings.enabled then
        return
    end

    -- dont slide frames here so drawings feel smooth
    if target_position then
        if target_position.x then
            graphics.text_3d("TARGET_1", target_position, 20, color_red(255))
        else
            if target_position and target_position:get_position() then
                graphics.text_3d("TARGET_2", target_position:get_position(), 20, color_orange(255))
            end
        end
    end

    -- 性能优化：只渲染关键路径点，避免绘制整个路径
    if current_path and #current_path > 0 then
        local current_point = current_path[path_index]
        if current_point then
            graphics.text_3d("PATH_1", current_point, 15, color_green(255))
        end
        
        -- 只显示下一个路径点
        local next_point = current_path[math.min(path_index + 1, #current_path)]
        if next_point and next_point ~= current_point then
            graphics.text_3d("PATH_1", next_point, 15, color_yellow(255))
        end
    end

    graphics.text_2d("Mode: " .. exploration_mode, vec2:new(10, 10), 20, color_white(255))

    -- Add this line to draw the explored area bounds
    draw_explored_area_bounds()
end)


-- 重复的check_and_create_circle函数定义已移除 - 使用第1264行的版本


function explorer.clear_explored_circles()
    explored_circles = {}
    logger.debug("Cleared all explored circles")
end

-- 【新增】：性能监控和统计函数
function explorer.get_performance_stats()
    local cache_stats = optimized_functions.get_cache_stats()
    return {
        exploration_cache = cache_stats,
        total_circles = #explored_circles,
        current_mode = exploration_mode,
        optimization_enabled = true
    }
end

-- 【新增】：定期性能报告
local last_performance_report = 0
function explorer.report_performance()
    local current_time = get_time_since_inject()
    
    -- 每60秒报告一次性能
    if current_time - last_performance_report > 60 then
        local stats = explorer.get_performance_stats()
        logger.info("=== 探索系统性能报告 ===")
        logger.info(string.format("缓存格子数: %d, 内存使用: %.1fMB", 
            stats.exploration_cache.total_cells, stats.exploration_cache.memory_mb))
        logger.info(string.format("缓存命中率: %.1f%%, 圆圈总数: %d", 
            stats.exploration_cache.hit_rate, stats.total_circles))
        logger.info(string.format("当前模式: %s, 优化状态: %s", 
            stats.current_mode, stats.optimization_enabled and "启用" or "禁用"))
        logger.info("===========================")
        
        last_performance_report = current_time
    end
end

-- 【新增】：切换调试模式（用于性能对比测试）
local use_optimized_cache = true
function explorer.toggle_optimization_mode()
    use_optimized_cache = not use_optimized_cache
    logger.info("探索优化模式: " .. (use_optimized_cache and "启用" or "禁用"))
    
    if use_optimized_cache then
        -- 切换回优化版本
        is_point_in_explored_area = function(point)
            return optimized_functions.is_point_in_explored_area(point)
        end
    else
        -- 切换回原始版本（性能对比测试用）
        is_point_in_explored_area = is_point_in_explored_area_original
    end
    
    return use_optimized_cache
end

return explorer
