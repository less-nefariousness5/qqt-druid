-- 暗黑4距离单位分析工具
local logger = require "core.logger"

local DistanceAnalyzer = {}

-- 分析游戏中的距离单位计算
function DistanceAnalyzer.analyze_distance_calculation()
    logger.info("=== 暗黑4距离单位分析 ===")
    
    logger.info("🔍 距离计算方法:")
    logger.info("使用 pos1:dist_to_ignore_z(pos2) 函数")
    logger.info("- 这是暗黑4游戏引擎的内置距离计算")
    logger.info("- 忽略Z轴（高度），只计算水平距离")
    logger.info("- 返回的是游戏世界坐标中的距离值")
    
    logger.info("")
    logger.info("📏 距离单位参考:")
    logger.info("暗黑4中的1个距离单位大致相当于:")
    logger.info("- 角色身高的约1/3")
    logger.info("- 一个小步的距离")
    logger.info("- 近战攻击范围约2-3单位")
    logger.info("- 角色碰撞体积直径约1单位")
    
    logger.info("")
    logger.info("⚔️ 实战距离对比:")
    logger.info("1单位 = 极近距离 (几乎贴身)")
    logger.info("2单位 = 近战攻击距离")
    logger.info("4单位 = 短距离技能范围")
    logger.info("8单位 = 中等距离技能范围")
    logger.info("15单位 = 远程技能/视野范围")
    logger.info("20单位+ = 屏幕边缘距离")
    
    logger.info("")
    logger.info("🎯 附魔传送相关距离:")
    logger.info("- 附魔传送最大范围: 约25单位")
    logger.info("- 合理传送距离: 7.5-17.5单位")
    logger.info("- 敌人威胁检测: 4单位 (近身威胁)")
    logger.info("- 首领安全距离: 10单位 (中等安全距离)")
    
    logger.info("")
    logger.info("🔧 为什么选择这些数值:")
    logger.info("4单位敌人检测:")
    logger.info("  - 足够避开近身敌人")
    logger.info("  - 不会过度保守")
    logger.info("  - 大约是2个角色身位")
    
    logger.info("10单位首领检测:")
    logger.info("  - 给首领足够反应距离")
    logger.info("  - 避免传送到首领攻击范围")
    logger.info("  - 大约是5个角色身位")
    
    logger.info("分析完成")
end

-- 实时测量当前环境中的距离
function DistanceAnalyzer.measure_current_distances()
    logger.info("=== 实时距离测量 ===")
    
    local player_pos = get_player_position()
    if not player_pos then
        logger.warn("无法获取玩家位置")
        return
    end
    
    local enemies = actors_manager.get_enemy_npcs()
    if #enemies == 0 then
        logger.info("附近没有敌人可以测量距离")
        return
    end
    
    logger.info("📊 附近敌人距离分析:")
    
    -- 收集并排序敌人距离
    local enemy_distances = {}
    for _, enemy in ipairs(enemies) do
        local distance = calculate_distance(player_pos, enemy:get_position())
        if distance < 25 then  -- 只显示25单位内的敌人
            table.insert(enemy_distances, {
                distance = distance,
                type = enemy:is_boss() and "首领" or 
                       (enemy:is_elite() and "精英" or 
                       (enemy:is_champion() and "冠军" or "普通")),
                is_threat_at_4 = distance < 4,
                is_threat_at_8 = distance < 8,
                is_boss_threat_at_10 = distance < 10 and enemy:is_boss(),
                is_boss_threat_at_15 = distance < 15 and enemy:is_boss()
            })
        end
    end
    
    -- 按距离排序
    table.sort(enemy_distances, function(a, b) return a.distance < b.distance end)
    
    -- 显示最近的8个敌人
    local max_show = math.min(8, #enemy_distances)
    for i = 1, max_show do
        local enemy = enemy_distances[i]
        
        local threat_indicators = {}
        if enemy.is_threat_at_4 then table.insert(threat_indicators, "4单位威胁") end
        if enemy.is_threat_at_8 then table.insert(threat_indicators, "8单位威胁") end
        if enemy.is_boss_threat_at_10 then table.insert(threat_indicators, "10单位首领威胁") end
        if enemy.is_boss_threat_at_15 then table.insert(threat_indicators, "15单位首领威胁") end
        
        local threat_text = #threat_indicators > 0 and 
            (" [" .. table.concat(threat_indicators, ", ") .. "]") or " [无威胁]"
        
        logger.info(string.format("  第%d近: %.2f单位 %s%s", 
            i, enemy.distance, enemy.type, threat_text))
    end
    
    -- 统计各范围内的威胁
    local threats_4 = 0
    local threats_8 = 0
    local boss_threats_10 = 0
    local boss_threats_15 = 0
    
    for _, enemy in ipairs(enemy_distances) do
        if enemy.is_threat_at_4 then threats_4 = threats_4 + 1 end
        if enemy.is_threat_at_8 then threats_8 = threats_8 + 1 end
        if enemy.is_boss_threat_at_10 then boss_threats_10 = boss_threats_10 + 1 end
        if enemy.is_boss_threat_at_15 then boss_threats_15 = boss_threats_15 + 1 end
    end
    
    logger.info("")
    logger.info("🎯 威胁统计:")
    logger.info(string.format("4单位内威胁: %d个 (当前敌人检测)", threats_4))
    logger.info(string.format("8单位内威胁: %d个 (原敌人检测)", threats_8))
    logger.info(string.format("10单位内首领: %d个 (当前首领检测)", boss_threats_10))
    logger.info(string.format("15单位内首领: %d个 (原首领检测)", boss_threats_15))
    
    -- 分析修改效果
    local old_blocked = threats_8 > 0 or boss_threats_15 > 0
    local new_blocked = threats_4 > 0 or boss_threats_10 > 0
    
    logger.info("")
    logger.info(string.format("修改前传送阻挡: %s", old_blocked and "是" or "否"))
    logger.info(string.format("修改后传送阻挡: %s", new_blocked and "是" or "否"))
    
    if old_blocked and not new_blocked then
        logger.info("🎉 距离优化生效！现在可以传送了")
    elseif not old_blocked and not new_blocked then
        logger.info("✅ 传送条件保持良好")
    end
    
    logger.info("距离测量完成")
end

-- 距离单位可视化参考
function DistanceAnalyzer.show_distance_visualization()
    logger.info("=== 距离单位可视化参考 ===")
    
    logger.info("📐 距离单位对照表:")
    logger.info("")
    logger.info("1单位  ●           (贴身距离)")
    logger.info("2单位  ●—●         (近战范围)")
    logger.info("4单位  ●———●       (短距离技能)")
    logger.info("8单位  ●———————●   (中距离技能)")
    logger.info("10单位 ●—————————● (安全距离)")
    logger.info("15单位 ●———————————————● (远程技能)")
    logger.info("")
    
    logger.info("🏃 以角色为参考:")
    logger.info("1单位 ≈ 角色身高的1/3")
    logger.info("2单位 ≈ 角色伸臂长度")
    logger.info("4单位 ≈ 2个角色身位")
    logger.info("8单位 ≈ 4个角色身位")
    logger.info("10单位 ≈ 5个角色身位")
    logger.info("15单位 ≈ 7-8个角色身位")
    
    logger.info("")
    logger.info("⚔️ 实战应用:")
    logger.info("4单位敌人检测 = 只检测真正的近身威胁")
    logger.info("10单位首领检测 = 足够的首领安全距离")
    logger.info("7.5-17.5单位传送 = 合适的传送距离范围")
    
    logger.info("")
    logger.info("💡 为什么不用更小的距离:")
    logger.info("- 2单位太小，可能传送到敌人身边")
    logger.info("- 1单位太小，基本等于贴身")
    logger.info("- 4单位是平衡点，既安全又不过度保守")
    
    logger.info("可视化参考完成")
end

-- 计算距离修改的影响
function DistanceAnalyzer.calculate_optimization_impact()
    logger.info("=== 距离优化影响计算 ===")
    
    local player_pos = get_player_position()
    if not player_pos then
        logger.warn("无法获取玩家位置")
        return
    end
    
    local enemies = actors_manager.get_enemy_npcs()
    
    -- 统计不同距离范围的敌人数量
    local ranges = {1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20}
    local enemy_counts = {}
    local boss_counts = {}
    
    for _, range in ipairs(ranges) do
        enemy_counts[range] = 0
        boss_counts[range] = 0
        
        for _, enemy in ipairs(enemies) do
            local distance = calculate_distance(player_pos, enemy:get_position())
            if distance < range then
                if enemy:is_boss() then
                    boss_counts[range] = boss_counts[range] + 1
                else
                    enemy_counts[range] = enemy_counts[range] + 1
                end
            end
        end
    end
    
    logger.info("📊 不同距离范围的敌人分布:")
    for _, range in ipairs(ranges) do
        local total = enemy_counts[range] + boss_counts[range]
        logger.info(string.format("%d单位内: 总计%d (普通%d + 首领%d)", 
            range, total, enemy_counts[range], boss_counts[range]))
    end
    
    logger.info("")
    logger.info("🎯 关键距离对比:")
    logger.info(string.format("4单位vs8单位敌人检测: %d vs %d (减少%d个)", 
        enemy_counts[4], enemy_counts[8], enemy_counts[8] - enemy_counts[4]))
    logger.info(string.format("10单位vs15单位首领检测: %d vs %d (减少%d个)", 
        boss_counts[10], boss_counts[15], boss_counts[15] - boss_counts[10]))
    
    -- 计算传送成功概率的改善
    local old_enemy_blocked = enemy_counts[8] > 0
    local new_enemy_blocked = enemy_counts[4] > 0
    local old_boss_blocked = boss_counts[15] > 0
    local new_boss_blocked = boss_counts[10] > 0
    
    local old_success = not old_enemy_blocked and not old_boss_blocked
    local new_success = not new_enemy_blocked and not new_boss_blocked
    
    logger.info("")
    logger.info("📈 优化效果评估:")
    if not old_success and new_success then
        logger.info("🎉 重大改善: 从无法传送变为可以传送")
    elseif old_success and new_success then
        logger.info("✅ 保持良好: 传送条件继续满足，但更稳定")
    elseif old_success and not new_success then
        logger.info("⚠️ 意外情况: 这通常不会发生")
    else
        logger.info("❌ 仍需改善: 当前位置仍不适合传送")
    end
    
    logger.info("影响计算完成")
end

-- 一键完整分析
function DistanceAnalyzer.complete_analysis()
    logger.info("开始完整的距离单位分析...")
    logger.info("")
    
    DistanceAnalyzer.analyze_distance_calculation()
    logger.info("")
    
    DistanceAnalyzer.show_distance_visualization()
    logger.info("")
    
    DistanceAnalyzer.measure_current_distances()
    logger.info("")
    
    DistanceAnalyzer.calculate_optimization_impact()
    logger.info("")
    
    logger.info("=== 完整分析结束 ===")
end

return DistanceAnalyzer