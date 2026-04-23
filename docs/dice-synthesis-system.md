# 骰子合成系统说明（当前实现）

本文基于当前代码实现整理，核心逻辑位于：

- `scripts/game_state.gd`（解锁、候选生成、合成落地）
- `scripts/die_definition.gd`（两颗骰子的具体合成规则）
- `scripts/ui_expedition.gd`（远征 UI 流程与交互约束）
- `scripts/ui_growth_tree.gd`（科技树前置与文本展示）

## 1. 合成系统定位

当前“合成”属于远征系统中的一种远征类型（`合成远征`），不是直接在常规掷骰回合里进行。

完整流程是：

1. 在科技树中解锁合成相关科技
2. 在某张骰桌打开远征窗口并选择“合成”
3. 远征计时结束后，从候选列表中选择两颗骰子
4. 确认结果后执行合成，产出 1 颗新骰子并减少 1 颗上场骰子

## 2. 解锁链路与花费

合成能力有严格前置：

1. 远征入口（`TECH_COST_EXPEDITION_ENTRY = 180`）
2. 删骰远征（`TECH_COST_DELETE_EXPEDITION = 320`）
3. 合成远征（`TECH_COST_SYNTH_EXPEDITION = 650`）

也就是说，必须先有“远征入口”和“删骰远征”，才能购买“合成远征”。

对应代码：`GameState.try_buy_synth_expedition()`。

## 3. 远征阶段与触发条件

在 `UIExpedition` 中，合成远征分为两个阶段：

- **开始远征阶段**
  - 玩家先选择远征类型为“合成”
  - 当前桌上场骰子数必须 `>= 2`，否则不能开始
  - 开始后进入计时，计时长度为 `GameState.get_expedition_duration_sec()`

- **结果确认阶段**
  - 远征计时结束后，系统生成候选池并展示
  - 玩家必须在列表中点选 **2 颗不同骰子**
  - 点击“确认结果”后才真正执行合成

对应代码：`UIExpedition._on_expedition_start_pressed()`、`UIExpedition._confirm_expedition_result()`。

## 4. 合成候选池生成规则

候选池不是全池可选，而是先随机抽一批候选位，再从中选 2 颗：

1. 拿到本桌当前“非空骰子池位”集合 `filled`
2. 计算候选池规模：
   - `want = min(get_expedition_synth_pool_n(), filled.size())`
3. 将 `filled` 打乱后取前 `want` 个，再排序展示

其中：

- `get_expedition_synth_pool_n()` 的基础值为 `4`
- 可通过科技 `exp_synth_n` 逐级提升，最大到 `10`

也就是“合成候选池（N选2）”中的 `N` 当前范围是 `4~10`（受池内实际骰子数上限约束）。

对应代码：`GameState.get_random_synth_candidate_indices()`。

## 5. 两颗骰子的合成规则（核心）

当玩家选定两颗骰子 `a`、`b` 后，合成函数是 `DieDefinition.merge(a, b)`，规则如下：

1. **六个面逐位取最大值**
   - 新骰子第 i 面 = `max(a.faces[i], b.faces[i])`
2. **稀有度取较高值**
   - `new.rarity = max(a.rarity, b.rarity)`
3. **buff_key 合并**
   - 两者都有 buff：`a+b` 字符串拼接
   - 只有一方有 buff：继承该方
   - 都没有：为空

这意味着合成是“保优不保劣”的逐面并集倾向，通常会提升或保持骰子质量，不会降低已存在的高面值。

对应代码：`DieDefinition.merge()`。

## 6. 合成成功后的状态变更

`GameState.apply_expedition_synth()` 成功后会做以下修改：

1. 取两个池位 `lo/hi`（小下标/大下标）
2. 将 `lo` 位置替换为合成结果
3. 删除 `hi` 位置（池数组长度减 1）
4. `table_dice_counts[table] -= 1`（上场骰子数减 1）
5. 清空该桌自动阶段缓存 `table_auto_staging[table] = []`
6. 执行 `_clamp_all_table_rows()` 做边界收敛
7. 重采样当前上场池位 `_resample_active_pool_indices(table)`

直观结果：**骰子总量 -1，上场骰子数 -1，但保留一颗融合后的更强骰子。**

## 7. 合成失败条件与错误分支

以下情况会直接失败并返回提示：

- 合成远征未解锁
- 当前桌上场骰子数 `< 2`
- 选择了同一颗骰子（下标相同）
- 下标越界
- 目标池位不是有效骰子
- 无效骰桌索引

对应代码：`GameState.apply_expedition_synth()` 的前置校验分支。

## 8. UI 侧可见信息

在远征窗口里，玩家可见：

- 合成类型入口（已解锁时）
- 候选骰子列表（显示“池位 + 骰子摘要”）
- 骰子六面预览（含稀有度着色）
- 远征前后估算收益/秒对比
- 结果状态文案（如“合成完成”或失败原因）

对应代码：`ui_expedition.gd` 的列表填充、预览刷新与确认结果流程。

## 9. 合成系统调参入口

如果要改平衡，优先关注：

- `scripts/game_state.gd`
  - `TECH_COST_SYNTH_EXPEDITION`（解锁成本）
  - `EXPEDITION_SYNTH_BASE_N` / `EXPEDITION_SYNTH_MAX_N`（候选池规模范围）
  - `TECH_COST_SYNTH_N_BASE` 与 `pow(1.78, level)`（候选池升级成本曲线）
  - `EXPEDITION_BASE_DURATION_SEC`、`EXPEDITION_DURATION_STEP_SEC`、`EXPEDITION_MIN_DURATION_SEC`（远征耗时）

- `scripts/die_definition.gd`
  - `merge()` 里的面值融合策略（当前是逐位取 max）
  - 稀有度融合策略（当前是取 max）
  - buff 合并策略（当前是字符串拼接/继承）

## 10. 一个完整示例

假设某桌候选池里选中了两颗骰子：

- A：`faces = [1,2,3,4,5,6]`，`rarity = 1`，`buff_key = "atk"`
- B：`faces = [2,2,4,4,6,6]`，`rarity = 2`，`buff_key = "crit"`

则合成后：

- 新 faces：`[2,2,4,4,6,6]`（逐位取最大）
- 新 rarity：`2`
- 新 buff：`"atk+crit"`

同时该桌上场骰子数会减 1，并重采样本桌当前上场骰子集合用于后续掷骰。
