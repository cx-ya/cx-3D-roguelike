# cx-3D-roguelike

A 3D space shooter with roguelite progression, built with **Godot 4**.

You pilot a single fighter in a tilted camera view, dodging meteors and blasting them into coins.
Kills level you up, levels give you upgrades, coins buy permanent power in the shop —
and eventually a boss wakes up and fills the screen with bullets.

---

## ⬇️ Play now

Don't want to install Godot? Grab the packaged Windows build and just double-click it.

**[⬇ Download cx-3D-roguelike v1.0.0 (Windows x64, single file, 108 MB)](https://github.com/cx-ya/cx-3D-roguelike/releases/latest)**

> Windows 10/11 x64 · Vulkan-capable GPU required · no installation, no extra files

---

## 🎮 How to play

### Controls

| Input | Action |
|---|---|
| `A` / `D` | Move left / right |
| **Double-tap** `A` / `D` | Dash |
| `Space` | Fire laser |

### The run

1. **Survive and shoot.** Meteors stream toward you. Everything is instantly clear on screen, so keep moving.
2. **Kill meteors → level up.** Every kill counts toward the next level.
3. **Level up → pick an upgrade.** The game pauses and offers 5 options:
   the first 3 are *mechanics* (new behaviour), the last 2 are *stats*.
4. **Shoot the boss.** It is already standing in the arena, dormant and **invulnerable**, until you reach level 2.
5. **Die → results screen → shop.** Coins are permanent; spend them and go again.

### Things that will keep you alive

- **Dash = invincibility frames.** For 0.35 s nothing can touch you. Use it to slip through a wall of meteors.
- **Dash *into* a meteor** to shatter it: this triggers **bullet time** (everything slows to 15%) and a camera push-in. It is the single strongest move in the game — it clears a meteor *and* gives you free time to line up shots.
- **Dodge shot** (run upgrade): every perfect dodge automatically fires 3 lasers straight ahead (30 s cooldown).
- **Shield** (run upgrade): absorbs one whole hit, then recharges over 30 s.
- **Pets** (run upgrade): follow you and produce coins over time. More pets = faster income.

### Upgrades you will see

| Type | Examples |
|---|---|
| Mechanics | Multishot (extra parallel lasers), Auto-reload (much faster fire rate), Pet, Wave shot (lasers sine-wave), Dodge shot, Greed (more coins) |
| Stats | Laser pierce, laser range, dash cooldown, max HP |

### The boss

| Phase | Trigger | What changes |
|---|---|---|
| Dormant | After the intro | Stands still, tinted grey-blue, **immune to damage** |
| Awake | Level 2 (25 kills) | Turns solid, sky darkens, starts firing, **150 hits to kill** |
| Phase 2 | HP ≤ 50% | Natural meteors ×3 speed, boss turns **red**, attacks faster |
| Phase 3 | HP ≤ 25% | **Sweeping barrage** from left to right, non-stop, until it dies |

Six attack patterns in rotation: twin volley, fan shot, meteor rain, surround-and-converge,
rapid snipe, and the phase-3 sweep. **None of them home in on you** — each meteor takes a single
snapshot of your position and then flies straight, so you can always dodge by moving after the shot.

### Dying

- Hit by a meteor: −50 HP
- Hit by an obstacle: −20 HP
- HP reaches 0 → results screen with your kill count, level and coins

Kill the boss instead and you get the **victory** screen.

---

## 🛠 Systems overview

| System | Notes |
|---|---|
| **Dash / i-frames** | 0.35 s invulnerability, 5 m displacement, cooldown reduced by shop upgrades |
| **Bullet time** | `Engine.time_scale` 0.15, triggered by dashing through a meteor |
| **Levels** | 11 levels · thresholds 25 / 50 / 100 / 200 / 320 / 500 / 750 / 1100 / 1600 / 2200 kills |
| **Run upgrades** | 5 choices per level-up, 3 mechanical + 2 stat, with fallbacks when maxed |
| **Shop** | Permanent upgrades, one-time unlocks, prerequisite chains (ultimate → cooldown → ammo) |
| **Pets** | Follow the ship, hop now and then, spawn coins on a timer |
| **Boss** | Area3D + Sprite3D, rises from the floor, three phases, 6 attack patterns |
| **HUD** | Level, coins, HP bar, shoot cooldown, dash, ultimate, shield, dodge shot, boss HP bar |
| **Save** | `ConfigFile` at `user://save.cfg`, auto-saved on death and purchases |

---

## 📁 Project layout

```
Global.gd              autoload singleton: currency, upgrades, levels,
                       bullet time, save/load
sences/
├── main_menu.tscn     main menu + tutorial overlay
├── shop.tscn          permanent upgrade shop
├── game.tscn          a run: 3D scene + CanvasLayer UI
├── node_3d.tscn       the boss (Area3D + Sprite3D)
├── player.tscn        ship: movement, dash, shooting, HP
├── laser.tscn         player projectile
├── meteor.tscn        meteor / aimed projectile
├── obstacle.tscn      static obstacle, collision box fitted from mesh AABB
├── pet.tscn           coin-producing companion
├── hud.tscn │ levelup.tscn │ boss_banner.tscn │ game_over.tscn
└── *.gdshader         procedural sky, noise-displaced floor
```

Almost all UI is **built in code** inside thin `Control` scenes — the `.tscn` files only carry
a root node and a script, which keeps the scene tree small and the layout version-controllable.

---

## 🚀 Running from source

1. Open the folder with **Godot 4.7.x** (the project file is `project.godot`)
2. Press **F5** — the main scene is `main_menu.tscn`

## 📦 Exporting a build

`export_presets.cfg` already contains a Windows Desktop preset (single file, PCK embedded).

From the editor: **Project → Export → Windows Desktop → Export Project**.

From the command line:

```bash
godot --headless --path . --export-release "Windows Desktop" build/game.exe
```

---

## 💾 Save data

```
Windows: %APPDATA%\Godot\app_userdata\space shooter 3d\save.cfg
```

The save is **not** inside the executable — a fresh machine starts a fresh run.
The shop has a **Reset save** button (click twice to confirm).

---

## 📄 Assets & license

No license is granted. Code and assets are all rights reserved.

The 3D models in `graphics/` come from a third-party asset pack, and some images in `picture/`
are third-party artwork; they are **not** covered by any license this project could grant.
