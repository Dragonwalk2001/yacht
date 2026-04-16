# test-project-2-yacht

Godot 快艇骰子（Yacht）MVP 项目。

## 当前功能

- 1-4 人本地轮流
- 12 类计分（上半区 6 + 下半区 6）
- 每回合最多 3 次掷骰，可锁定骰子
- 上半区奖励分（63/35）
- 12 轮结束后自动结算，支持平局显示
- 支持一键开启新局

## 运行方式

### 方式 1：Godot 编辑器打开

1. 打开 Godot
2. Import 项目目录：`test-project-2-yacht`
3. 运行主场景（`res://scenes/main.tscn`）

### 方式 2：命令行运行

如果项目目录下有 `godot.exe`：

```powershell
cd E:\Projects\Cursor\test-project-2-yacht
.\godot.exe --path .
```

## 操作说明

- 点击 `掷骰`：掷出未锁定骰子
- 点击每个骰子按钮：切换锁定/解锁
- 在类别列表中选择 1 项，点击 `确认落分`
- 点击 `新局`：按玩家数重开

## 主要结构

- `project.godot`
- `scenes/main.tscn`
- `scenes/GameBoard.tscn`
- `scenes/ResultPopup.tscn`
- `scripts/ui_controller.gd`
- `scripts/game_state.gd`
- `scripts/turn_manager.gd`
- `scripts/scoring_rules.gd`
