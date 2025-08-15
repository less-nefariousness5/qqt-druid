local CooldownGuard = {}
CooldownGuard.__index = CooldownGuard

---Create a new cooldown guard.
---@param duration number cooldown duration in seconds
---@param time_fn function? optional time provider
function CooldownGuard:new(duration, time_fn)
    return setmetatable({
        duration = duration,
        time_fn = time_fn or os.clock,
        last_time = -math.huge
    }, self)
end

---Check if the guard is ready.
---@return boolean
function CooldownGuard:is_ready()
    return (self.time_fn() - self.last_time) >= self.duration
end

---Mark the cooldown as used.
function CooldownGuard:use()
    self.last_time = self.time_fn()
end

return CooldownGuard
