# 计分系统说明（当前实现）

本文基于当前代码实现整理，核心逻辑位于：

- `scripts/scoring_rules.gd`（判型与判型倍率）
- `scripts/game_state.gd`（结算与收益公式）
- `scripts/ui_controller.gd`（面板展示）

## 1. 一次结算的最终公式

每次结算（手动或自动）都会先拿到一组最终骰面 `dice`，然后按下面公式计算收益：

`income = round(base_score * pattern_multiplier * progress_multiplier)`

并且最终会做下限保护：

`income = max(1, income)`

其中：

- `base_score`：本次骰面点数和（所有上场骰子的点数相加）
- `pattern_multiplier`：根据判型得到的倍率
- `progress_multiplier`：根据当前发展状态（每桌骰子数量、骰桌数量）得到的成长倍率

对应代码：`GameState._evaluate_income_for_dice()`。

## 2. 基础分（base_score）

`base_score` 很直接，就是本次结算骰面数组求和。

例如：

- 骰面 `[6, 6, 2, 1]` -> `base_score = 15`
- 骰面 `[5, 5, 5, 4, 3]` -> `base_score = 22`

对应代码：`ScoringRules._sum_dice()`。

## 3. 判型与倍率（pattern_multiplier）

## 3.1 判型列表与倍率表

当前判型和倍率如下（`scripts/scoring_rules.gd`）：

- 散点（`none`）：`1.00`
- 一对（`pair`）：`1.25`
- 两对（`two_pair`）：`1.50`
- 三条（`three_kind`）：`1.90`
- 小顺（`small_straight`）：`2.20`
- 大顺（`large_straight`）：`2.70`
- 葫芦（`full_house`）：`3.10`
- 四条（`four_kind`）：`3.90`
- 五同（`five_kind`）：`5.20`
- 六同（`six_kind`）：`7.00`
- 七同（`seven_kind`）：`9.00`

> 说明：当前系统支持最多 7 颗上场骰子，所以存在六同、七同。

## 3.2 判型判定优先级（非常关键）

同一组骰子可能同时满足多个条件，系统按固定优先级“从上到下”命中第一个：

1. 七同
2. 六同
3. 五同
4. 四条
5. 葫芦
6. 大顺
7. 小顺
8. 三条
9. 两对
10. 一对
11. 散点

例如：

- 若同时满足“三条”和“葫芦”，会判为“葫芦”
- 若同一组里出现四条，也不会再按两对/三条算，而是直接“四条”

对应代码：`ScoringRules.evaluate_best_pattern()` 中 `if/elif` 链。

## 3.3 各判型的实现细节

- **同点类（对子/三条/四条/...）**
  - 统计每个点数出现次数，取 `max_same` 判断 N 同（4/5/6/7）
  - `pair_count` 统计“出现次数 >= 2”的点数组数量，用于一对/两对

- **小顺**
  - 先去重排序，然后检查是否包含任一序列：
    - `[1,2,3,4]`
    - `[2,3,4,5]`
    - `[3,4,5,6]`

- **大顺**
  - 去重排序后，必须恰好等于：
    - `[1,2,3,4,5]` 或 `[2,3,4,5,6]`

- **葫芦**
  - 频次列表中同时存在“至少一个 >=3”与“另一个 >=2”
  - 注意是 `>=`，不是严格等于，所以在更大骰池场景也能成立

## 4. 成长倍率（progress_multiplier）

成长倍率用于体现“系统发展程度”，公式在 `GameState.get_progress_multiplier()`：

1. 计算每桌额外骰子数（相对最小值 1）：
   - `extra_i = table_dice_counts[i] - 1`
2. 计算平均额外骰子数：
   - `avg_extra = sum(extra_i) / table_count`
3. 骰子因子：
   - `dice_factor = 1.0 + avg_extra * 0.16`
4. 骰桌因子：
   - `table_factor = 1.0 + (table_count - 1) * 0.10`
5. 成长倍率：
   - `progress_multiplier = dice_factor * table_factor`

直观上：

- 每桌平均多 1 颗骰子，倍率大约再乘 `1.16`
- 每多 1 张骰桌，倍率因子多 `0.10`

## 5. 手动结算流程

入口：`GameState.settle_manual_turn(table_index)`。

流程：

1. 校验当前桌是否满足“已至少掷过一次”
2. 读取该桌当前骰面
3. 调用 `_evaluate_income_for_dice()` 算出：
   - 判型文本 `label`
   - 基础分 `base`
   - 判型倍率 `multiplier`
   - 收益 `income`
4. 将 `income` 加到 `coin_1` 与 `total_coin_earned`
5. 记录“最近结算”信息（用于 UI 显示）
6. 记录收益窗口（用于估算收益/秒）
7. 重置该桌回合状态，进入下一轮

## 6. 自动结算流程

自动模式是“构造一次完整自动回合”后再统一结算，入口分两段：

- `begin_auto_throw_for_table()`：生成待结算骰面（staging）
- `finalize_auto_throw_for_table()`：按同一套公式结算

自动掷骰策略（`_build_auto_cycle_dice_for_table`）：

1. 先掷一轮新骰
2. 后续重掷中，默认“保留 >=5 的骰子”，重掷其余骰子
3. 共模拟到每回合上限（3 次掷骰）

最后仍走同一个 `_evaluate_income_for_dice()`，所以“计分公式”与手动完全一致，只是“得到最终骰面的策略”不同。

## 7. UI 中可见的计分信息

记分板（`UIController._refresh_score_board()`）展示：

- 当前货币 `coin_1`
- 总产出 `total_coin_earned`
- 预估收益/秒 `estimate_income_per_second()`
- 最近结算（判型 + 收益）
- 最近结算拆解（基础点数 + 判型倍率 + 当前成长倍率）
- 手动回合数 / 自动回合数

这意味着你在面板上可以直接看到一次收益的 3 个核心组成部分：

- `基础点数`
- `判型倍率`
- `成长倍率`

## 8. 参数调优入口（如果要改平衡）

当前最关键的平衡参数集中在两处：

- `scripts/scoring_rules.gd`
  - `PATTERN_MULTIPLIERS`：所有判型收益强度
  - 判型判断顺序（`evaluate_best_pattern` 的 `if/elif` 顺序）

- `scripts/game_state.gd`
  - `get_progress_multiplier()` 中的系数
    - `0.16`（平均额外骰子的收益放大）
    - `0.10`（额外骰桌的收益放大）

如果只想做“小步调参”，优先从倍率表和这两个成长系数下手。

## 9. 一个完整算例

假设某次结算：

- 骰面：`[6, 6, 5, 2]`
- 判型：一对（倍率 `1.25`）
- `base_score = 19`
- 当前 `progress_multiplier = 1.42`

则：

- 原始值：`19 * 1.25 * 1.42 = 33.725`
- 四舍五入后：`34`
- 最终收益：`max(1, 34) = 34`

最终本次结算给 `coin_1` 增加 `34`。
