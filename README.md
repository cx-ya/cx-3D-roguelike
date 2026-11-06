# 曾想 3D 飞机 · cx-3D-roguelike

一个用 Godot 4 做的 3D 太空射击 + Roguelike 成长小游戏。

飞船在倾斜视角的太空场景里左右闪避，发射激光击碎陨石，
击杀累积升级、五选一强化、攒金币在商店里永久成长，最后挑战会放弹幕的 BOSS。

## ⬇️ 直接玩

不想装 Godot 的话，下载打包好的 Windows 版本，双击即可运行：

**[⬇ 下载 cx-3D-roguelike v1.0.0 (Windows x64, 单文件 108 MB)](https://github.com/cx-ya/cx-3D-roguelike/releases/latest)**

> Windows 10/11 x64 · 需要支持 Vulkan 的显卡 · 无需安装

---

## 操作

| 按键 | 作用 |
|---|---|
| `A` / `D` | 左右移动 |
| 双击 `A` / `D` | 冲刺（冲刺期间无敌，可撞碎陨石触发子弹时间） |
| `空格` | 发射激光（有射速冷却） |

---

## 主要系统

| 系统 | 说明 |
|---|---|
| **射击** | 基础间隔 1 秒，可被「快速装填」升到 0.1 秒；支持多发齐射 |
| **冲刺 / 无敌帧** | 双击方向键，0.35 秒无敌 + 位移 5 米 |
| **完美闪避** | 冲刺撞碎陨石 → 子弹时间（慢放）+ 镜头推近 |
| **等级** | 击杀陨石累积升级，共 11 级（25 / 50 / 100 / 200 / 320 …） |
| **局内强化** | 升级时暂停并五选一：前 3 个是机制强化，后 2 个是数值强化 |
| **宠物** | 跟在飞船后方，定期产出金币（每多一只间隔 -1 秒） |
| **护盾** | 抵挡一次伤害，破盾后 30 秒充能 |
| **大招** | 商店购买后每 25 秒自动并列发射 5 颗直线子弹 |
| **BOSS** | 玩家 2 级时苏醒，150 次命中击破，三阶段弹幕（齐射 / 扇形 / 陨石雨 / 埋伏 / 点射 / 横向扫射） |
| **商店** | 游戏外永久成长，金币由击杀陨石和宠物产出 |
| **存档** | 自动存到 `user://save.cfg`，商店内可一键重置 |

---

## 场景结构

```
sences/
├── main_menu.tscn   主菜单（开始 / 新手教程 / 退出）
├── shop.tscn        升级商店
├── game.tscn        一局游戏（3D 场景 + UI 层）
├── node_3d.tscn     BOSS（Area3D + Sprite3D）
└── ...              player / laser / meteor / obstacle / pet / hud / levelup / game_over
```

`Global.gd` 是全局数据中心（货币、升级等级、局内等级、子弹时间参数、存档读写）。

---

## 运行

1. 用 **Godot 4.7.x** 打开本目录（`project.godot`）
2. F5 运行（主场景是 `main_menu.tscn`）

## 导出

项目内已带 `export_presets.cfg`（Windows Desktop 预设，单文件、pck 内嵌）：

```
项目 → 导出 → Windows Desktop → 导出项目
```

命令行：

```bash
godot --headless --path . --export-release "Windows Desktop" build/game.exe
```

---

## 存档位置

```
Windows: %APPDATA%\Godot\app_userdata\space shooter 3d\save.cfg
```

存档**不在 exe 里**，换一台电脑就是全新进度。商店里有「重置存档」按钮（点两下确认）。
