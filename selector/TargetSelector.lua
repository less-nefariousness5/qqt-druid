local api_selector = require("target_selector")
local prediction = require("prediction")

local TargetSelector = {}

local cached_scan = {
    time = 0.0,
    range = 0.0,
    list = {}
}

local CACHE_DURATION = 0.1

local function scan_targets(source, range)
    local now = get_time_since_inject()
    if now - cached_scan.time > CACHE_DURATION or range ~= cached_scan.range then
        cached_scan.list = api_selector.get_near_target_list(source, range) or {}
        cached_scan.time = now
        cached_scan.range = range
    end
    return cached_scan.list
end

local function passes_filters(unit, source, collision, floor, angle)
    if unit:get_skin_name() == "S05_BSK_Rogue_001_Clone" then
        return false
    end

    local unit_pos = unit:get_position()

    if collision and collision.is_enabled then
        if prediction.is_wall_collision(source, unit_pos, collision.width) then
            return false
        end
    end

    if floor and floor.is_enabled then
        local x_difference = math.abs(source.x() - unit_pos.x())
        if x_difference > floor.height then
            return false
        end
    end

    if angle and angle.is_enabled then
        local cursor_position = cursor_pos()
        local angle_value = unit_pos.angle(cursor_position, source)
        if angle_value > angle.max_angle then
            return false
        end
    end

    return true
end

--- Returns a filtered list of targets around the source.
--- @param source vec3
--- @param range number
--- @param collision table
--- @param floor table
--- @param angle table
--- @return game.object[]
function TargetSelector.get_target_list(source, range, collision, floor, angle)
    local list = {}
    for _, unit in ipairs(scan_targets(source, range)) do
        if passes_filters(unit, source, collision, floor, angle) then
            table.insert(list, unit)
        end
    end
    return list
end

--- Calculates weight for a given target for AOE decisions.
--- @param target game.object
--- @return number
function TargetSelector.weighted(target)
    local base = 1
    if target:is_boss() then
        base = base + 10
    elseif target:is_elite() then
        base = base + 4
    elseif target:is_champion() then
        base = base + 2
    end

    local pos = target:get_position()
    local count = 0
    for _, other in ipairs(cached_scan.list) do
        if other ~= target then
            local other_pos = other:get_position()
            if other_pos:squared_dist_to_ignore_z(pos) <= (5 * 5) then
                count = count + 1
            end
        end
    end
    return base + count
end

--- Selects the best target based on weight.
--- @param source vec3
--- @param range number
--- @param collision table
--- @param floor table
--- @param angle table
--- @return game.object|nil
function TargetSelector.get_best_target(source, range, collision, floor, angle)
    local candidates = TargetSelector.get_target_list(source, range, collision, floor, angle)
    local best, best_weight
    for _, unit in ipairs(candidates) do
        local w = TargetSelector.weighted(unit)
        if not best or w > best_weight then
            best, best_weight = unit, w
        end
    end
    return best
end

return TargetSelector

