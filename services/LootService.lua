local loot_manager = require("loot_manager")
local MovementService = require("services.MovementService")

local LootService = {}

function LootService:get_lootables()
    return loot_manager.get_all_items_and_chest_sorted_by_distance()
end

function LootService:tick()
    if MovementService:is_busy() then
        local lootables = self:get_lootables()
        if lootables and #lootables > 0 then
            loot_manager.loot_item_orbwalker(lootables[1])
        end
    end
end

return LootService

