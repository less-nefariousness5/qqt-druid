local PathingService = {}

-- Distance threshold to decide between pathfinder navigation and direct force move
local FORCE_MOVE_THRESHOLD = 3.0

--- Navigate to a position using pathfinder for long distances and force move for short hops.
-- @param pos vec3
-- @return boolean success
function PathingService.navigate(pos)
    local local_player = get_local_player()
    if not local_player or not pos then
        return false
    end

    local player_pos = local_player:get_position()
    local distance = player_pos:dist_to_ignore_z(pos)

    if distance > FORCE_MOVE_THRESHOLD then
        return pathfinder.move_to_cpathfinder(pos)
    else
        return pathfinder.force_move(pos)
    end
end

--- Wrapper for direct long path movement using custom pathfinder.
-- @param pos vec3
-- @return boolean success
function PathingService.move_to(pos)
    return pathfinder.move_to_cpathfinder(pos)
end

--- Wrapper for short force move operations.
-- @param pos vec3
-- @return boolean success
function PathingService.force_move(pos)
    return pathfinder.force_move(pos)
end

return PathingService
