local CooldownGuard = {
    spell_end_time = 0.0,
    move_end_time = 0.0
}

function CooldownGuard:can_act()
    local now = get_time_since_inject()
    return now >= self.spell_end_time and now >= self.move_end_time
end

function CooldownGuard:on_spell_cast(duration)
    local now = get_time_since_inject()
    local end_time = now + (duration or 0)
    if end_time > self.spell_end_time then
        self.spell_end_time = end_time
    end
end

function CooldownGuard:on_movement(duration)
    local now = get_time_since_inject()
    local end_time = now + (duration or 0)
    if end_time > self.move_end_time then
        self.move_end_time = end_time
    end
end

return CooldownGuard
