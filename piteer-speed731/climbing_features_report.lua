-- 攀爬功能检测报告
local logger = require "core.logger"

local ClimbingReport = {}

-- 生成完整的攀爬功能报告
function ClimbingReport.generate_full_report()
    logger.info("=== piteer1插件攀爬功能完整报告 ===")
    
    logger.info("")
    logger.info("🔍 检测结果概览:")
    logger.info("✅ 发现攀爬相关功能")
    logger.info("✅ 发现梯子处理系统")
    logger.info("✅ 发现垂直移动功能")
    logger.info("✅ 发现跳跃技能支持")
    
    logger.info("")
    logger.info("📂 相关文件清单:")
    logger.info("1. tasks/stupid_ladder.lua - 梯子/传送控制器处理")
    logger.info("2. core/explorer.lua - 跳跃技能集成")
    logger.info("3. core/anti_stuck_system.lua - 垂直方向逃脱")
    logger.info("4. core/task_manager.lua - 梯子任务管理")
    logger.info("5. gui.lua - 跳跃功能界面")
    logger.info("6. data/enums.lua - 传送控制器定义")
    
    logger.info("")
    logger.info("🎯 主要攀爬功能:")
    
    logger.info("")
    logger.info("1. 【梯子/传送控制器系统】")
    logger.info("   文件: tasks/stupid_ladder.lua")
    logger.info("   功能: 自动检测和使用游戏中的传送控制器")
    logger.info("   - 搜索名称包含'Traversal'的游戏对象")
    logger.info("   - 自动导航到传送控制器位置")
    logger.info("   - 处理Z轴高度差异(±5单位内)")
    logger.info("   - 智能寻找可行走位置")
    logger.info("   - 自动交互激活传送")
    
    logger.info("")
    logger.info("2. 【野蛮人跳跃技能】")
    logger.info("   文件: core/explorer.lua (line 1183-1185)")
    logger.info("   技能ID: 196545")
    logger.info("   - 可在GUI中启用/禁用")
    logger.info("   - 集成到移动技能系统")
    logger.info("   - 用于探索中的垂直移动")
    
    logger.info("")
    logger.info("3. 【反卡死垂直逃脱】")
    logger.info("   文件: core/anti_stuck_system.lua (line 307-344)")
    logger.info("   - 计算移动方向的垂直方向")
    logger.info("   - 尝试90度方向逃脱")
    logger.info("   - 处理卡在障碍物的情况")
    
    logger.info("")
    logger.info("4. 【任务管理集成】")
    logger.info("   文件: core/task_manager.lua (line 59)")
    logger.info("   - 'stupid_ladder'任务高优先级")
    logger.info("   - 在怪物击杀之前执行")
    logger.info("   - 与其他任务协调运行")
    
    logger.info("")
    logger.info("💡 技术实现细节:")
    
    logger.info("")
    logger.info("【传送控制器检测】")
    logger.info("- 扫描所有游戏actor对象")
    logger.info("- 匹配skin_name包含'[Tt]raversal'")
    logger.info("- 检查Z轴高度差(math.abs(actor_pos:z() - player_pos:z()) <= 5)")
    logger.info("- 找到最近的可用传送点")
    
    logger.info("")
    logger.info("【智能导航逻辑】")
    logger.info("- 距离<2单位: 使用pathfinder.force_move_raw()直接移动")
    logger.info("- 距离>=2单位: 使用explorer路径规划系统")
    logger.info("- 目标不可行走: 自动搜索5单位内可行走位置")
    logger.info("- 距离<1单位: 自动交互激活传送")
    
    logger.info("")
    logger.info("【垂直移动算法】")
    logger.info("- 分析最近2个位置计算移动方向")
    logger.info("- 计算逆时针和顺时针90度方向")
    logger.info("- 测试垂直方向的可行走性")
    logger.info("- 使用escape_attempt_radius范围")
    
    logger.info("")
    logger.info("🎮 用户界面:")
    logger.info("- GUI中有'野蛮人跳跃'开关")
    logger.info("- settings.use_leap控制跳跃技能启用")
    logger.info("- 梯子功能自动运行，无需手动控制")
    
    logger.info("")
    logger.info("⚙️ 配置参数:")
    logger.info("- 传送控制器Z轴检测范围: ±5单位")
    logger.info("- 近距离直接移动阈值: 2单位")
    logger.info("- 交互距离阈值: 1单位")
    logger.info("- 可行走位置搜索半径: 5单位")
    logger.info("- 垂直逃脱测试半径: CONFIG.escape_attempt_radius")
    
    logger.info("")
    logger.info("🔧 相关枚举定义:")
    logger.info("- enums.misc.traversal_controller = 'traversal_footprints_01_fxMesh'")
    logger.info("- 野蛮人跳跃技能ID = 196545")
    
    logger.info("")
    logger.info("📊 功能评估:")
    logger.info("✅ 优点:")
    logger.info("  - 完整的垂直移动解决方案")
    logger.info("  - 智能的传送控制器处理")
    logger.info("  - 集成度高，自动化程度好")
    logger.info("  - 处理多种边缘情况")
    
    logger.info("⚠️ 局限性:")
    logger.info("  - 依赖游戏内置传送控制器")
    logger.info("  - 跳跃技能仅支持野蛮人")
    logger.info("  - 垂直逃脱范围有限")
    
    logger.info("")
    logger.info("🎯 总结:")
    logger.info("该插件包含较为完善的攀爬和垂直移动功能，主要通过:")
    logger.info("1. 自动化的传送控制器(梯子)处理系统")
    logger.info("2. 野蛮人跳跃技能集成")
    logger.info("3. 反卡死的垂直方向逃脱机制")
    logger.info("4. 智能的高度差异处理算法")
    
    logger.info("")
    logger.info("这些功能能够有效处理暗黑4中的垂直移动需求，")
    logger.info("特别是在深坑(Pit)等多层地形环境中的导航。")
    
    logger.info("")
    logger.info("=== 攀爬功能报告完成 ===")
end

-- 检查当前攀爬功能状态
function ClimbingReport.check_current_status()
    logger.info("=== 当前攀爬功能状态 ===")
    
    -- 检查设置
    local settings = require "core.settings"
    logger.info(string.format("野蛮人跳跃: %s", settings.use_leap and "✅ 启用" or "❌ 禁用"))
    
    -- 检查传送控制器
    local traversal_found = false
    local actors = actors_manager:get_all_actors()
    local player_pos = get_player_position()
    
    if player_pos then
        for _, actor in pairs(actors) do
            local name = actor:get_skin_name()
            if name:match("[Tt]raversal") then
                traversal_found = true
                local actor_pos = actor:get_position()
                local distance = actor_pos:dist_to_ignore_z(player_pos)
                local height_diff = math.abs(actor_pos:z() - player_pos:z())
                
                logger.info(string.format("发现传送控制器: %s", name))
                logger.info(string.format("  距离: %.2f单位", distance))
                logger.info(string.format("  高度差: %.2f单位", height_diff))
                logger.info(string.format("  可检测: %s", height_diff <= 5 and "是" or "否"))
                break
            end
        end
    end
    
    if not traversal_found then
        logger.info("当前区域无传送控制器")
    end
    
    -- 检查任务管理器状态
    local task_manager = require "core.task_manager"
    local current_task = task_manager.get_current_task()
    logger.info(string.format("当前任务: %s", current_task.name))
    
    logger.info("状态检查完成")
end

-- 显示攀爬功能的技术细节
function ClimbingReport.show_technical_details()
    logger.info("=== 攀爬功能技术细节 ===")
    
    logger.info("🔧 核心算法:")
    logger.info("")
    logger.info("1. 传送控制器搜索算法:")
    logger.info("```lua")
    logger.info("for _, actor in pairs(actors) do")
    logger.info("    local name = actor:get_skin_name()")
    logger.info("    if name:match('[Tt]raversal') then")
    logger.info("        local height_diff = math.abs(actor_pos:z() - player_pos:z())")
    logger.info("        if height_diff <= 5 then")
    logger.info("            return actor")
    logger.info("        end")
    logger.info("    end")
    logger.info("end")
    logger.info("```")
    
    logger.info("")
    logger.info("2. 可行走位置搜索:")
    logger.info("```lua")
    logger.info("for x = -radius, radius, 0.5 do")
    logger.info("    for y = -radius, radius, 0.5 do")
    logger.info("        local test_pos = vec3:new(pos:x() + x, pos:y() + y, pos:z())")
    logger.info("        test_pos = utility.set_height_of_valid_position(test_pos)")
    logger.info("        if utility.is_point_walkeable(test_pos) then")
    logger.info("            -- 找到可行走位置")
    logger.info("        end")
    logger.info("    end")
    logger.info("end")
    logger.info("```")
    
    logger.info("")
    logger.info("3. 垂直方向计算:")
    logger.info("```lua")
    logger.info("local movement_dir = {")
    logger.info("    x = current_pos:x() - last_pos.x,")
    logger.info("    y = current_pos:y() - last_pos.y")
    logger.info("}")
    logger.info("local perpendicular_dirs = {")
    logger.info("    {x = -movement_dir.y, y = movement_dir.x},  -- 逆时针90度")
    logger.info("    {x = movement_dir.y, y = -movement_dir.x}   -- 顺时针90度")
    logger.info("}")
    logger.info("```")
    
    logger.info("")
    logger.info("🎯 关键参数:")
    logger.info("- Z轴检测容差: 5单位")
    logger.info("- 直接移动阈值: 2单位")
    logger.info("- 交互距离: 1单位")
    logger.info("- 搜索精度: 0.5单位步长")
    logger.info("- 搜索半径: 5单位")
    
    logger.info("")
    logger.info("🔄 执行流程:")
    logger.info("1. 扫描传送控制器")
    logger.info("2. 计算距离和高度差")
    logger.info("3. 选择移动策略(直接/路径规划)")
    logger.info("4. 处理不可行走位置")
    logger.info("5. 执行移动命令")
    logger.info("6. 到达后自动交互")
    logger.info("7. 标记任务完成")
    
    logger.info("技术细节显示完成")
end

return ClimbingReport