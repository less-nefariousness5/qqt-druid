local pathfinder = require("pathfinder")

local ok_path, PathingService = pcall(require, "services.PathingService")
if not ok_path then
    PathingService = {
        move_to = function(_, pos)
            return pathfinder.move_to_cpathfinder(pos)
        end,
        stop = function() end,
    }
end

local ok_cd, CooldownGuard = pcall(require, "services.CooldownGuard")
if not ok_cd then
    CooldownGuard = {
        is_locked = function() return false end,
        lock = function() end,
    }
end

local MovementService = {}
MovementService.__index = MovementService

MovementService.SHORT_HOP_DIST = 6.0
MovementService.DASH_THROTTLE = 0.75

function MovementService.new()
    return setmetatable({ _last_dash = 0 }, MovementService)
end

function MovementService:move_to(dest)
    if CooldownGuard.is_locked("move") then
        return false
    end
    local player = get_local_player()
    if not player then
        return false
    end
    local current_pos = player:get_position()
    if current_pos:dist_to(dest) > self.SHORT_HOP_DIST then
        return PathingService:move_to(dest)
    else
        return pathfinder.force_move_raw(dest)
    end
end

function MovementService:dash_if_ready(dest)
    if CooldownGuard.is_locked("dash") then
        return false
    end
    local now = os.clock()
    if now - self._last_dash < self.DASH_THROTTLE then
        return false
    end
    local ok = pathfinder.force_move_raw(dest)
    if ok then
        self._last_dash = now
        CooldownGuard.lock("dash", self.DASH_THROTTLE)
    end
    return ok
end

function MovementService:stop()
    PathingService:stop()
    local player = get_local_player()
    if player then
        pathfinder.force_move_raw(player:get_position())
    end
end

return MovementService

