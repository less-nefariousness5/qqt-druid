-- Import the spell_data class from the global context
local spell_data_class = _G.spell_data

-- Create a module to hold our spell data
local spell_data_module = {}

-- Function to create spell data objects
function spell_data_module.create_spell_data(radius, range, cast_delay, projectile_speed, has_wall_collision, spell_id, geometry_type, targeting_type)
    return spell_data_class:new(
        radius,
        range,
        cast_delay,
        projectile_speed,
        has_wall_collision,
        spell_id,
        geometry_type or spell_geometry.rectangular,
        targeting_type or targeting_type.skillshot
    )
end

-- Define all spell data
local spell_data = {
    -- active spells
    arc_lash = {
        spell_id = 297902,
        data = spell_data_module.create_spell_data(
            2.0,           -- radius
            3.0,           -- range
            0.8,           -- cast_delay
            1.2,           -- projectile_speed
            true,         -- has_collision
            297902,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    ball = {
        spell_id = 514030,
        data = spell_data_module.create_spell_data(
            0.6,           -- radius
            12.0,          -- range
            0.3,           -- cast_delay
            2.5,           -- projectile_speed
            true,          -- has_collision
            514030,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },        
    blizzard = {
        spell_id = 291403
    },
    chain_lightning = {
        spell_id = 292757,
        data = spell_data_module.create_spell_data(
            0.5,           -- radius
            11.0,          -- range
            2.0,           -- cast_delay
            4.0,           -- projectile_speed
            true,          -- has_collision
            292757,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    charged_bolts = {
        spell_id = 171937,
        data = spell_data_module.create_spell_data(
            1.2,           -- radius
            0.7,          -- range
            1.0,           -- cast_delay
            2.0,          -- projectile_speed
            true,          -- has_collision
            171937,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    deep_freeze = {
        spell_id = 291827,
    },
    evade = {
        spell_id = 337031
    },
    familiars = {
        spell_id = 1627075
    },
    fire_bolt = {
        spell_id = 153249,
        data = spell_data_module.create_spell_data(
            0.7,           -- radius
            20.0,          -- range
            0.0,           -- cast_delay
            4.0,          -- projectile_speed
            true,          -- has_collision
            153249,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    fireball = {
        spell_id = 165023,
        data = spell_data_module.create_spell_data(
            0.7,           -- radius
            12.0,          -- range
            1.6,           -- cast_delay
            2.0,           -- projectile_speed
            true,          -- has_collision
            165023,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    firewall = {
        spell_id = 111422
    },
    flame_shield = {
        spell_id = 167341
    },
    frost_bolt = {
        spell_id = 287256,
        data = spell_data_module.create_spell_data(
            0.7,           -- radius
            12.0,          -- range
            1.0,           -- cast_delay
            3.0,          -- projectile_speed
            true,          -- has_collision
            287256,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    frost_nova = {
        spell_id = 291215
    },
    frozen_orb = {
        spell_id = 291347,
        data = spell_data_module.create_spell_data(
            1.5,           -- radius
            2.0,          -- range
            1.0,           -- cast_delay
            2.5,          -- projectile_speed
            false,          -- has_collision
            291347,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    hydra = {
        spell_id = 146743
    },
    ice_armor = {
        spell_id = 297039
    },
    ice_blade = {
        spell_id = 291492,
    },
    ice_shards = {
        spell_id = 293195,
        data = spell_data_module.create_spell_data(
            0.7,           -- radius
            8.0,          -- range
            2.0,           -- cast_delay
            1.0,          -- projectile_speed
            true,          -- has_collision
            293195,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    incinerate = {
        spell_id = 292737,
        data = spell_data_module.create_spell_data(
            0.7,           -- radius
            8.0,           -- range
            1.6,           -- cast_delay
            2.0,          -- projectile_speed
            true,          -- has_collision
            292737,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    inferno = {
        spell_id = 294198,
        data = spell_data_module.create_spell_data(
            2.0,           -- radius
            6.0,           -- range
            0.3,           -- cast_delay
            0.0,           -- projectile_speed
            false,         -- has_collision
            294198,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    meteor = {
        spell_id = 296998
    },
    spark = {
        spell_id = 143483,
        data = spell_data_module.create_spell_data(
            0.7,           -- radius
            10.0,          -- range
            1.0,           -- cast_delay
            3.5,          -- projectile_speed
            false,          -- has_collision
            143483,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    spear = {
        spell_id = 292074,
    },
    teleport = {
        spell_id = 288106,
        data = spell_data_module.create_spell_data(
            2.5,           -- radius
            10.0,          -- range
            0.3,           -- cast_delay
            0.7,          -- projectile_speed
            false,          -- has_collision
            288106,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    teleport_ench = {
        spell_id = 959728,
        data = spell_data_module.create_spell_data(
            2.5,           -- radius
            10.0,           -- range
            0.3,           -- cast_delay
            0.7,           -- projectile_speed
            false,         -- has_collision
            959728,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    unstable_current = {
        spell_id = 517417
    },
    evade = {
        spell_id = 337031,
        data = spell_data_module.create_spell_data(
            1.0,           -- radius
            8.0,           -- range
            0.2,           -- cast_delay
            5.0,           -- projectile_speed
            false,         -- has_collision
            337031,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },

    -- passives
    -- Would love to implement this but unable to find what the buff_id would be
    -- in_combat_area = {
    --    spell_id = 24312,
    --    buff_id = 24313
    --},
    
    -- enemies
    enemies = {
        damage_resistance = {
            spell_id = 1094180,
            buff_ids = {
                provider = 2771801864,
                receiver = 2182649012
            }
        }
    }
}

-- Merge spell_data_module functions with spell_data for easier access
for k, v in pairs(spell_data_module) do
    spell_data[k] = v
end

return spell_data