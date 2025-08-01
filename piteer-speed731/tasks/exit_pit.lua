local utils      = require "core.utils"
local enums      = require "data.enums"
local tracker    = require "core.tracker"
local explorer   = require "core.explorer"
local settings   = require "core.settings"

local last_reset = get_time_since_inject()
local cooldown_period = 60 -- 60 seconds cooldown
local first_run = true

local task = {
    name = "退出深坑",
    shouldExecute = function()
        -- 检查finish_pit任务是否存在等待状态
        local finish_pit_task = require("tasks.finish_pit")
        if finish_pit_task and finish_pit_task.is_waiting and finish_pit_task.is_waiting() then
            -- 如果finish_pit正在等待，则不执行exit_pit
            return false
        end
        
        return settings.exit_pit_enabled and
               utils.get_object_by_name(enums.misc.gizmo_paragon_glyph_upgrade) ~= nil and
               not utils.get_pit_portal()
    end,
    Execute = function()
        console.print("正在执行任务：退出深坑。")
        explorer.is_task_running = true
        explorer:clear_path_and_target()

        if first_run then
            console.print("首次运行退出深坑任务。重置tracker.finished_time为当前时间。")
            tracker.finished_time = get_time_since_inject()
            first_run = false
        end

        local current_time = get_time_since_inject()
        local time_since_finish = current_time - tracker.finished_time
        local time_since_last_reset = current_time - last_reset

        console.print("调试：当前时间：" .. current_time)
        console.print("调试：tracker.finished_time：" .. tracker.finished_time)
        console.print("调试：完成后时间：" .. time_since_finish)
        console.print("调试：上次重置后时间：" .. time_since_last_reset)

        if time_since_finish > 40 then
            if time_since_last_reset > cooldown_period then
                last_reset = current_time
                reset_all_dungeons()
                console.print("在时间点重置所有地牢：" .. current_time)
            else
                console.print("冷却时间未到。跳过重置。剩余时间：" .. (cooldown_period - time_since_last_reset))
            end
        else
            console.print("上次完成后时间不足。剩余时间：" .. (40 - time_since_finish))
        end

        explorer.is_task_running = false
    end
}

return task
