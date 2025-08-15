local CooldownGuard = {
    spell_timers = {},
    locked_until = 0
}

-- Checks whether a spell can be cast and updates timers when allowed.
-- @param spell_id number
-- @param cooldown number|nil optional cooldown to apply if cast succeeds
-- @return boolean
function CooldownGuard:can_cast(spell_id, cooldown)
    local now = get_time_since_inject()
    local ready_time = self.spell_timers[spell_id] or 0
    if now < ready_time or now < self.locked_until then
        return false
    end
    if cooldown then
        self.spell_timers[spell_id] = now + cooldown
    end
    return true
end

-- Locks movement for the given duration in seconds.
-- @param duration number
function CooldownGuard:lock_movement(duration)
    local now = get_time_since_inject()
    local lock_until = now + (duration or 0)
    if lock_until > self.locked_until then
        self.locked_until = lock_until
    end
end

return CooldownGuard
