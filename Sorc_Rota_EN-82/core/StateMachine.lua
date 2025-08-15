local StateMachine = {}
StateMachine.__index = StateMachine

StateMachine.states = {
    IDLE = {
        enter = function() end,
        update = function() end,
        exit = function() end
    },
    EXPLORE = {
        enter = function() end,
        update = function() end,
        exit = function() end
    },
    ENGAGE = {
        enter = function() end,
        update = function() end,
        exit = function() end
    },
    LOOT = {
        enter = function() end,
        update = function() end,
        exit = function() end
    },
    TOWN = {
        enter = function() end,
        update = function() end,
        exit = function() end
    }
}

function StateMachine.new()
    local self = setmetatable({}, StateMachine)
    self.current = nil
    return self
end

function StateMachine:switch(state_name)
    local next_state = self.states[state_name]
    if not next_state then return end

    if self.current and self.current.exit then
        self.current.exit()
    end

    self.current = next_state

    if self.current.enter then
        self.current.enter()
    end
end

function StateMachine:update(...)
    if self.current and self.current.update then
        self.current.update(...)
    end
end

return StateMachine

