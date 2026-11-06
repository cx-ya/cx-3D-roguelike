extends Node

# ===================== 局内（肉鸽）升级池 =====================
# 拆成两类：功能性（带机制的） / 数值（纯加成的）
# 抽卡规则：第 1 个位置一定给功能性，第 2、3 个位置给数值
const RUN_POOL_FUNC: Array = [
	{"id": "wave_shot",  "name": "波动弹道", "desc": "子弹左右小幅摆动", "max": 1},
	{"id": "shield",     "name": "能量护盾", "desc": "抵挡一次伤害，30 秒充能", "max": 1},
	{"id": "dodge_shot", "name": "闪避射击", "desc": "完美闪避时直线发射 3 颗（30 秒 CD）", "max": 1},
	{"id": "pet",        "name": "宠物",     "desc": "多一只宠物，每 7 秒掉金币（每多一只 -1 秒）", "max": 5},
	{"id": "ult_cd",     "name": "大招冷却", "desc": "大招间隔 -3 秒", "max": 3},
	{"id": "ult_extra",  "name": "大招增强", "desc": "大招从 5 发变成 7 发", "max": 1},
	{"id": "coin_luck",  "name": "贪婪之触", "desc": "陨石掉金币概率 30%→60%，且每次 +1", "max": 1},
]

const RUN_POOL_STAT: Array = [
	{"id": "shot_count",  "name": "多联发射", "desc": "每次射击 +1 颗子弹", "max": 3},
	{"id": "fire_rate",   "name": "快速装填", "desc": "射击间隔 -0.1 秒", "max": 9},
	{"id": "pierce_plus", "name": "额外穿透", "desc": "激光穿透 +1", "max": 3},
	{"id": "dash_charge", "name": "冲刺充能", "desc": "冲刺冷却 -0.5 秒", "max": 3},
	{"id": "range_plus",  "name": "超远射程", "desc": "激光射程 +8 米", "max": 3},
]

var run_levels: Dictionary = {}

# 局内派生值（每次升级都重算）
var shot_count: int = 1
var shoot_interval: float = 1.0      # 射击间隔
var ultimate_interval: float = 25.0  # 大招间隔
var ultimate_bullets: int = 5        # 大招发数
var ultimate_unlocked: bool = false
var coin_chance: float = 0.3         # 陨石掉金币概率
var coin_amount: int = 1             # 每次掉多少

const BASE_SHOOT_INTERVAL := 1.0
const MIN_SHOOT_INTERVAL := 0.1      # 装填升满 = 1.0 - 0.9
const BASE_ULTIMATE_INTERVAL := 25.0
const ULTIMATE_INTERVAL := 25.0
const ULTIMATE_BASE_BULLETS := 5
const ULTIMATE_BULLETS := 5          # 兼容旧引用
const BASE_COIN_CHANCE := 0.3
const BASE_COIN_AMOUNT := 1

# 宠物参数
const PET_COIN_BASE_INTERVAL := 7.0  # 一只宠物 7 秒一块钱
const PET_COIN_MIN_INTERVAL := 1.0

# 一次升级弹几个选项，前几个固定是功能性
const LEVELUP_OPTIONS := 5
const FUNC_SLOTS := 3

func run_level(id: String) -> int:
	return int(run_levels.get(id, 0))

# 某池子里还能选的项
func _available(pool: Array) -> Array:
	var out: Array = []
	for item in pool:
		var id := String(item["id"])
		if run_level(id) < int(item["max"]):
			out.append(item)
	return out

# 🌟 抽 n 个：前 3 个固定功能性，剩下的给数值
func roll_run_options(n: int) -> Array:
	var result: Array = []
	
	var funcs := _available(RUN_POOL_FUNC)
	funcs.shuffle()
	for i in mini(FUNC_SLOTS, funcs.size()):
		result.append(funcs[i])
	
	var stats := _available(RUN_POOL_STAT)
	stats.shuffle()
	for item in stats:
		if result.size() >= n:
			break
		result.append(item)
	
	# 数值也被拿光了 → 用剩下的功能性补满
	if result.size() < n:
		for item in funcs:
			if result.size() >= n:
				break
			if not result.has(item):
				result.append(item)
	
	return result.slice(0, n)

# 宠物的金币掉落间隔：7 秒，每多一只减 1 秒
func pet_coin_interval() -> float:
	var pets := run_level("pet")
	if pets <= 0:
		return PET_COIN_BASE_INTERVAL
	return maxf(PET_COIN_MIN_INTERVAL, PET_COIN_BASE_INTERVAL - (pets - 1) * 1.0)

func take_run_upgrade(item: Dictionary) -> void:
	var id := String(item["id"])
	run_levels[id] = run_level(id) + 1
	apply_run_upgrades()
	run_upgrade_gained.emit(id)

# 局内加成 → 实际数值
func apply_run_upgrades() -> void:
	shot_count = 1 + run_level("shot_count")
	shoot_interval = maxf(MIN_SHOOT_INTERVAL, BASE_SHOOT_INTERVAL - run_level("fire_rate") * 0.1)
	coin_chance = BASE_COIN_CHANCE + (0.3 if run_level("coin_luck") > 0 else 0.0)
	coin_amount = BASE_COIN_AMOUNT + (1 if run_level("coin_luck") > 0 else 0)
	if run_level("wave_shot") > 0:
		current_trajectory = LaserTrajectory.SINE
	apply_upgrades()

# ===================== 局内等级（击杀陨石升级）=====================
signal level_changed(level: int)
signal kills_changed(kills: int, target: int)
signal level_up(new_level: int)          # 升级了 → Game 弹三选一
signal run_upgrade_gained(id: String)    # 局内升级拿到（宠物靠它生成）
signal perfect_dodge                     # 完美闪避（冲刺撞碎陨石）

# 升到下一级需要累计击杀数：一共 10 级（越往后越陡）
const KILL_THRESHOLDS: Array = [25, 50, 100, 200, 320, 500, 750, 1100, 1600, 2200]

var level: int = 1
var kills: int = 0
var last_run_victory: bool = false   # 上一局是不是打赢了 BOSS（结算画面用）
var pending_picks: int = 0           # 待领的免费三选一次数（BOSS 出场送 5 次）

var MAX_LEVEL: int = KILL_THRESHOLDS.size() + 1

# 每局开始清空（Game._ready 调用）
func reset_run() -> void:
	level = 1
	kills = 0
	pending_picks = 0
	meteor_speed_mult = 1.0
	run_levels.clear()
	current_trajectory = LaserTrajectory.STRAIGHT
	apply_run_upgrades()      # 按"没有局内加成"重算一遍
	level_changed.emit(level)
	kills_changed.emit(kills, kill_target())

# 当前等级升到下一级需要多少击杀
func kill_target() -> int:
	if level >= MAX_LEVEL:
		return int(KILL_THRESHOLDS[-1])
	return int(KILL_THRESHOLDS[level - 1])

# 到达某个等级所需的累计击杀（等级 3 → 50 颗）
func kills_for_level(lv: int) -> int:
	if lv <= 1:
		return 0
	return int(KILL_THRESHOLDS[mini(lv - 2, KILL_THRESHOLDS.size() - 1)])

# 🌟 干掉一颗陨石
func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills, kill_target())
	
	# 一次可能连跨好几级（比如开挂），所以用 while
	while level < MAX_LEVEL and kills >= int(KILL_THRESHOLDS[level - 1]):
		level += 1
		level_changed.emit(level)
		level_up.emit(level)

# ===================== 货币 & 升级（游戏外成长）=====================
signal currency_changed(value: int)
signal upgrade_level_changed(id: String, level: int)

const SAVE_PATH := "user://save.cfg"

# 🌟 商品表：改这里就能加/改商品，商店 UI 会自动生成卡片
const UPGRADES: Array = [
	{"id": "laser_pierce",  "name": "激光穿透", "desc": "激光能多穿透 1 个目标", "base": 50, "growth": 1.6, "max": 10},
	{"id": "laser_range",   "name": "激光射程", "desc": "射程 +5 米",            "base": 40, "growth": 1.5, "max": 12},
	{"id": "dash_cooldown", "name": "冲刺冷却", "desc": "冷却 -0.35 秒",         "base": 60, "growth": 1.6, "max": 10},
	{"id": "player_max_hp", "name": "血量上限", "desc": "血上限 +20",            "base": 80, "growth": 1.7, "max": 10},
	{"id": "ultimate",      "name": "大招：五连发", "desc": "每 25 秒自动向前并列发射 5 颗子弹（一次性）", "base": 150, "growth": 1.0, "max": 1},
	{"id": "ultimate_cd",   "name": "大招冷却",   "desc": "大招间隔 -2 秒", "base": 120, "growth": 1.6, "max": 8, "requires": "ultimate"},
	{"id": "ultimate_ammo", "name": "大招齐射",   "desc": "大招多发射 1 颗", "base": 100, "growth": 1.5, "max": 6, "requires": "ultimate"},
]

# 基础值：永远不改，升级只加等级，实际生效值由 apply_upgrades() 推导
const BASE_LASER_PIERCE := 1
const BASE_LASER_RANGE := -30.0
const BASE_DASH_COOLDOWN := 4.0
const BASE_PLAYER_HP := 100
const BASE_BULLET_TIME_HOLD := 0.7

# 货币系统
var currency: int = 0
# 每个升级的等级：id -> int
var upgrade_levels: Dictionary = {}

# 激光属性
var laser_pierce: int = 1
var laser_delay: float = 0.4 
var laser_range: float = -30   # 射程：飞到 z <= 这个值就自动消失

# 陨石属性
var meteor_delay: float = 1.0 
var meteor_damage: int = 50   # 撞到玩家扣多少血

# 障碍物属性（撞上扣血，不再是一击必死）
var obstacle_damage: int = 20

# 🌟 统一的"死亡平面"：障碍物/陨石飞过这个 z 就销毁
# 相机平时在 z=4.29，开场俯冲最远到 z≈11，取 25 保证一定在画面外
var despawn_z: float = 25.0

# 🌟 陨石速度倍率（BOSS 半血狂暴时变 2）
var meteor_speed_mult: float = 1.0

# 🌟 玩家血量（上限放全局，后面升级/血条 UI 直接读这里）
var player_max_hp: int = 100

# 🌟 开场快进期间 = 真·无敌（不然 60 秒的陨石雨会在开局直接把玩家撞死）
# 默认 false，由 player 报开场后置 true，快进结束再置回 false
var intro_active: bool = false

# 🌟 新增：冲刺冷却时间（秒）
var dash_cooldown: float = 4
# 弹道枚举（预留）
enum LaserTrajectory { STRAIGHT, SPIRAL, HOMING, SINE }
var current_trajectory: LaserTrajectory = LaserTrajectory.STRAIGHT

# 🌟 子弹时间（冲刺时触发）
# 🌟 广播信号：Game 收到后推拉镜头
signal bullet_time_started
signal bullet_time_ended

var bullet_time_scale: float = 0.15   # 慢放倍率
var bullet_time_hold: float = 0.7     # 低倍速保持时长（真实秒）
var bullet_time_fade: float = 0.5     # 回正缓动时长（真实秒）
var _bt_left: float = 0.0             # 剩余真实时间，<=0 表示未激活

func _ready() -> void:
	load_game()

# ===================== 商店 / 存档 =====================

func level_of(id: String) -> int:
	return int(upgrade_levels.get(id, 0))

# 价格 = 基础价 × 涨价倍率^当前等级
func price_of(item: Dictionary) -> int:
	return int(round(float(item["base"]) * pow(float(item["growth"]), level_of(String(item["id"])))))

func is_maxed(item: Dictionary) -> bool:
	return level_of(String(item["id"])) >= int(item["max"])

# 🌟 前置条件：比如大招冷却必须先买「大招」解锁
func is_locked(item: Dictionary) -> bool:
	var req := String(item.get("requires", ""))
	return req != "" and level_of(req) <= 0

# 买一个升级。返回 0=成功 1=已满级 2=钱不够 3=未解锁
func buy_upgrade(item: Dictionary) -> int:
	var id := String(item["id"])
	if is_locked(item):
		return 3
	if is_maxed(item):
		return 1
	var price := price_of(item)
	if currency < price:
		return 2
	
	currency -= price
	upgrade_levels[id] = level_of(id) + 1
	apply_upgrades()
	
	currency_changed.emit(currency)
	upgrade_level_changed.emit(id, upgrade_levels[id])
	save_game()
	return 0

func add_currency(amount: int) -> void:
	currency = maxi(currency + amount, 0)
	currency_changed.emit(currency)

# 🌟 等级 → 实际数值。全项目只有这里能推导，别在别处直接改这些值
# 公式 = 基础值 + 商店（元）等级 + 局内（肉鸽）等级
func apply_upgrades() -> void:
	laser_pierce = BASE_LASER_PIERCE + level_of("laser_pierce") + run_level("pierce_plus")
	laser_range = BASE_LASER_RANGE - level_of("laser_range") * 5.0 - run_level("range_plus") * 8.0
	dash_cooldown = maxf(0.5, BASE_DASH_COOLDOWN - level_of("dash_cooldown") * 0.35 - run_level("dash_charge") * 0.5)
	player_max_hp = BASE_PLAYER_HP + level_of("player_max_hp") * 20
	# 大招：商店（冷却/齐射）+ 局内（超载）两边的加成合成一处
	ultimate_interval = maxf(8.0, BASE_ULTIMATE_INTERVAL - level_of("ultimate_cd") * 2.0 - run_level("ult_cd") * 3.0)
	ultimate_bullets = ULTIMATE_BASE_BULLETS + level_of("ultimate_ammo") + run_level("ult_extra") * 2
	# 子弹时间时长固定，没有对应升级
	bullet_time_hold = BASE_BULLET_TIME_HOLD
	# 商店里买过大招才解锁
	ultimate_unlocked = level_of("ultimate") > 0

# 🌟 某个升级在指定等级下的"效果文字"，商店卡片用它显示 当前 → 下一级
func effect_text(id: String, level: int) -> String:
	match id:
		"laser_pierce":
			return "穿透 %d 个目标" % (BASE_LASER_PIERCE + level)
		"laser_range":
			return "射程 %.0f 米" % absf(BASE_LASER_RANGE - level * 5.0)
		"dash_cooldown":
			return "冷却 %.1f 秒" % maxf(0.5, BASE_DASH_COOLDOWN - level * 0.35)
		"player_max_hp":
			return "血上限 %d" % (BASE_PLAYER_HP + level * 20)
		"ultimate":
			return "未解锁" if level < 1 else "每 %.0f 秒齐射" % maxf(8.0, BASE_ULTIMATE_INTERVAL - level_of("ultimate_cd") * 2.0)
		"ultimate_cd":
			return "大招每 %.0f 秒" % maxf(8.0, BASE_ULTIMATE_INTERVAL - level * 2.0)
		"ultimate_ammo":
			return "大招 %d 发" % (ULTIMATE_BASE_BULLETS + level)
	return ""

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "currency", currency)
	for item in UPGRADES:
		var id := String(item["id"])
		cfg.set_value("upgrades", id, level_of(id))
	cfg.save(SAVE_PATH)

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		currency = int(cfg.get_value("player", "currency", 0))
		for item in UPGRADES:
			var id := String(item["id"])
			upgrade_levels[id] = int(cfg.get_value("upgrades", id, 0))
	apply_upgrades()

# 🌟 清空存档（游戏内「重置存档」按钮用）
func reset_save() -> void:
	currency = 0
	upgrade_levels.clear()
	apply_upgrades()
	save_game()
	currency_changed.emit(currency)
	for item in UPGRADES:
		upgrade_level_changed.emit(String(item["id"]), 0)

# ===================== 子弹时间 =====================

# 触发子弹时间（可被打断，重复调用只刷新计时）
func start_bullet_time() -> void:
	Engine.time_scale = bullet_time_scale
	_bt_left = bullet_time_hold + bullet_time_fade
	bullet_time_started.emit()

# 🌟 强制结束并复位。切场景前必须调，否则残留在 _process 里的计时器
# 会把新场景的 time_scale 又踩回 0.15（看起来像卡死）
func stop_bullet_time() -> void:
	_bt_left = 0.0
	Engine.time_scale = 1.0
	bullet_time_ended.emit()

# 用真实时间倒计时，最后一段平滑回到 1.0
# 注意：_process 的 delta 是被 time_scale 缩放过的，所以要除回来
func _process(delta: float) -> void:
	if _bt_left <= 0.0:
		return

	_bt_left -= delta / maxf(Engine.time_scale, 0.001)

	if _bt_left <= bullet_time_fade:
		var t := clampf(_bt_left / bullet_time_fade, 0.0, 1.0)
		Engine.time_scale = lerpf(1.0, bullet_time_scale, t)

	if _bt_left <= 0.0:
		Engine.time_scale = 1.0
		bullet_time_ended.emit()
