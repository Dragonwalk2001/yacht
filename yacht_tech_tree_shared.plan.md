# Yacht 科技树总规划（跨阶段共享）

## 1. 文档定位

- 本文件用于承载 Yacht 项目所有阶段共享的科技树设计。
- 文档放在项目根目录，便于通过 git 跟踪历史与评审。
- 后续 Milestone 计划只引用本文件，不在各自计划中重复维护完整科技树细节。

## 2. 当前确认规则（截至 MilestoneB）

- 远征能力默认与解锁关系：
  - 远征入口解锁后，默认可用“获得新骰子远征（Acquire）”。
  - 删骰远征（Delete）需科技树解锁。
  - 合成远征（Synthesize）需科技树解锁，且前置为“已解锁删骰远征”。
- 骰子上限解锁关系：
  - 第6骰与第7骰为同一个科技节点的不同等级。
  - Lv1 解锁第6骰，Lv2 解锁第7骰。
  - Lv2 费用需相对 Lv1 高很多倍（建议至少 5x 到 10x）。
- 远征参数升级：
  - 得骰远征支持 `N选1` 升级。
  - 删骰远征支持 `N选1` 升级。
  - 合成远征支持 `N选2` 升级。
  - 远征耗时（完成时间或冷却）支持独立升级线。

## 3. 与里程碑计划的关系

- MilestoneB 负责首版落地远征科技树与上述规则。
- 后续 Milestone 仅在本文件扩展科技树，不回写旧 Milestone 细节。

## 4. 文件位置（单一事实源）

- `E:\Projects\Cursor\yacht\yacht_tech_tree_shared.plan.md`

## 5. 实现映射（MilestoneB）

- 科技购买与数值：`E:\Projects\Cursor\yacht\scripts\game_state.gd`（`TECH_COST_*`、`try_buy_*`、`try_upgrade_*`）
- 远征 UI 与每桌入口：`E:\Projects\Cursor\yacht\scripts\ui_controller.gd`
- 骰子构筑数据：`E:\Projects\Cursor\yacht\scripts\die_definition.gd`，存档字段 `table_die_defs`（`version` 3）
