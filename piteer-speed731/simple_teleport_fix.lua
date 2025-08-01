-- 简单的附魔传送修复方案
-- 只修改关键的检测范围，避免复杂的更改

local logger = require "core.logger"

local SimpleFix = {}

-- 一键修复附魔传送
function SimpleFix.apply_simple_fix()
    logger.info("=== 应用简单附魔传送修复 ===")
    
    logger.info("🔧 修复内容:")
    logger.info("1. 减少敌人检测范围: 8单位 → 4单位")
    logger.info("2. 减少首领检测范围: 15单位 → 8单位")
    logger.info("3. 这应该大幅提升传送触发频率")
    
    logger.info("")
    logger.info("⚠️ 需要手动修改 core/explorer.lua:")
    logger.info("第749行: 将 < 8 改为 < 4")
    logger.info("第797行: 将 < 15 改为 < 8")
    
    logger.info("")
    logger.info("📝 具体修改:")
    logger.info("行749: if calculate_distance(player_pos, enemy:get_position()) < 4 then")
    logger.info("行797: if calculate_distance(player_pos, enemy:get_position()) < 8 then")
    
    logger.info("")
    logger.info("💡 为什么这样修改:")
    logger.info("- 8单位敌人检测太大，导致很少有'无敌人'情况")
    logger.info("- 15单位首领检测太大，首领总是阻止传送")
    logger.info("- 4单位敌人检测：只检测真正近距离的威胁")
    logger.info("- 8单位首领检测：给首领足够的安全距离")
    
    logger.info("修复说明完成")
end

-- 显示当前问题
function SimpleFix.show_current_problems()
    logger.info("=== 当前问题分析 ===")
    
    local player_pos = get_player_position()
    if not player_pos then
        logger.warn("无法获取玩家位置")
        return
    end
    
    local enemies = actors_manager.get_enemy_npcs()
    local enemies_in_4 = 0
    local enemies_in_8 = 0
    local bosses_in_8 = 0  
    local bosses_in_15 = 0
    
    for _, enemy in ipairs(enemies) do
        local distance = calculate_distance(player_pos, enemy:get_position())
        
        if distance < 4 then
            enemies_in_4 = enemies_in_4 + 1
        end
        
        if distance < 8 then
            enemies_in_8 = enemies_in_8 + 1
            if enemy:is_boss() then
                bosses_in_8 = bosses_in_8 + 1
            end
        end
        
        if distance < 15 and enemy:is_boss() then
            bosses_in_15 = bosses_in_15 + 1
        end
    end
    
    logger.info("🎯 范围对比分析:")
    logger.info(string.format("4单位内敌人: %d个 (建议范围)", enemies_in_4))
    logger.info(string.format("8单位内敌人: %d个 (当前范围)", enemies_in_8))
    logger.info(string.format("8单位内首领: %d个 (建议范围)", bosses_in_8))
    logger.info(string.format("15单位内首领: %d个 (当前范围)", bosses_in_15))
    
    logger.info("")
    logger.info("📊 传送阻挡分析:")
    
    local current_blocked_by_enemies = enemies_in_8 > 0
    local current_blocked_by_boss = bosses_in_15 > 0
    local suggested_blocked_by_enemies = enemies_in_4 > 0
    local suggested_blocked_by_boss = bosses_in_8 > 0
    
    logger.info(string.format("当前设置 - 敌人阻挡: %s, 首领阻挡: %s", 
        current_blocked_by_enemies and "是" or "否",
        current_blocked_by_boss and "是" or "否"))
    
    logger.info(string.format("建议设置 - 敌人阻挡: %s, 首领阻挡: %s", 
        suggested_blocked_by_enemies and "是" or "否",
        suggested_blocked_by_boss and "是" or "否"))
    
    local current_can_teleport = not current_blocked_by_enemies and not current_blocked_by_boss
    local suggested_can_teleport = not suggested_blocked_by_enemies and not suggested_blocked_by_boss
    
    logger.info("")
    logger.info(string.format("当前能否传送: %s", current_can_teleport and "✅ 是" or "❌ 否"))
    logger.info(string.format("修改后能否传送: %s", suggested_can_teleport and "✅ 是" or "❌ 否"))
    
    if not current_can_teleport and suggested_can_teleport then
        logger.info("🎉 修改后将解除传送阻挡！")
    elseif current_can_teleport and suggested_can_teleport then
        logger.info("✅ 修改后传送状态不变，但会更稳定")
    elseif not suggested_can_teleport then
        logger.info("⚠️ 即使修改后，当前位置仍然不适合传送")
    end
    
    logger.info("问题分析完成")
end

-- 验证基本条件
function SimpleFix.verify_basic_conditions()
    logger.info("=== 基本条件验证 ===")
    
    local settings = require "core.settings"
    
    -- 检查开关
    local switch1 = settings.movement_spell_in_explorer
    local switch2 = settings.use_teleport_enchanted
    
    logger.info(string.format("movement_spell_in_explorer: %s", switch1 and "✅ 启用" or "❌ 未启用"))
    logger.info(string.format("use_teleport_enchanted: %s", switch2 and "✅ 启用" or "❌ 未启用"))
    
    if not switch1 or not switch2 then
        logger.info("❌ 基本开关未启用，请先启用相关设置")
        return false
    end
    
    -- 检查玩家状态
    local local_player = get_local_player()
    if not local_player then
        logger.info("❌ 无法获取玩家对象")
        return false
    end
    
    local spell_ready = local_player:is_spell_ready(959728)
    logger.info(string.format("附魔传送技能: %s", spell_ready and "✅ 可用" or "⏳ 冷却中"))
    
    -- 检查orbwalker
    local orb_mode = orbwalker.get_orb_mode()
    local orb_ok = orb_mode ~= orb_mode.none
    logger.info(string.format("orbwalker模式: %s", orb_ok and "✅ 正常" or "❌ none (会阻止传送)"))
    
    if not orb_ok then
        logger.info("❌ orbwalker模式为none，这会完全阻止传送")
        return false
    end
    
    logger.info("✅ 基本条件验证通过")
    return true
end

return SimpleFix