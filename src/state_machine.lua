local StateMachine = {}
StateMachine.__index = StateMachine

---Create a new state machine.
---@param guard table cooldown guard instance
function StateMachine:new(guard)
    return setmetatable({
        state = "idle",
        guard = guard
    }, self)
end

---Get current state.
function StateMachine:get_state()
    return self.state
end

---Attempt to cast a spell, transitioning state when successful.
---@param spell_id number
---@return boolean
function StateMachine:try_cast(spell_id)
    -- Check for player context; stubbed in tests
    get_local_player()
    if not self.guard:is_ready() then
        return false
    end

    if cast_spell.self(spell_id, 0.0) then
        self.guard:use()
        self.state = "casting"
        return true
    end
    return false
end

---Update the state machine based on cooldown.
function StateMachine:update()
    if self.state == "casting" and self.guard:is_ready() then
        self.state = "idle"
    end
end

return StateMachine
