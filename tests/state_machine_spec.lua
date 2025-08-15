local CooldownGuard = require("src.cooldown_guard")
local StateMachine = require("src.state_machine")

describe("StateMachine", function()
    it("transitions with cooldown", function()
        local t = 0
        local function time_fn() return t end
        local guard = CooldownGuard:new(1, time_fn)
        local machine = StateMachine:new(guard)

        local player_called = false
        get_local_player = function()
            player_called = true
            return {}
        end

        local cast_called = false
        cast_spell = {
            self = function(spell_id, anim_time)
                cast_called = true
                return true
            end
        }

        assert.equals("idle", machine:get_state())
        assert.is_true(machine:try_cast(123))
        assert.is_true(player_called)
        assert.is_true(cast_called)
        assert.equals("casting", machine:get_state())

        t = 1.1
        machine:update()
        assert.equals("idle", machine:get_state())
    end)
end)

describe("CooldownGuard", function()
    it("enforces timing", function()
        local t = 0
        local function time_fn() return t end
        local guard = CooldownGuard:new(2, time_fn)
        assert.is_true(guard:is_ready())
        guard:use()
        assert.is_false(guard:is_ready())
        t = 2.1
        assert.is_true(guard:is_ready())
    end)
end)
