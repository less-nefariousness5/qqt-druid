local PathingService = {}

--- Moves the player using the internal pathfinder.
-- @param pos vec3 Destination position
-- @return boolean success
function PathingService:move_to(pos)
    if not pos then
        return false
    end
    return pathfinder.move_to_cpathfinder(pos)
end

--- Forces a movement command to the given position.
-- @param pos vec3
-- @return boolean
function PathingService:force_move(pos)
    if not pos then
        return false
    end
    return pathfinder.force_move(pos)
end

--- Issues a non-blocking move request.
-- @param pos vec3
function PathingService:request_move(pos)
    if not pos then
        return
    end
    pathfinder.request_move(pos)
end

--- Clears any cached pathing information.
function PathingService:clear_path()
    pathfinder.clear_stored_path()
end

return PathingService

