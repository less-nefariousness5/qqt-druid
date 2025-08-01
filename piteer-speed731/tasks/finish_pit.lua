local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local settings = require "core.settings"
local tracker = require "core.tracker"

local start_time = 0
local is_waiting = false  -- 添加等待状态标记

local task = {
    name = "完成深坑",
    is_waiting = function() return is_waiting end,  -- 暴露等待状态
    shouldExecute = function()
        --console.print("Checking if Finish Pit task should execute...")
        -- 如果正在等待，继续执行finish_pit任务，阻止其他退出任务
        if is_waiting then
            return true
        end
        
        return settings.exit_pit_enabled and
            utils.get_object_by_name(enums.misc.gizmo_paragon_glyph_upgrade) ~= nil
    end,
    Execute = function()
        console.print("正在执行任务：完成深坑。")
        explorer.is_task_running = true
        explorer:clear_path_and_target()
        
        tracker:set_boss_task_running(true)
        
        local current_time = get_time_since_inject()
        console.print(string.format("当前时间：%.2f，开始时间：%.2f", current_time, start_time))
        
        if start_time == 0 then
            start_time = current_time
            is_waiting = true  -- 开始等待状态
            console.print(string.format("设置开始时间为：%.2f，进入强制等待状态", start_time))
        end

        if current_time - start_time > 100 then
            console.print("超过100秒了。重置任务。")
            start_time = 0
            is_waiting = false  -- 结束等待状态
            explorer.is_task_running = false
            return task
        end

        -- 直接进行强制等待，不处理任何物品
        current_time = get_time_since_inject()
        console.print(string.format("当前时间：%.2f，开始时间：%.2f", current_time, start_time))
        local exit_delay = settings.exit_pit_delay

        -- 强制等待指定时间后退出，不管是否有物品
        if current_time - start_time > exit_delay then
            console.print(exit_delay .. " 秒已过。强制退出副本。")
            start_time = 0
            is_waiting = false  -- 结束等待状态
            explorer.is_task_running = false
            reset_all_dungeons()
            return task
        else
            local timeout = exit_delay - current_time + start_time
            console.print(string.format("*** 强制等待中 - 剩余时间 %.2f 秒 ***", timeout))
            -- 在等待期间阻止其他退出任务执行
            return task
        end
    end
}

return task
