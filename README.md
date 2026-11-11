# Code Survivors · 幸存者 色块原型

阶段①原型验证版（按飞书知识库《幸存者类 8 阶段流水线》实现）。

## 核心玩法
- 蓝方块玩家，WASD / 方向键移动，武器自动攻击
- 红方块海最高 300 同屏，白圈 AoE 自动清怪，绿宝石磁吸拾取
- 飘字合并（×N），接触伤害不叠加 + 无敌帧

## 管线系统（核心差异化）
- 可视化节点图：触发 → 条件 → 动作 → 修饰，四元组组合
- 2–3 槽位管线预设，战斗中可切槽位，不可修改
- 暂停 / 安全区内可拖拽编辑管线，添加 / 删除指令块
- 战斗中管线条右下角实时点亮，看见“我的管线在跑”

## 运行
```bash
cd code-survivors
E:\a_code\001-Game\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe --path .
```

## 验收
```bash
E:\a_code\001-Game\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe --headless --path . --script tests/test_proto.gd
# 期望：ALL 45 CHECKS PASSED，300同屏单帧模拟耗时 ~0.2ms
```

## 文件组织
- 飞书云盘 `幸存者《代码幸存者》项目`：设计文档、原型代码、美术资源、测试报告
- 飞书知识库 `05 幸存者`：通用知识与 SOP（不随项目迭代的沉淀内容）

## 目标平台
海外：Google Play / App Store / Web H5；国内：TapTap / 微信小程序 / 抖音小游戏；后续 Steam
