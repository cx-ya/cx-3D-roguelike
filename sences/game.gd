extends Node3D

var laser_sence: PackedScene = preload("res://sences/laser.tscn")
var meteor_sence: PackedScene = preload("res://sences/meteor.tscn")
var neurosama_sence: PackedScene = preload("res://sences/neurosama.tscn")
var amazing_sence: PackedScene = preload("res://sences/amazing.tscn")
var obstacle_sence: PackedScene = preload("res://sences/obstacle.tscn")
var pet_sence: PackedScene = preload("res://sences/pet.tscn")
var boss_sence: PackedScene = preload("res://sences/node_3d.tscn")

# ================= BOSS =================
const BOSS_LEVEL := 2          # 玩家到几级时 BOSS 苏醒（2 级 = 25 颗）
const BOSS_POS := Vector3(0, 0, -20)
const BOSS_FREE_PICKS := 5     # BOSS 出场送的免费强化的次数
var boss: Node3D = null

# ================= 宠物 =================
const PET_SCALE := 0.6            # 缩小比例
const PET_FOLLOW_SPEED := 8.0
var pets: Array = []               # [{ "node": Node3D, "offset": Vector3 }]
var pet_coin_timer: float = 0.0
var game_size = {
	'left': -35,
	'right': 35,
	'front': -2,      # 开局铺场：近端
	'back': -85,      # 开局铺场：远端（伸到补刷生成线 -80 的后面一点）
	'spawn_z': -80    # 之后定时补刷的生成线
}
# amazing 相对玩家的生成偏移（-X 是屏幕左边，+Z 稍微往镜头方向，别被飞船挡住）
var amazing_offset: Vector3 = Vector3(-2.0, 0.0, 0.6)

# ================= 镜头聚焦（子弹时间时对准玩家再推近）=================
@onready var camera: Camera3D = $Camera3D
@onready var player: Node3D = $Player
@onready var levelup: Control = $UI/LevelUp

var cam_base_transform: Transform3D   # 原始机位，回正用
var cam_base_fov: float

var focus_zoom: float = 0.6        # FOV 缩到 60%，越小越“放大”
var focus_distance: float = 0.75   # 相机拉近到原来的 75%
var focus_in_time: float = 0.18    # 推进时长（真实秒）
var focus_out_time: float = 0.5    # 回正时长（真实秒）

var _focus: float = 0.0            # 当前混合值：0 = 原机位，1 = 完全聚焦
var _focus_target: float = 0.0     # 目标混合值

# ================= 开场：快进 + 飞入镜头 =================
# 触发源在 player.gd（飞船自己飞进来），这里只负责「时间」和「镜头」
var intro_time: float = 3.0          # 开场持续多久（真实秒，由 player 的信号传入）
var intro_game_time: float = 40.0    # 这段时间里快进掉多少「游戏秒」
var intro_distance: float = 2.6      # 起始机位离玩家多远（倍数）
var intro_fov_scale: float = 1.2     # 起始 FOV 放大倍数（速度感）
var intro_roll_deg: float = 25.0     # 起始镜头滚转角度（压弯）
var intro_side: float = 6.0          # 起始机位往右偏多少（斜着切入）
var _intro_t: float = 1.0            # 0 → 1，默认 1 = 没在播

func _ready() -> void:
	cam_base_transform = camera.global_transform
	cam_base_fov = camera.fov
	
	# 🌟 每局重置等级 / 击杀数
	Global.reset_run()
	Global.level_up.connect(_on_level_up)
	Global.kills_changed.connect(_on_kills_changed)
	
	# 🌟 开局一次性铺一片障碍物
	_spawn_obstacles(randi_range(50, 60))
	
	# 🌟 Global 广播子弹时间开始/结束 → 镜头推拉
	# 触发源只有一个：陨石被冲刺撞碎（meteor.gd::_on_body_entered）
	Global.bullet_time_started.connect(_on_bullet_time_started)
	Global.bullet_time_ended.connect(_on_bullet_time_ended)
	
	# 🚀 开场交给 Player：它自己飞进来，用两个信号通知我
	player.intro_started.connect(_on_intro_started)
	player.intro_camera_requested.connect(_on_intro_camera_requested)
	player.intro_finished.connect(_spawn_boss)     # 🌟 玩家完全落位后再放 BOSS
	player.ultimate_fired.connect(_on_player_ultimate_fired)
	player.dodge_shots_requested.connect(_on_dodge_shots_requested)
	player.play_intro()
	
	# 🌟 局内升级：拿到"宠物"就生成一只
	Global.run_upgrade_gained.connect(_on_run_upgrade_gained)
	
	# 🌟 HUD 接上玩家（血量 / 货币）
	player.add_to_group("player")
	($UI/HUD as Control).bind_player(player)

# ① 飞船报开场（duration）→ 时间踩到底
func _on_intro_started(duration: float) -> void:
	intro_time = maxf(duration, 0.001)
	Engine.time_scale = _intro_start_speed()
	Global.intro_active = true

# ② 飞船请镜头 → 开播飞入镜头
func _on_intro_camera_requested() -> void:
	_intro_t = 0.0

# 🌟 在场地里随机撒一批障碍物（只在开局调用一次）
func _spawn_obstacles(count: int) -> void:
	for i in count:
		var obstacle = obstacle_sence.instantiate()
		$Projectlies.add_child(obstacle)
		obstacle.player_damaged.connect(_on_player_damaged)
		obstacle.set_xz_pos(
			randf_range(game_size['left'], game_size['right']),
			randf_range(game_size['front'], game_size['back']),
		)

func _on_player_shoot_laser(pos: Vector3) -> void:
	_spawn_laser_row(pos, Global.shot_count, false)

# 🌟 大招：并列发射，直线飞行（发数可由「大招增强」升到 7）
func _on_player_ultimate_fired(pos: Vector3) -> void:
	_spawn_laser_row(pos, Global.ultimate_bullets, true)

# 🌟 完美闪避射击：并列 3 颗，直线飞行
func _on_dodge_shots_requested(pos: Vector3) -> void:
	_spawn_laser_row(pos, 3, true)

# ================= 宠物 =================

func _on_run_upgrade_gained(id: String) -> void:
	if id == "pet":
		_spawn_pet()

# 在飞机后方的随机位置生成一只，缩小一圈
func _spawn_pet() -> void:
	var pet := pet_sence.instantiate() as Node3D
	$Projectlies.add_child(pet)
	pet.scale = Vector3.ONE * PET_SCALE
	
	# 🚨 相机在 z = 4.29，Z 不能给太大，否则宠物直接生成在相机背后（看不见）
	# 再整体往前挪 3：1.2~2.8 → -1.8~-0.2
	var side := 1.0 if randf() < 0.5 else -1.0
	var offset := Vector3(
		side * randf_range(1.2, 2.8),
		randf_range(-0.8, 0.2),
		randf_range(-1.8, -0.2),    # 往前 3（往屏幕里、往船头方向）
	)
	pet.global_position = player.global_position + offset
	pets.append({"node": pet, "offset": offset})
	
	if pets.size() == 1:
		pet_coin_timer = Global.pet_coin_interval()
	print("🐾 宠物数量：%d  生成位置偏移：%s" % [pets.size(), str(offset)])

# 跟着飞机跑 + 定时上供金币
func _update_pets(delta: float) -> void:
	for entry in pets:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var goal: Vector3 = player.global_position + entry["offset"]
		node.global_position = node.global_position.lerp(goal, clampf(PET_FOLLOW_SPEED * delta, 0.0, 1.0))
	
	var count := Global.run_level("pet")
	if count <= 0:
		return
	
	pet_coin_timer -= delta
	if pet_coin_timer <= 0.0:
		pet_coin_timer = Global.pet_coin_interval()
		Global.add_currency(count)

# 横向铺开一排激光
# force_straight = true 时无视当前弹道（大招子弹只往前飞）
func _spawn_laser_row(pos: Vector3, count: int, force_straight: bool) -> void:
	for i in count:
		var laser = laser_sence.instantiate() as Area3D
		$Projectlies.add_child(laser)
		var spread := (i - (count - 1) * 0.5) * 1.2
		laser.position = pos + Vector3(spread, 0, -1.2)
		laser.force_straight = force_straight

func _on_meteor_timer_timeout() -> void:
	var meteor = meteor_sence.instantiate()
	$Projectlies.add_child(meteor)
	meteor.meteor_hit.connect(_on_meteor_hit)
	# 🌟 新增：陨石撞到玩家的扣血信号
	meteor.player_damaged.connect(_on_player_damaged)

# 🌟 统一入口：陨石 / 障碍物撞到玩家，都在这里转达给 Player 扣血
func _on_player_damaged(damage: int) -> void:
	$Player.take_damage(damage)

# 🌟 接收 2 个参数
func _on_meteor_hit(hit_pos: Vector3, meteor_node: Area3D) -> void:
	# 🌟 每击杀一颗陨石都计数（用来升级），和 30% 掉金币无关
	Global.add_kill()
	
	if randf() < Global.coin_chance:
		var neurosama2 = neurosama_sence.instantiate()
		$Projectlies.add_child(neurosama2)
		neurosama2.global_position = hit_pos 
		# 🌟 走 Global 的统一入口，这样 UI 能收到 currency_changed 信号
		Global.add_currency(Global.coin_amount)
	# 🌟 删除了原本的 else 和 Global.meteor_delay = 0.3

# 🌟 升级了：游戏暂停，弹出三选一
func _on_level_up(new_level: int) -> void:
	levelup.open(new_level)

# ================= BOSS =================

# 🌟 到 3 级之后，再多吃 1 颗陨石，BOSS 才苏醒开始攻击
# （3 级需要 50 颗 → 第 51 颗时苏醒）
func _on_kills_changed(kills: int, _target: int) -> void:
	if boss == null or bool(boss.get("is_attacking")):
		return
	if Global.level < BOSS_LEVEL:
		return
	if kills > Global.kills_for_level(BOSS_LEVEL):
		_activate_boss()

# 玩家完全飞进场后才放出来（introduction 结束信号触发），站着不动、免疫
func _spawn_boss() -> void:
	if boss != null:
		return
	boss = boss_sence.instantiate() as Node3D
	$Projectlies.add_child(boss)
	# 高度交给 boss.gd 自己从地底下升上来，这里只定位 x / z
	boss.position.x = BOSS_POS.x
	boss.position.z = BOSS_POS.z
	
	boss.defeated.connect(_on_boss_defeated)
	boss.projectile_requested.connect(_on_boss_projectile)
	($UI/HUD as Control).bind_boss(boss)
	print("👹 BOSS 就位（尚未苏醒）")

# 🌟 3 级时苏醒：横幅 + 天黑 + 开始攻击 + 送 5 次免费强化
func _activate_boss() -> void:
	($UI/BossBanner as Control).show_banner(int(boss.get("max_hits")))
	boss.activate()
	_darken_sky()
	print("👹 BOSS 苏醒！")
	
	await get_tree().create_timer(1.8).timeout
	Global.pending_picks += BOSS_FREE_PICKS
	levelup.open(Global.level, true)

# 天色调暗：天空 shader 的三个颜色 + 平行光强度一起压暗
func _darken_sky() -> void:
	var env := ($WorldEnvironment as WorldEnvironment).environment
	if env != null and env.sky != null:
		var mat := env.sky.sky_material as ShaderMaterial
		if mat != null:
			for param in ["zenith_color", "horizon_color", "ground_color"]:
				var from = mat.get_shader_parameter(param)
				if typeof(from) != TYPE_VECTOR3:
					continue
				var to: Vector3 = from * 0.25
				var tw := create_tween()
				tw.tween_method(func(v: Vector3): mat.set_shader_parameter(param, v), from, to, 2.0)
	
	var light := $DirectionalLight3D as DirectionalLight3D
	if light != null:
		var tw2 := create_tween()
		tw2.tween_property(light, "light_energy", 0.3, 2.0)

# 🌟 BOSS 发射的定向陨石：只取一次方向，之后直线飞
func _on_boss_projectile(from: Vector3, dir: Vector3, speed: float) -> void:
	var meteor = meteor_sence.instantiate()
	$Projectlies.add_child(meteor)
	meteor.make_projectile(from, dir, speed)
	meteor.meteor_hit.connect(_on_meteor_hit)
	meteor.player_damaged.connect(_on_player_damaged)

func _on_boss_defeated() -> void:
	print("🎉 BOSS 击破，本局胜利")
	await get_tree().create_timer(2.0).timeout
	Global.last_run_victory = true
	Global.save_game()
	Global.stop_bullet_time()
	get_tree().change_scene_to_file("res://sences/game_over.tscn")

# ================= 镜头 / 子弹时间 =================

# 🌟 子弹时间开始：镜头瞄准玩家 + 推近 + 左边弹个 amazing
func _on_bullet_time_started() -> void:
	_focus_target = 1.0
	_spawn_amazing()

# 🌟 实例化 amazing 到玩家左边（它自己在 _ready 里转完就自毁）
func _spawn_amazing() -> void:
	var amazing := amazing_sence.instantiate() as Node3D
	add_child(amazing)
	amazing.global_position = player.global_position + amazing_offset

# 🌟 子弹时间结束：镜头回正
func _on_bullet_time_ended() -> void:
	_focus_target = 0.0

# 用真实时间推进混合值（慢放时镜头也不能被拖慢）
func _process(delta: float) -> void:
	_update_intro(delta)
	_update_pets(delta)
	
	if not is_equal_approx(_focus, _focus_target):
		var real_delta := delta / maxf(Engine.time_scale, 0.001)
		var duration := focus_in_time if _focus_target > _focus else focus_out_time
		_focus = move_toward(_focus, _focus_target, real_delta / duration)
	
	# 每帧都应用：聚焦期间持续跟随玩家，别让冲刺位移把玩家甩出画面
	_apply_focus(_focus)

# ================= 开场快进 =================

# 线性从 S 降到 1.0 时，intro_time 秒内的总游戏时间 = intro_time * (S + 1) / 2
# 反解出要让 2 秒跑完 15 秒所需的起始倍速 S
func _intro_start_speed() -> float:
	if intro_time <= 0.0:
		return 1.0
	return 2.0 * intro_game_time / intro_time - 1.0

func _update_intro(delta: float) -> void:
	if _intro_t >= 1.0 or intro_time <= 0.0:
		return
	
	# delta 是被 time_scale 放大过的，要换算回真实时间，否则开场会“自己加速自己”
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_intro_t = minf(_intro_t + real_delta / intro_time, 1.0)
	Engine.time_scale = lerpf(_intro_start_speed(), 1.0, _intro_t)
	
	if _intro_t >= 1.0:
		Engine.time_scale = 1.0
		Global.intro_active = false   # 快进结束，恢复正常判定与伤害

# 把 _focus(0~1) 映射成实际的机位 + FOV，再叠一层开场飞入
func _apply_focus(blend: float) -> void:
	var e := smoothstep(0.0, 1.0, blend)
	
	# 1. FOV：75 → 45，纯物理意义上的“放大”
	var fov_end := lerpf(cam_base_fov, cam_base_fov * focus_zoom, e)
	
	# 2. 机位：从原机位插值到“玩家正后上方”，保证玩家在画面正中心
	var cam_end := cam_base_transform.interpolate_with(_player_camera_transform(), e)
	
	# 3. 开场还没播完：从“远处 + 广角 + 压弯”的机位俯冲进来
	if _intro_t < 1.0:
		var e_in := smoothstep(0.0, 1.0, _intro_t)
		var anchor := _player_anchor()
		var cam_start := cam_end
		# 位置：沿“玩家岗位→相机”的方向拉远，再往右偏一点，形成斜切
		cam_start.origin = anchor + (cam_end.origin - anchor) * intro_distance + Vector3(intro_side, 0, 0)
		# 姿态：绕自己的视线轴滚转，落地时自动归零
		cam_start.basis = cam_start.basis.rotated(cam_start.basis.z, deg_to_rad(intro_roll_deg))
		
		camera.fov = lerpf(cam_base_fov * intro_fov_scale, fov_end, e_in)
		camera.global_transform = cam_start.interpolate_with(cam_end, e_in)
		return
	
	camera.fov = fov_end
	camera.global_transform = cam_end

# 计算“正对玩家”的机位：位置 = 玩家位置 + 原始偏移 × focus_distance，朝向 = looking_at(玩家)
func _player_camera_transform() -> Transform3D:
	var player_pos := _player_anchor()
	var offset := cam_base_transform.origin - player_pos   # 原始 相机→玩家 的偏移
	var target_pos := player_pos + offset * focus_distance
	# 用原相机的 up 轴，避免镜头翻转/歪掉
	var up := cam_base_transform.basis.y.normalized()
	return Transform3D(Basis(), target_pos).looking_at(player_pos, up)

# 镜头该盯着谁：开场期间盯“岗位”，不追那架还在飞进来的飞船
func _player_anchor() -> Vector3:
	if _intro_t < 1.0:
		return player.home_position
	return player.global_position


func _on_obstacle_timer_timeout() -> void:
	for i in randi_range(3,6):
		var obstacle = obstacle_sence.instantiate()
		$Projectlies.add_child(obstacle)
		obstacle.player_damaged.connect(_on_player_damaged)
		obstacle.set_xz_pos(
			randf_range(game_size['left'], game_size['right']),
			randf_range(game_size['spawn_z'], game_size['spawn_z'] + 5),
		)
