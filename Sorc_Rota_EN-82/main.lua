local local_player = get_local_player();
if local_player == nil then
    return
end

local character_id = local_player:get_character_class_id();
local is_sorc = character_id == 0;
if not is_sorc then
 return
end;

local config = require("ui/menu");
local spell_priority = require("spell_priority");
local spell_data = require("my_utility/spell_data");

local spells =
{
    arc_lash                = require("spells/arc_lash"),
    ball                    = require("spells/ball"),
    blizzard                = require("spells/blizzard"),
    chain_lightning         = require("spells/chain_lightning"),
    charged_bolts           = require("spells/charged_bolts"),
    deep_freeze             = require("spells/deep_freeze"),
    evade                   = require("spells/evade"),
    familiars               = require("spells/familiars"),
    flame_shield            = require("spells/flame_shield"),
    firewall                = require("spells/firewall"),
    fire_bolt               = require("spells/fire_bolt"),
    fireball                = require("spells/fireball"),
    frost_bolt              = require("spells/frost_bolt"),
    frost_nova              = require("spells/frost_nova"),
    frozen_orb              = require("spells/frozen_orb"),
    hydra                   = require("spells/hydra"),
    ice_armor               = require("spells/ice_armor"),
    ice_blade               = require("spells/ice_blade"),
    ice_shards              = require("spells/ice_shards"),
    incinerate              = require("spells/incinerate"),
    inferno                 = require("spells/inferno"),
    meteor                  = require("spells/meteor"),
    spear                   = require("spells/spear"),
    spark                   = require("spells/spark"),
    teleport                = require("spells/teleport"),
    teleport_ench           = require("spells/teleport_ench"),
    unstable_current        = require("spells/unstable_current")
}

local can_move = 0.0;
local cast_end_time = 0.0;

-- 移动技能功能（参考piteer1的movement_spell_to_target）
local function use_movement_spells_to_target(target)
    local local_player = get_local_player()
    if not local_player then return end

    local movement_spell_id = {}

    -- 简化版：直接检查菜单元素状态
    -- 这些菜单元素将通过require的模块访问，但为了避免复杂引用，我们使用简化逻辑
    
    -- 检查闪避技能是否启用且冷却完毕
    if local_player:is_spell_ready(337031) then -- General Evade
        table.insert(movement_spell_id, 337031)
    end

    -- 检查传送技能是否启用且冷却完毕
    if local_player:is_spell_ready(288106) then -- Sorceror Teleport
        table.insert(movement_spell_id, 288106)
    end

    -- 检查传送附魔是否启用且冷却完毕
    if local_player:is_spell_ready(959728) then -- Sorceror Teleport Enchanted
        table.insert(movement_spell_id, 959728)
    end

    -- 检查每个移动技能是否可以施放
    for _, spell_id in ipairs(movement_spell_id) do
        -- 向目标位置施放移动技能
        local success = cast_spell.position(spell_id, target, 0.3) -- 稍微延迟避免过于频繁使用
        if success then
            console.print("[Movement Spell] Successfully used movement spell to target position ID:" .. spell_id)
            break -- 成功使用一个技能后跳出循环
        end
    end
end

local mount_buff_name = "Generic_SetCannotBeAddedToAITargetList";
local mount_buff_name_hash = mount_buff_name;
local mount_buff_name_hash_c = 1923;

local my_utility = require("my_utility/my_utility");
local my_target_selector = require("my_utility/my_target_selector");

-- Reusable tables to avoid per-frame allocations
local collision_table = { true, 1.0 }
local floor_table = { true, 5.0 }
local angle_table = { false, 90.0 }

on_update(function ()

    local local_player = get_local_player();
    if not local_player then
        return;
    end
    
    if not config.enabled then
        -- 如果插件被禁用，不执行任何逻辑
        return;
    end;

    local current_time = get_time_since_inject()
    if current_time < cast_end_time then
        return;
    end;

    if not my_utility.is_action_allowed() then
        return;
    end  

    local local_player_buffs = local_player:get_buffs();
    for _, buff in ipairs(local_player_buffs) do
        --   console.print("buff name ", buff:name());
        --   console.print("buff hash ", buff.name_hash);
          if buff.name_hash == blood_mist_buff_name_hash_c then
              is_blood_mist = true;
              break;
          end
    end

    local screen_range = 12.0;
    local player_position = get_player_position();

    local entity_list = my_target_selector.get_target_list(
        player_position,
        screen_range,
        collision_table,
        floor_table,
        angle_table);

    -- 获取any_weight值用于过滤普通目标
    local any_weight = 2  -- 默认值
    if config.custom_weights_enabled then
        any_weight = config.any_weight
    end

    local target_selector_data = my_target_selector.get_target_selector_data(
        player_position, 
        entity_list,
        any_weight);

    local enemies_nearby = target_selector_data.is_valid or (best_target_position and best_target_position:squared_dist_to_ignore_z(player_position) > (8 * 8))


    if not target_selector_data.is_valid then
        return;
    end

    local is_auto_play_active = auto_play.is_active();
    local max_range = 12.0;
    if is_auto_play_active then
        max_range = 12.0;
    end

    -- 默认目标选择(在权重目标被禁用或未找到权重目标时使用)
    local best_target = target_selector_data.closest_unit;

    -- 如果启用了权重目标，应用权重目标选择
    if config.weighted_targeting_enabled then
        -- 获取配置值
        local scan_radius = config.scan_radius
        local refresh_rate = config.scan_refresh_rate
        local min_targets = config.min_targets
        local comparison_radius = config.comparison_radius
        
        -- 根据开关使用自定义权重或默认权重
        local boss_weight, elite_weight, champion_weight
        local damage_resistance_provider_weight, damage_resistance_receiver_penalty, horde_objective_weight
        
        -- 自定义敌人权重
        if config.custom_weights_enabled then
            boss_weight = config.boss_weight
            elite_weight = config.elite_weight
            champion_weight = config.champion_weight
            -- any_weight已经在前面获取了
        else
            boss_weight = 50
            elite_weight = 10
            champion_weight = 15
            -- any_weight已经在前面设置为默认值2
        end

        -- 自定义增益权重
        if config.custom_buff_weights_enabled then
            damage_resistance_provider_weight = config.damage_resistance_provider_weight
            damage_resistance_receiver_penalty = config.damage_resistance_receiver_penalty
            horde_objective_weight = config.horde_objective_weight
            vulnerable_debuff_weight = config.vulnerable_debuff_weight
        else
            damage_resistance_provider_weight = 30
            damage_resistance_receiver_penalty = 5
            horde_objective_weight = 50
            vulnerable_debuff_weight = 1
        end
        
        -- 获取权重目标
        local weighted_target = my_target_selector.get_weighted_target(
            player_position,
            scan_radius,
            min_targets,
            comparison_radius,
            boss_weight,
            elite_weight,
            champion_weight,
            any_weight,
            refresh_rate,
            damage_resistance_provider_weight,
            damage_resistance_receiver_penalty,
            horde_objective_weight,
            vulnerable_debuff_weight
        )
        
        -- 仅在找到权重目标时使用，没有后备方案
        if weighted_target then
            best_target = weighted_target
        else
            -- 如果未找到权重目标，将best_target设为nil以防止施法
            -- 这样做是为了尊重最小目标数量设置
            best_target = nil
        end
    else
        -- 传统目标选择(如果权重目标被禁用)
        if target_selector_data.has_elite then
            local unit = target_selector_data.closest_elite;
            local unit_position = unit:get_position();
            local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
            if distance_sqr < (max_range * max_range) then
                best_target = unit;
            end        
        end

        if target_selector_data.has_boss then
            local unit = target_selector_data.closest_boss;
            local unit_position = unit:get_position();
            local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
            if distance_sqr < (max_range * max_range) then
                best_target = unit;
            end
        end

        if target_selector_data.has_champion then
            local unit = target_selector_data.closest_champion;
            local unit_position = unit:get_position();
            local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
            if distance_sqr < (max_range * max_range) then
                best_target = unit;
            end
        end
    end

    if not best_target then
        return;
    end

    -- 最终检查：如果any_weight=0且目标是普通目标，则跳过
    if any_weight == 0 and not best_target:is_boss() and not best_target:is_elite() and not best_target:is_champion() then
        return;
    end

    local best_target_position = best_target:get_position();
    local distance_sqr = best_target_position:squared_dist_to_ignore_z(player_position);

    if distance_sqr > (max_range * max_range) then            
        best_target = target_selector_data.closest_unit;
        -- 检查后备目标是否应该被跳过（如果any_weight=0且目标是普通目标）
        if best_target and any_weight == 0 and not best_target:is_boss() and not best_target:is_elite() and not best_target:is_champion() then
            return;  -- 跳过普通目标
        end
        if best_target then
            local closer_pos = best_target:get_position();
            local distance_sqr_2 = closer_pos:squared_dist_to_ignore_z(player_position);
            if distance_sqr_2 > (max_range * max_range) then
                return;
            end
        else
            return;
        end
    end

    local function should_firewall()
        local actors = actors_manager.get_all_actors()
        for _, actor in ipairs(actors) do
            local actor_name = actor:get_skin_name()
            if actor_name == "Generic_Proxy_firewall" then
                local actor_position = actor:get_position()
                local dx = math.abs(best_target_position:x() - actor_position:x())
                local dy = math.abs(best_target_position:y() - actor_position:y())    
                if dx <= 2 and dy <= 8 then  -- rectangle width is 2 and height is 8
                    return false
                end
            end
        end
        return true
    end
    -- spells logics begins:
    -- if local_player:is_spell_ready(959728) then
    --     console.print("spell is ready")
    -- end

    -- if not local_playeris_spell_ready(959728) then
    --     console.print("spell is not ready")
    -- end

    -- 电流爆发快照功能已禁用，确保不影响其他技能的正常使用
    -- 所有技能现在完全独立运行
    
    -- 正常的技能施放逻辑从这里开始
    
    -- 根据技能类型定义技能参数，以确保参数传递的一致性
    local spell_params = {
        flame_shield = { args = {}, delay = 0.0 },
        ice_armor = { args = {}, delay = 0.2 },
        unstable_current = { args = {}, delay = 0.2 },
        ball = { args = {best_target}, delay = 0.1 },
        spear = { args = {best_target}, delay = 0.1 },
        ice_blade = { args = {best_target}, delay = 0.1 },
        fireball = { args = {best_target}, delay = 0.3, custom_handler = true }, -- 更新为使用best_target而非target_selector_data
        frozen_orb = { args = {best_target}, delay = 0.3 },
        chain_lightning = { args = {best_target}, delay = 0.4 },
        blizzard = { args = {best_target}, delay = 0.3 },
        inferno = { args = {best_target}, delay = 0.1 },
        firewall = { args = {local_player, best_target}, delay = 0.0, custom_check = should_firewall },
        meteor = { args = {best_target}, delay = 0.3 },
        ice_shards = { args = {best_target}, delay = 0.3 },
        charged_bolts = { args = {best_target}, delay = 0.3 },
        hydra = { args = {best_target}, delay = 0.3 },
        arc_lash = { args = {best_target}, delay = 0.3 },
        incinerate = { args = {best_target}, delay = 0.1 },
        frost_nova = { args = {}, delay = 0.2 },
        teleport_ench = { args = {best_target, target_selector_data}, delay = 0.0 },
        teleport = { args = {entity_list, target_selector_data, best_target}, delay = 0.0 },
        deep_freeze = { args = {}, delay = 4.0 },
        fire_bolt = { args = {best_target}, delay = 0.0 },
        frost_bolt = { args = {best_target}, delay = 0.2 },
        spark = { args = {best_target}, delay = 0.3 },
        familiars = { args = {}, delay = 0.3 }
    }
    
    -- 火球术的特殊处理，因为它有返回值
    if spells.fireball.logics(best_target, target_selector_data) then
        cast_end_time = current_time + 0.3; -- 标准施法的正常延迟
        return;
    end;
    
    -- 获取已装备技能用于技能施放逻辑
    local equipped_spells = get_equipped_spell_ids()
    table.insert(equipped_spells, spell_data.evade.spell_id) -- 将躲避技能添加到列表中
    
    -- 检查传送附魔增益(增益ID 516547)
    local has_teleport_ench_buff = false
    local player_buffs = local_player:get_buffs()
    if player_buffs then
        for _, buff in ipairs(player_buffs) do
            if buff.name_hash == 516547 then
                has_teleport_ench_buff = true
                break
            end
        end
    end
    
    -- 如果检测到传送附魔增益，将其添加到已装备技能中
    if has_teleport_ench_buff then
        table.insert(equipped_spells, spell_data.teleport_ench.spell_id)
    end
    
    -- 为已装备技能创建查找表
    local equipped_lookup = {}
    for _, spell_id in ipairs(equipped_spells) do
        equipped_lookup[spell_id] = true
    end
    
    -- 正常技能优先级逻辑(仅在不处于电流爆发循环时运行)
    for _, spell_name in ipairs(spell_priority) do
        if spells[spell_name] and spell_data[spell_name] and spell_data[spell_name].spell_id and equipped_lookup[spell_data[spell_name].spell_id] then
            if spells[spell_name].logics(best_target, target_selector_data) then
                break;
            end
        end
    end
    
    -- 按照spell_priority.lua中定义的优先级顺序循环遍历技能
    for _, spell_name in ipairs(spell_priority) do
        local spell = spells[spell_name]
        -- 仅处理已装备的技能
        if spell and spell_data[spell_name] and spell_data[spell_name].spell_id and equipped_lookup[spell_data[spell_name].spell_id] then
            local params = spell_params[spell_name]
            
            if params then
                -- 跳过带有custom_handler标志的技能，因为它们被单独处理
                if not params.custom_handler then
                    -- 如果定义了自定义前置条件，则检查
                    local should_cast = true
                    if params.custom_check ~= nil then
                        should_cast = params.custom_check()
                    end
                    
                    if should_cast then
                        -- 使用适当的参数调用技能的logics函数
                        local result = spell.logics(unpack(params.args))
                        if result then
                            cast_end_time = current_time + params.delay
                            return
                        end
                    end
                end
            end
        end
    end
    
    -- 自动游戏接近远处的怪物
    local move_timer = get_time_since_inject()
    if move_timer < can_move then
        return;
    end;

    -- 自动游戏接近远处的怪物
    local is_auto_play = my_utility.is_auto_play_enabled();
    if is_auto_play then
        local player_position = local_player:get_position();
        local is_dangerous_evade_position = evade.is_dangerous_position(player_position);
        if not is_dangerous_evade_position then
            local closer_target = target_selector.get_target_closer(player_position, 15.0);
            if closer_target then
                -- if is_blood_mist then
                --     local closer_target_position = closer_target:get_position();
                --     local move_pos = closer_target_position:get_extended(player_position, -5.0);
                --     if my_utility.move_to(move_pos) then
                --         cast_end_time = current_time + 0.40;
                --         can_move = move_timer + 1.5;
                --         --console.print("自动游戏 move_to - 111")
                --     end
                -- else
                    local closer_target_position = closer_target:get_position();
                    local move_pos = closer_target_position:get_extended(player_position, 4.0);
                    
                    -- 使用移动技能到目标位置（参考piteer1逻辑）
                    use_movement_spells_to_target(move_pos);
                    
                    if my_utility.move_to(move_pos) then
                        can_move = move_timer + 1.5;
                        --console.print("自动游戏 move_to - 222")
                    end
                -- end
                
            end
        end
    end

end)

local draw_player_circle = false;
local draw_enemy_circles = false;

on_render(function ()

    if not config.enabled then
        return;
    end;

    local local_player = get_local_player();
    if not local_player then
        return;
    end

    local player_position = local_player:get_position();
    local player_screen_position = graphics.w2s(player_position);
    if player_screen_position:is_zero() then
        return;
    end

    local function count_and_display_buffs()
        local local_player = get_local_player()
        local player_position = get_player_position()
        local player_position_2d = graphics.w2s(player_position)
        local text_position = vec2.new(player_position_2d.x, player_position_2d.y + 15)
        local buff_name_check = "Ring_Unique_Sorc_101"
        if not local_player then return 0 end

        local buffs = local_player:get_buffs()
        if not buffs then return 0 end

        local buff_stack_count = -1

        for _, buff in ipairs(buffs) do
            local buff_name = buff:name()
            if buff_name == buff_name_check then
                buff_stack_count = buff_stack_count + 1
            end
        end
        return buff_stack_count
    end

    local buff_stack_count = count_and_display_buffs()

    if draw_player_circle then
        graphics.circle_3d(player_position, 8, color_white(85), 3.5, 144)
        graphics.circle_3d(player_position, 6, color_white(85), 2.5, 144)
    end    

    if draw_enemy_circles then
        local enemies = actors_manager.get_enemy_npcs()

        for i,obj in ipairs(enemies) do
        local position = obj:get_position();
        local distance_sqr = position:squared_dist_to_ignore_z(player_position);
        local is_close = distance_sqr < (8.0 * 8.0);
            -- if is_close then
                graphics.circle_3d(position, 1, color_white(100));

                local future_position = prediction.get_future_unit_position(obj, 0.4);
                graphics.circle_3d(future_position, 0.5, color_yellow(100));
            -- end;
        end;
    end


    -- 目标发光效果 -- 快速粘贴的代码

    local screen_range = 12.0;
    local player_position = get_player_position();

    local entity_list = my_target_selector.get_target_list(
        player_position,
        screen_range,
        collision_table,
        floor_table,
        angle_table);

    -- 获取any_weight值用于过滤普通目标
    local any_weight_2 = 2  -- 默认值
    if config.custom_weights_enabled then
        any_weight_2 = config.any_weight
    end

    local target_selector_data = my_target_selector.get_target_selector_data(
        player_position, 
        entity_list,
        any_weight_2);

    if not target_selector_data.is_valid then
        return;
    end

    local is_auto_play_active = auto_play.is_active();
    local max_range = 12.0;
    if is_auto_play_active then
        max_range = 12.0;
    end

    local best_target = target_selector_data.closest_unit;

    if target_selector_data.has_elite then
        local unit = target_selector_data.closest_elite;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end        
    end

    if target_selector_data.has_boss then
        local unit = target_selector_data.closest_boss;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end
    end

    if target_selector_data.has_champion then
        local unit = target_selector_data.closest_champion;
        local unit_position = unit:get_position();
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position);
        if distance_sqr < (max_range * max_range) then
            best_target = unit;
        end
    end   

    if not best_target then
        return;
    end

    if best_target and best_target:is_enemy()  then
        local glow_target_position = best_target:get_position();
        local glow_target_position_2d = graphics.w2s(glow_target_position);
        graphics.line(glow_target_position_2d, player_screen_position, color_red(180), 2.5)
        graphics.circle_3d(glow_target_position, 0.80, color_red(200), 2.0);
    end


end);

console.print("Lua Plugin - Salad Sorcerer - Version 1.4 (with Crackling Energy Snapshot)");