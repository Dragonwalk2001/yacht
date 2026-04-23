# 计分系统设计说明（TOGO 版本）

本文是“目标版本”计分系统规格，重点覆盖两件事：

- 增加高阶牌型（并给出明确判定规则）
- 重做成长倍率（从单公式改为多乘区科技系统）

当前实现相关文件：

- `scripts/scoring_rules.gd`
- `scripts/game_state.gd`
- `scripts/die_definition.gd`
- `scripts/ui_controller.gd`

## 1. 目标结算公式

结算统一使用：

`income = max(1, round(base_score * pattern_multiplier * growth_multiplier_total))`

其中：

- `base_score`：本次最终骰面的点数和
- `pattern_multiplier`：判型基础倍率 * 判型升级倍率
- `growth_multiplier_total`：所有成长乘区的乘积

拆开写为：

`growth_multiplier_total = manual_zone * table_zone * global_zone * rarity_zone * other_zones...`

目标是所有成长都以“明确乘区”管理，避免旧版 `get_progress_multiplier()` 把桌数和骰子数揉成一条公式导致的调参耦合。

## 2. 牌型系统（更多牌型）

## 2.1 牌型列表（目标）

目标牌型与基础倍率（可继续调）：

- 散点（`none`）：`1.00`
- 一对（`pair`）：`1.50`
- 两对（`two_pair`）：`2.00`
- 三条（`three_kind`）：`3.00`
- 小顺（`small_straight`）：`4.00`
- 大顺（`large_straight`）：`5.00`
- 葫芦（`full_house`）：`6.00`
- 四条（`four_kind`）：`10.00`
- 五同（`five_kind`）：`20.00`
- 满顺（`full_straight`）：`30.00`
- 四带三（`fullest_house`）：`50.00`
- 六同（`six_kind`）：`100.00`
- 七同（`seven_kind`）：`200.00`

## 2.2 新增牌型定义

- `full_straight`（满顺）
  - 触发条件：在“去重后”包含 `1~6` 全部点数
  - 只在上场骰子数 `>= 6` 时可能触发

- `fullest_house`（四带三）
  - 触发条件：同一局中同时出现 `count >= 4` 与 `另一个点数 count >= 3`
  - 只在上场骰子数 `>= 7` 时稳定可触发
  - 与 `four_kind`、`full_house` 冲突时，按优先级取最高者

## 2.3 判定优先级（从高到低）

1. 七同
2. 六同
3. 四带三（`fullest_house`）
4. 满顺（`full_straight`）
5. 五同
6. 四条
7. 葫芦
8. 大顺
9. 小顺
10. 三条
11. 两对
12. 一对
13. 散点

说明：

- “优先级”应该等于“倍率大小”，建议根据倍率config里的顺序逐次判断
- 任何一组骰子最终只取一个牌型（最高优先级命中）

## 2.4 判型升级乘区（新增）

每个牌型可以独立升级，作为额外乘区：

`pattern_multiplier = pattern_base_multiplier(pattern_id) * pattern_upgrade_multiplier(pattern_id)`

建议默认（与成长乘区一致，**每级线性**）：

`pattern_upgrade_multiplier(pattern_id) = 1 + 0.25 * pattern_level[pattern_id]`

`pattern_level = 0` 时倍率为 `1.0`；与 `manual_zone` / `global_zone` 使用同一每级斜率，便于调参时对齐各乘区增长节奏。

## 3. 成长倍率系统（重做）

## 3.1 设计目标

- 每种成长来源独立成区，便于平衡
- UI 可直接展示每个乘区的当前值
- 允许后续新增乘区，不改旧公式结构

## 3.2 标准乘区结构

建议先落地 4 个核心乘区：

1. `manual_zone`（手动结算乘区）
2. `table_zone`（骰桌建设乘区）
3. `global_zone`（全局乘区）
4. `rarity_zone`（高阶骰稀有度乘区）

总成长倍率：

`growth_multiplier_total = manual_zone * table_zone * global_zone * rarity_zone`

## 3.3 每个乘区建议公式

- `manual_zone`
  - 来源：手动投掷科技等级 `manual_mult_level`
  - 公式：`1 + 0.25 * manual_mult_level`

- `table_zone`
  - 来源：骰桌相关科技等级 `table_mult_level`
  - 公式：`1 + 0.10 * table_mult_level`

- `global_zone`
  - 来源：全局科技等级 `global_mult_level`
  - 公式：`1 + 0.25 * global_mult_level`

- `rarity_zone`
  - 来源：本次结算中，参与最终牌型的骰子稀有度
  - 公式见下一节

## 4. 稀有度乘区（重点）

## 4.1 目标规则

高阶骰稀有度提供独立乘区，倍率梯度：

- 稀有度 0：`1.0`
- 稀有度 1：`1.5`
- 稀有度 2：`3.0`
- 稀有度 3：`6.0`
- 稀有度 4：`12.0`
- 稀有度 5：`24.0`
- ...（继续翻倍）

可用函数表达：

`rarity_weight(r) = 1.5 * pow(2.0, r - 1)`，当 `r >= 1`

## 4.2 “参与最终牌型的骰子”如何判定

必须可计算、可复现，建议规则如下：

- N 同（pair / three_kind / four_kind / five_kind / six_kind / seven_kind）
  - 只取构成该 N 同的那组骰子
- 两对
  - 取两组对子对应骰子
- 葫芦
  - 取三条 + 对子
- 四带三
  - 取四条 + 三条
- 小顺/大顺/满顺
  - 取构成顺子的骰子集合（按去重后点位匹配）
- 散点
  - 取全体上场骰子

然后：

`rarity_zone = product(rarity_weight(rarity_of_each_used_die))`

## 4.3 防爆建议

为避免后期爆炸过快，高稀有度的骰子应当很难获取。

## 5. 手动/自动结算统一约束

手动与自动都必须走同一函数计算最终收益，只允许“得到最终骰面的过程”不同。

要求：

- 公共入口：`evaluate_income_snapshot(dice, table_index, settle_mode)`（命名可调整）
- 统一产出字段：
  - `base_score`
  - `pattern_id`
  - `pattern_multiplier_base`
  - `pattern_multiplier_upgrade`
  - `manual_zone`
  - `table_zone`
  - `global_zone`
  - `rarity_zone`
  - `growth_multiplier_total`
  - `final_income`

这样 UI 与日志可以直接复用，不会再出现手动/自动展示字段不一致。

## 6. UI 展示需求（按乘区拆开）

记分板新增“本次结算拆解”：

- 基础分：`base_score`
- 牌型：`label`（含基础倍率与升级倍率）
- 成长乘区：
  - 手动区
  - 骰桌区
  - 全局区
  - 稀有度区
- 最终收益：`final_income`

目标是玩家能直接看出“这次收益高是因为哪一段倍率在发力”。

## 7. 配置化与调参建议

建议把可调项集中在配置字典（或资源）：

- 牌型倍率表
- 判型升级每级增幅
- 各成长乘区每级增幅
- 稀有度权重曲线

不建议把常数散落在多个函数里，后续平衡时会很难维护。

## 8. 实施顺序（建议）

1. 先扩展 `ScoringRules`：新增 `full_straight`、`fullest_house` 与优先级
2. 抽离并重写成长倍率：从 `get_progress_multiplier()` 迁移到多乘区结构
3. 新增“参与最终牌型骰子索引”的返回数据，支持 `rarity_zone`
4. 统一手动/自动结算快照结构
5. 补 UI 文本与调试输出

## 9. 示例（目标公式）

假设某次结算：

- `base_score = 30`
- 牌型为四条：`pattern_base = 10.0`
- 该牌型升级 2 级：`pattern_upgrade = 1 + 0.25 * 2 = 1.5`
- `manual_zone = 1 + 0.25 * 3 = 1.75`
- `table_zone = 1 + 0.10 * 4 = 1.40`
- `global_zone = 1 + 0.25 * 2 = 1.50`
- `rarity_zone = 3.0 * 1.5 * 1.5 * 1.0 = 6.75`

则：

- `pattern_multiplier = 10.0 * 1.5 = 15.0`
- `growth_multiplier_total = 1.75 * 1.40 * 1.50 * 6.75 = 24.80625`
- `income_raw = 30 * 15.0 * 24.80625 = 11162.8125`
- `final_income = round(11162.8125) = 11163`

该例子主要用于说明“多乘区叠乘”后，收益会显著放大，因此后续需要配套成本曲线一起调。
