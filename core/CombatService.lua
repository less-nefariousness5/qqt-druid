local cast_spell = require("cast_spell")
local CooldownGuard = require("core/CooldownGuard")

local CombatService = {}

-- Attempts to cast a spell on a target using the CooldownGuard.
-- @param target game.object
-- @param spell_id number
-- @param animation_time number
-- @param cooldown number|nil optional cooldown duration for the spell
-- @return boolean
function CombatService.cast(target, spell_id, animation_time, cooldown)
    if not CooldownGuard:can_cast(spell_id, cooldown) then
        return false
    end
    -- Lock movement for duration of animation to avoid interruptions
    if animation_time then
        CooldownGuard:lock_movement(animation_time)
    end
    return cast_spell.target(target, spell_id, animation_time)
end

return CombatService
