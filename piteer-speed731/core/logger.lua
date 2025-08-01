-- 高性能Logger模块 - 解决console.print性能问题
-- 使用限速和级别控制来大幅减少不必要的输出

local logger = {}

-- 日志级别
logger.LEVEL = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
    TRACE = 5
}

-- 配置
local config = {
    level = logger.LEVEL.ERROR,  -- 只显示ERROR级别，关闭所有其他日志
    rate_limit = 2.0,           -- 每2秒最多输出一次相同消息
    max_cache = 100,            -- 最多缓存100条消息记录
    enable_debug = false        -- 生产环境关闭debug输出
}

-- 消息缓存和时间记录
local message_cache = {}
local last_output_time = {}
local cache_size = 0

-- 清理过期缓存
local function cleanup_cache()
    if cache_size > config.max_cache then
        local current_time = get_time_since_inject()
        local new_cache = {}
        local new_time_cache = {}
        local new_size = 0
        
        for msg, count in pairs(message_cache) do
            local last_time = last_output_time[msg] or 0
            if current_time - last_time < config.rate_limit * 10 then -- 保留10倍限制时间内的记录
                new_cache[msg] = count
                new_time_cache[msg] = last_time
                new_size = new_size + 1
            end
        end
        
        message_cache = new_cache
        last_output_time = new_time_cache
        cache_size = new_size
    end
end

-- 核心日志函数
local function log(level, message, force_output)
    -- 级别检查
    if level > config.level and not force_output then
        return false
    end
    
    -- Debug模式检查
    if level >= logger.LEVEL.DEBUG and not config.enable_debug and not force_output then
        return false
    end
    
    local current_time = get_time_since_inject()
    local last_time = last_output_time[message] or 0
    
    -- 限速检查
    if not force_output and (current_time - last_time) < config.rate_limit then
        -- 增加消息计数但不输出
        message_cache[message] = (message_cache[message] or 0) + 1
        return false
    end
    
    -- 输出消息
    local count = message_cache[message] or 0
    if count > 1 then
        console.print(message .. " (重复 " .. count .. " 次)")
        message_cache[message] = 0
    else
        console.print(message)
    end
    
    -- 更新时间记录
    last_output_time[message] = current_time
    if not message_cache[message] then
        cache_size = cache_size + 1
    end
    
    -- 定期清理缓存
    if cache_size > config.max_cache then
        cleanup_cache()
    end
    
    return true
end

-- 公共接口函数
function logger.error(message)
    return log(logger.LEVEL.ERROR, "[ERROR] " .. tostring(message), true)
end

function logger.warn(message)
    return log(logger.LEVEL.WARN, "[WARN] " .. tostring(message))
end

function logger.info(message)
    return log(logger.LEVEL.INFO, "[INFO] " .. tostring(message))
end

function logger.debug(message)
    return log(logger.LEVEL.DEBUG, "[DEBUG] " .. tostring(message))
end

function logger.trace(message)
    return log(logger.LEVEL.TRACE, "[TRACE] " .. tostring(message))
end

-- 配置函数
function logger.set_level(level)
    config.level = level
end

function logger.set_debug_mode(enabled)
    config.enable_debug = enabled
end

function logger.set_rate_limit(seconds)
    config.rate_limit = seconds
end

-- 兼容性函数 - 用于替换现有的console.print调用
function logger.print(message)
    return log(logger.LEVEL.INFO, tostring(message))
end

-- 强制输出函数 - 用于重要信息
function logger.force_print(message)
    return log(logger.LEVEL.INFO, tostring(message), true)
end

-- 统计信息
function logger.get_stats()
    return {
        cached_messages = cache_size,
        total_cache_entries = cache_size,
        config = config
    }
end

-- 清理所有缓存
function logger.clear_cache()
    message_cache = {}
    last_output_time = {}
    cache_size = 0
end

return logger