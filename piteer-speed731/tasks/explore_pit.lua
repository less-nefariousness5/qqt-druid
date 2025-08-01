local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local tracker = require "core.tracker"

local task  = {
    name = "探索深坑",
    shouldExecute = function()
        return utils.player_in_zone("EGD_MSWK_World_02") or utils.player_in_zone("EGD_MSWK_World_01")
    end,
    Execute = function()
        if not explorer.is_task_running then
            explorer.enabled = true
            tracker:set_boss_task_running(false)   
        end
    end
}
return task
