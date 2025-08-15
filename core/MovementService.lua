local pathfinder = require("pathfinder")
local CooldownGuard = require("core/CooldownGuard")

local MovementService = {}

-- Moves to a position if movement is not locked.
-- @param position vec3
-- @return boolean
function MovementService.move_to(position)
    local now = get_time_since_inject()
    if now < CooldownGuard.locked_until then
        return false
    end
    return pathfinder.request_move(position)
end

return MovementService
