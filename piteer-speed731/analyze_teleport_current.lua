-- 当前附魔传送问题分析工具
local logger = require "core.logger"
local settings = require "core.settings"

local TeleportAnalyzer = {}

-- 分析当前附魔传送为什么不工作
function TeleportAnalyzer.analyze_why_not_working()
    logger.info("=== 附魔传送问题诊断 ===")
    
    local issues = {}
    local warnings = {}
    
    -- 1. 基本开关检查
    if not settings.movement_spell_in_explorer then
        table.insert(issues, "movement_spell_in_explorer 未启用")
    end
    
    if not settings.use_teleport_enchanted then
        table.insert(issues, "use_teleport_enchanted 未启用")
    end
    
    -- 2. 玩家状态检查
    local local_player = get_local_player()
    if not local_player then
        table.insert(issues, "无法获取玩家对象")
    else
        if not local_player:is_spell_ready(959728) then
            table.insert(warnings, "附魔传送技能冷却中")
        end
    end
    
    -- 3. orbwalker检查
    local current_orb_mode = orbwalker.get_orb_mode()
    if current_orb_mode == orb_mode.none then
        table.insert(issues, "orbwalker模式为none - 这会完全阻止传送")
    end
    
    -- 4. 敌人检测分析
    local player_pos = get_player_position()
    if player_pos then
        local enemies = actors_manager.get_enemy_npcs()
        local enemies_in_8 = 0
        local bosses_in_15 = 0
        local normal_enemies = 0
        local special_enemies = 0
        
        for _, enemy in ipairs(enemies) do
            local distance = calculate_distance(player_pos, enemy:get_position())
            
            -- 8单位内敌人检测
            if distance < 8 then
                enemies_in_8 = enemies_in_8 + 1
                if enemy:is_boss() then
                    -- 首领不算在敌人检测里
                elseif enemy:is_elite() or enemy:is_champion() then
                    special_enemies = special_enemies + 1
                else
                    normal_enemies = normal_enemies + 1
                end
            end
            
            -- 15单位内首领检测
            if distance < 15 and enemy:is_boss() then
                bosses_in_15 = bosses_in_15 + 1
            end
        end
        
        -- 分析敌人阻挡情况
        local has_blocking_enemies = false
        if settings.ignore_normal_enemies_for_movement then
            has_blocking_enemies = special_enemies > 0
            if special_enemies > 0 then
                table.insert(warnings, string.format("8单位内有%d个特殊敌人(精英/冠军)阻止传送", special_enemies))
            end
            if normal_enemies > 0 then
                logger.info(string.format("8单位内有%d个普通敌人(被忽略)", normal_enemies))
            end
        else
            has_blocking_enemies = (normal_enemies + special_enemies) > 0
            if has_blocking_enemies then
                table.insert(warnings, string.format("8单位内有%d个敌人阻止传送", normal_enemies + special_enemies))
            end
        end
        
        -- 分析首领阻挡情况
        if settings.disable_movement_on_boss and bosses_in_15 > 0 then
            table.insert(warnings, string.format("15单位内有%d个首领阻止传送", bosses_in_15))
        end
        
        -- 总结敌人情况
        logger.info("🎯 敌人检测分析:")
        logger.info(string.format("  8单位内: 普通%d, 特殊%d, 首领%d", normal_enemies, special_enemies, 
            enemies_in_8 - normal_enemies - special_enemies))
        logger.info(string.format("  15单位内首领: %d", bosses_in_15))
        logger.info(string.format("  忽略普通敌人: %s", settings.ignore_normal_enemies_for_movement and "是" or "否"))
        logger.info(string.format("  首领阻止移动: %s", settings.disable_movement_on_boss and "是" or "否"))
    end
    
    -- 5. 距离要求检查
    logger.info("📏 距离要求: 7.5 - 17.5单位")
    
    -- 输出结果
    if #issues > 0 then
        logger.info("🔴 阻止传送的严重问题:")
        for i, issue in ipairs(issues) do
            logger.info(string.format("  %d. %s", i, issue))
        end
    end
    
    if #warnings > 0 then
        logger.info("🟡 当前状况:")
        for i, warning in ipairs(warnings) do
            logger.info(string.format("  %d. %s", i, warning))
        end
    end
    
    if #issues == 0 and #warnings == 0 then
        logger.info("✅ 所有条件都满足，传送应该能正常工作")
        logger.info("如果仍然不工作，可能是代码逻辑问题")
    elseif #issues == 0 then
        logger.info("⚠️ 主要功能正常，但有临时阻挡因素")
    else
        logger.info("❌ 发现阻止传送的关键问题")
    end
    
    logger.info("========================")
end

-- 实时监控传送尝试
function TeleportAnalyzer.monitor_teleport_attempts()
    logger.info("=== 实时监控传送尝试 ===")
    
    local start_time = get_time_since_inject()
    local check_count = 0
    local attempt_count = 0
    
    logger.info("开始10秒监控...")
    
    while get_time_since_inject() - start_time < 10 do
        check_count = check_count + 1
        
        -- 检查当前条件
        local player_pos = get_player_position()
        if player_pos then
            local local_player = get_local_player()
            local orb_mode = orbwalker.get_orb_mode()
            local spell_ready = local_player and local_player:is_spell_ready(959728)
            
            -- 检查是否满足传送条件
            local has_enemies = false
            local has_boss = false
            
            local enemies = actors_manager.get_enemy_npcs()
            for _, enemy in ipairs(enemies) do
                local distance = calculate_distance(player_pos, enemy:get_position())
                
                if distance < 8 then
                    if settings.ignore_normal_enemies_for_movement then
                        if enemy:is_elite() or enemy:is_champion() then
                            has_enemies = true
                            break
                        end
                    else
                        if not enemy:is_boss() then
                            has_enemies = true
                            break
                        end
                    end
                end
                
                if settings.disable_movement_on_boss and distance < 15 and enemy:is_boss() then
                    has_boss = true
                end
            end
            
            local can_teleport = settings.movement_spell_in_explorer and 
                               settings.use_teleport_enchanted and
                               spell_ready and 
                               orb_mode ~= orb_mode.none and
                               not has_enemies and 
                               not has_boss
            
            if can_teleport then
                attempt_count = attempt_count + 1
                logger.info(string.format("%.1fs: ✅ 满足传送条件 (第%d次)", 
                    get_time_since_inject() - start_time, attempt_count))
            end
        end
        
        -- 等待0.5秒
        local wait_start = get_time_since_inject()
        while get_time_since_inject() - wait_start < 0.5 do
            -- 等待
        end
    end
    
    logger.info(string.format("监控结束: 共检查%d次，满足传送条件%d次", check_count, attempt_count))
    
    if attempt_count == 0 then
        logger.info("⚠️ 10秒内从未满足传送条件，这说明当前环境不适合传送")
    elseif attempt_count > 0 then
        logger.info("💡 条件满足但可能传送逻辑有问题，建议检查代码")
    end
end

-- 简化的条件检查
function TeleportAnalyzer.quick_check()
    logger.info("=== 快速条件检查 ===")
    
    -- 基本开关
    local switch_ok = settings.movement_spell_in_explorer and settings.use_teleport_enchanted
    logger.info(string.format("开关状态: %s", switch_ok and "✅ 正常" or "❌ 未启用"))
    
    -- 玩家和技能
    local local_player = get_local_player()
    local player_ok = local_player ~= nil
    local spell_ok = player_ok and local_player:is_spell_ready(959728)
    logger.info(string.format("玩家对象: %s", player_ok and "✅ 正常" or "❌ 异常"))
    logger.info(string.format("技能状态: %s", spell_ok and "✅ 可用" or "⏳ 冷却中"))
    
    -- orbwalker
    local orb_mode = orbwalker.get_orb_mode()
    local orb_ok = orb_mode ~= orb_mode.none
    logger.info(string.format("orbwalker: %s", orb_ok and "✅ 正常" or "❌ none模式"))
    
    -- 敌人状态
    local player_pos = get_player_position()
    local enemy_ok = true
    local boss_ok = true
    
    if player_pos then
        local enemies = actors_manager.get_enemy_npcs()
        
        for _, enemy in ipairs(enemies) do
            local distance = calculate_distance(player_pos, enemy:get_position())
            
            if distance < 8 then
                if settings.ignore_normal_enemies_for_movement then
                    if enemy:is_elite() or enemy:is_champion() then
                        enemy_ok = false
                        break
                    end
                else
                    if not enemy:is_boss() then
                        enemy_ok = false
                        break
                    end
                end
            end
            
            if settings.disable_movement_on_boss and distance < 15 and enemy:is_boss() then
                boss_ok = false
            end
        end
    end
    
    logger.info(string.format("敌人检查: %s", enemy_ok and "✅ 无阻挡" or "❌ 有敌人"))
    logger.info(string.format("首领检查: %s", boss_ok and "✅ 无阻挡" or "❌ 有首领"))
    
    -- 总结
    local all_ok = switch_ok and player_ok and spell_ok and orb_ok and enemy_ok and boss_ok
    logger.info(string.format("总体状态: %s", all_ok and "✅ 应该能传送" or "❌ 有阻挡因素"))
    
    return all_ok
end

return TeleportAnalyzer