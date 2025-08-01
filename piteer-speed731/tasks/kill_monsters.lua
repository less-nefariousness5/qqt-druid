local utils      = require "core.utils"
local enums      = require "data.enums"
local settings   = require "core.settings"
local navigation = require "core.navigation"
local explorer   = require "core.explorer"
local MovementService = require "core.MovementService"
local logger     = require "core.logger"

local stuck_position = nil

local task = {
    name = "击杀怪物",
    shouldExecute = function()
        local traversal_controller = utils.get_object_by_name(enums.misc.traversal_controller)
        if traversal_controller ~= nil then
            return false
        end

        local close_enemy = utils.get_closest_enemy()
        return close_enemy ~= nil
    end,
    Execute = function()
        explorer.current_task = "击杀怪物"
        local player_pos = get_player_position()

        if explorer.check_if_stuck() then
            -- Log the stuck position
            stuck_position = player_pos
            return false
        end

        if stuck_position and utils.distance_to(stuck_position) < 25 then
            -- Player is still within 10 units of the stuck position, do not resume
            return false
        else
            -- Clear the stuck position once the player has moved 10+ units away
            stuck_position = nil
        end

        local distance_check = settings.melee_logic and 2 or 6.5
        local enemy = utils.get_closest_enemy()
        if not enemy then return false end

        local within_distance = utils.distance_to(enemy) < distance_check

        if not within_distance then
            -- 使用MovementService进行统一的移动管理
            MovementService.move_to_object(enemy, distance_check)
            logger.debug("移动到敌人位置，距离: " .. string.format("%.2f", utils.distance_to(enemy)))
        else
            if settings.melee_logic then
                local enemy_pos = enemy:get_position()
                local melee_position = enemy_pos:get_extended(player_pos, -1.0)
                MovementService.move_to_position(melee_position)
                logger.debug("近战模式：移动到敌人背后位置")
            else
                -- 远程模式：保持当前位置
                logger.trace("远程模式：保持距离攻击")
            end
        end
        explorer.current_task = nil
    end
}

return task