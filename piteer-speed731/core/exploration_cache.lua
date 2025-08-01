-- 高性能探索缓存系统
-- 用于替换线性搜索的O(1)探索区域检测
-- 针对高速移动优化：快速+精确

local logger = require "core.logger"

local ExplorationCache = {}
ExplorationCache.__index = ExplorationCache

-- 缓存配置
local CACHE_CONFIG = {
    cell_size = 1,          -- 网格精度：1单位 (几乎无精度损失)
    enable_stats = true,    -- 启用性能统计
    cleanup_interval = 30,  -- 清理间隔（秒）
    max_memory_mb = 200     -- 最大内存限制（MB）
}

function ExplorationCache:new()
    local obj = {
        -- 主缓存网格
        grid = {},
        
        -- 性能统计
        stats = {
            cache_hits = 0,
            cache_misses = 0,
            total_cells = 0,
            memory_usage_mb = 0,
            last_cleanup = 0
        },
        
        -- 配置
        cell_size = CACHE_CONFIG.cell_size,
        initialized = true,
        
        -- 边界追踪
        bounds = {
            min_x = math.huge,
            max_x = -math.huge,
            min_y = math.huge,
            max_y = -math.huge
        }
    }
    
    setmetatable(obj, ExplorationCache)
    logger.info("ExplorationCache初始化完成，网格精度: " .. obj.cell_size)
    return obj
end

-- 生成缓存键
function ExplorationCache:get_cache_key(x, y)
    return math.floor(x / self.cell_size) .. "," .. math.floor(y / self.cell_size)
end

-- 添加探索圆圈到缓存
function ExplorationCache:add_exploration_circle(center, radius)
    local start_time = get_time_since_inject()
    local cells_added = 0
    
    -- 计算需要检查的边界
    local min_x = center:x() - radius
    local max_x = center:x() + radius
    local min_y = center:y() - radius
    local max_y = center:y() + radius
    
    -- 高精度遍历每个可能的网格
    for x = min_x, max_x, self.cell_size do
        for y = min_y, max_y, self.cell_size do
            -- 计算网格中心点
            local cell_center_x = x + self.cell_size / 2
            local cell_center_y = y + self.cell_size / 2
            
            -- 计算距离（优化：避免sqrt，直接比较平方）
            local dx = cell_center_x - center:x()
            local dy = cell_center_y - center:y()
            local distance_sq = dx * dx + dy * dy
            local radius_sq = radius * radius
            
            if distance_sq <= radius_sq then
                local key = self:get_cache_key(x, y)
                if not self.grid[key] then
                    self.grid[key] = true
                    cells_added = cells_added + 1
                    
                    -- 更新边界
                    self.bounds.min_x = math.min(self.bounds.min_x, x)
                    self.bounds.max_x = math.max(self.bounds.max_x, x)
                    self.bounds.min_y = math.min(self.bounds.min_y, y)
                    self.bounds.max_y = math.max(self.bounds.max_y, y)
                end
            end
        end
    end
    
    -- 更新统计信息
    self.stats.total_cells = self.stats.total_cells + cells_added
    local cache_time = get_time_since_inject() - start_time
    
    logger.debug(string.format("缓存探索圆圈: 中心(%.1f,%.1f) 半径%.1f, 新增%d格子, 耗时%.3fms", 
        center:x(), center:y(), radius, cells_added, cache_time * 1000))
    
    -- 定期内存清理检查
    self:check_memory_usage()
end

-- 检查位置是否已探索（超快查询）
function ExplorationCache:is_position_explored(position)
    local key = self:get_cache_key(position:x(), position:y())
    local is_explored = self.grid[key] == true
    
    -- 更新统计
    if CACHE_CONFIG.enable_stats then
        if is_explored then
            self.stats.cache_hits = self.stats.cache_hits + 1
        else
            self.stats.cache_misses = self.stats.cache_misses + 1
        end
    end
    
    return is_explored
end

-- 批量检查多个位置（进一步优化）
function ExplorationCache:batch_check_positions(positions)
    local results = {}
    local batch_start = get_time_since_inject()
    
    for i, position in ipairs(positions) do
        results[i] = self:is_position_explored(position)
    end
    
    local batch_time = get_time_since_inject() - batch_start
    logger.trace(string.format("批量检查%d个位置，耗时%.3fms", #positions, batch_time * 1000))
    
    return results
end

-- 获取探索区域边界
function ExplorationCache:get_explored_bounds()
    return {
        min_x = self.bounds.min_x,
        max_x = self.bounds.max_x,
        min_y = self.bounds.min_y,
        max_y = self.bounds.max_y,
        width = self.bounds.max_x - self.bounds.min_x,
        height = self.bounds.max_y - self.bounds.min_y
    }
end

-- 内存使用检查
function ExplorationCache:check_memory_usage()
    local current_time = get_time_since_inject()
    
    -- 每30秒检查一次
    if current_time - self.stats.last_cleanup < CACHE_CONFIG.cleanup_interval then
        return
    end
    
    -- 估算内存使用（每个缓存条目约8字节）
    local estimated_memory_mb = (self.stats.total_cells * 8) / (1024 * 1024)
    self.stats.memory_usage_mb = estimated_memory_mb
    self.stats.last_cleanup = current_time
    
    logger.debug(string.format("探索缓存统计: %d格子, %.1fMB内存, 命中率%.1f%%", 
        self.stats.total_cells, 
        estimated_memory_mb,
        self:get_hit_rate()))
    
    -- 内存超限警告
    if estimated_memory_mb > CACHE_CONFIG.max_memory_mb then
        logger.warn(string.format("探索缓存内存使用过高: %.1fMB > %dMB", 
            estimated_memory_mb, CACHE_CONFIG.max_memory_mb))
    end
end

-- 获取缓存命中率
function ExplorationCache:get_hit_rate()
    local total_queries = self.stats.cache_hits + self.stats.cache_misses
    if total_queries == 0 then return 0 end
    return (self.stats.cache_hits / total_queries) * 100
end

-- 获取性能统计
function ExplorationCache:get_performance_stats()
    return {
        total_cells = self.stats.total_cells,
        memory_mb = self.stats.memory_usage_mb,
        hit_rate = self:get_hit_rate(),
        cache_hits = self.stats.cache_hits,
        cache_misses = self.stats.cache_misses,
        bounds = self:get_explored_bounds()
    }
end

-- 清空缓存（重置时使用）
function ExplorationCache:clear()
    self.grid = {}
    self.stats.total_cells = 0
    self.stats.cache_hits = 0
    self.stats.cache_misses = 0
    self.bounds = {
        min_x = math.huge,
        max_x = -math.huge,
        min_y = math.huge,
        max_y = -math.huge
    }
    logger.info("探索缓存已清空")
end

-- 导出优化后的函数供外部使用
function ExplorationCache:create_optimized_functions()
    local cache = self
    
    return {
        -- 替换 mark_area_as_explored
        mark_area_as_explored = function(center, radius)
            cache:add_exploration_circle(center, radius)
        end,
        
        -- 替换 is_point_in_explored_area  
        is_point_in_explored_area = function(point)
            return cache:is_position_explored(point)
        end,
        
        -- 新增：批量检查
        batch_check_explored = function(points)
            return cache:batch_check_positions(points)
        end,
        
        -- 新增：获取统计信息
        get_cache_stats = function()
            return cache:get_performance_stats()
        end,
        
        -- 新增：清空缓存
        reset_cache = function()
            cache:clear()
        end
    }
end

-- 调试功能：可视化缓存状态
function ExplorationCache:debug_visualize_cache()
    if not CACHE_CONFIG.enable_stats then return end
    
    local bounds = self:get_explored_bounds()
    logger.debug("=== 探索缓存可视化 ===")
    logger.debug(string.format("探索范围: (%.1f,%.1f) 到 (%.1f,%.1f)", 
        bounds.min_x, bounds.min_y, bounds.max_x, bounds.max_y))
    logger.debug(string.format("区域大小: %.1f × %.1f", bounds.width, bounds.height))
    logger.debug(string.format("缓存密度: %.1f格子/平方单位", 
        self.stats.total_cells / (bounds.width * bounds.height)))
end

return ExplorationCache