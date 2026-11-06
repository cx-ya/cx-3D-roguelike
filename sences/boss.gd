extends Area3D

# ===================== BOSS =====================
# 开局就出现（但不打人），玩家到 3 级后 activate() 才真正开打
# 阶段：1 普通 → 2 半血狂暴 → 3 低血横扫

signal hp_changed(current_hits: int, max_hits: int)
signal defeated
# 🌟 请求发射一颗定向陨石：(出生点, 飞行方向, 速度)
signal projectile_requested(from: Vector3, dir: Vector3, speed: float)

@export var max_hits: int = 150         # 被打中多少次死
@export var rise_from_y: float = -10.0  # 从多深的地方升起来
@export var rise_time: float = 3.0      # 升起来要多久
@export var rise_to_y: float = 2.0      # 升到多高停住
@export var model_scale: float = 3.0    # 整体放大倍数
@export var tilt_deg: float = 22.0      # 朝相机方向倾斜多少度（相机俯视 45°）

@export var attack_interval: float = 4.5   # 每隔几秒放一次技能
@export var projectile_speed: float = 15.0 # 投射物基础速度

@export var phase2_ratio: float = 0.5      # 掉到多少血进二阶段
@export var phase3_ratio: float = 0.25     # 掉到多少血进三阶段

var hits: int = 0
var is_alive: bool = true
var is_attacking: bool = false   # 开局 false：站着不动，随便打都免疫
var phase: int = 1
var _is_rising: bool = true
var _base_scale: Vector3 = Vector3.ONE
var _attack_timer: float = 4.0
var _pattern: int = 0
var _atk_speed_mult: float = 1.0
var _sweep_phase: float = 0.0
var _sfx: AudioStreamPlayer3D

const PATTERN_COUNT := 5
const PHASE3_COLUMNS := 11

func _ready() -> void:
	# 🚨 激光在 layer 3（值 4），不改 mask 就永远撞不到
	collision_mask |= 4
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	
	scale = Vector3.ONE * model_scale
	_base_scale = scale
	# 相机是 45° 俯视的，图片正对着 Z 会显得很"贴墙"，往相机方向倾一点
	rotation.x = -deg_to_rad(tilt_deg)
	
	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = preload("res://audio/explosion.wav")
	_sfx.volume_db = -10.0
	_sfx.max_distance = 300.0
	_sfx.unit_size = 30.0
	add_child(_sfx)
	
	# 🌟 没苏醒时灰蓝半透明，一眼看出"现在打不动它"
	var sleeping := get_node_or_null("Sprite3D") as Sprite3D
	if sleeping != null:
		sleeping.modulate = Color(0.55, 0.55, 0.7, 0.45)
	
	# 从地下开始，慢慢钻出来
	position.y = rise_from_y
	hp_changed.emit(0, max_hits)
	
	var tween := create_tween()
	# 🚨 开局时 Engine.time_scale 是 19 倍，不加这一行 BOSS 会"瞬间"冒出来
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "position:y", rise_to_y, rise_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): _is_rising = false)

# 🌟 玩家到 3 级：BOSS 醒过来
func activate() -> void:
	if is_attacking or not is_alive:
		return
	is_attacking = true
	_attack_timer = 1.2      # 醒来后 1.2 秒就放第一招
	phase = 1
	
	# 从半透明灰蓝恢复成正常颜色
	var sprite := get_node_or_null("Sprite3D") as Sprite3D
	if sprite != null:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.6)
	
	print("👹 BOSS 苏醒，开始攻击！")

# ---------------- 受击 ----------------

func _on_area_entered(area: Area3D) -> void:
	if not is_alive or not is_attacking:
		return   # 还没苏醒 = 无敌，激光穿过去
	if not area.has_method("destroy"):
		return
	
	area.destroy()
	_take_hit()

func _take_hit() -> void:
	if not is_alive:
		return
	hits += 1
	hp_changed.emit(hits, max_hits)
	
	var tw := create_tween()
	tw.tween_property(self, "scale", _base_scale * 1.06, 0.05)
	tw.tween_property(self, "scale", _base_scale, 0.08)
	
	var remain := float(max_hits - hits) / float(max_hits)
	if phase < 3 and remain <= phase3_ratio:
		_enter_phase3()
	elif phase < 2 and remain <= phase2_ratio:
		_enter_phase2()
	
	if hits >= max_hits:
		_die()

# 🌟 二阶段：半血狂暴
func _enter_phase2() -> void:
	phase = 2
	Global.meteor_speed_mult = 3.0      # 场上自然陨石速度 ×3
	_atk_speed_mult = 1.5               # BOSS 自己的投射物也更快
	attack_interval *= 0.6
	print("🔥 BOSS 二阶段：陨石加速 ×3")
	
	var sprite := get_node_or_null("Sprite3D") as Sprite3D
	if sprite != null:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(1.0, 0.38, 0.38), 0.8)
	
	var tw2 := create_tween()
	tw2.tween_property(self, "rotation:z", 0.12, 0.4)

# 🌟 三阶段：从左到右不间断扫射
func _enter_phase3() -> void:
	phase = 3
	_atk_speed_mult = 1.5
	Global.meteor_speed_mult = 3.0
	print("💥 BOSS 三阶段：横向扫射！")
	
	var sprite := get_node_or_null("Sprite3D") as Sprite3D
	if sprite != null:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(1.0, 0.2, 0.2), 0.5)
	
	_phase3_sweep()

func _die() -> void:
	if not is_alive:
		return
	is_alive = false
	print("💀 BOSS 被击破！")
	defeated.emit()
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(_base_scale.x, 0.01, _base_scale.z), 0.6)
	tween.tween_property(self, "rotation:z", rotation.z + 0.8, 0.6)
	await tween.finished
	queue_free()

# ---------------- 攻击循环 ----------------

func _physics_process(delta: float) -> void:
	if not is_alive or _is_rising or not is_attacking:
		return
	if phase >= 3:
		return   # 三阶段走自己的扫射循环
	
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	
	_attack_timer = attack_interval
	_run_pattern(_pattern)
	_pattern = (_pattern + 1) % PATTERN_COUNT

func _play_sfx() -> void:
	if _sfx != null:
		_sfx.play()

# 只取一次玩家坐标，不追踪
func _target_pos() -> Vector3:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		return (p as Node3D).global_position
	return global_position + Vector3(0, 0, 10)

func _run_pattern(index: int) -> void:
	match index:
		0: _pattern_volley()
		1: _pattern_fan()
		2: _pattern_rain()
		3: _pattern_surround()
		4: _pattern_snipe()

# 🌟 技能一：左右两侧齐射 10 颗，连发 3 波
func _pattern_volley() -> void:
	for wave in 3:
		if not is_alive:
			return
		var target := _target_pos()
		for i in 12:
			var side := -1.0 if i < 6 else 1.0
			var lane := float(i % 6) - 2.5
			var from := global_position + Vector3(side * 9.0, lane * 1.5, 1.5)
			var dir := (target - from).normalized()
			projectile_requested.emit(from, dir, projectile_speed * _atk_speed_mult)
		_play_sfx()
		await get_tree().create_timer(0.36).timeout

# 🌟 技能二：扇形 9 连发
func _pattern_fan() -> void:
	var target := _target_pos()
	var base := (target - global_position).normalized()
	var right := base.cross(Vector3.UP).normalized()
	for i in 9:
		var t := (i - 4) * 0.14
		var dir := (base + right * t).normalized()
		projectile_requested.emit(global_position + dir * 3.0, dir, projectile_speed * _atk_speed_mult * 0.9)
	_play_sfx()

# 🌟 技能三：天降陨石雨
func _pattern_rain() -> void:
	var target := _target_pos()
	for i in 10:
		var x := (i - 4.5) * 3.0
		var from := Vector3(target.x + x, 16.0, target.z - 5.0)
		projectile_requested.emit(from, Vector3(0, -1, 0.15), 11.0 * _atk_speed_mult)
	_play_sfx()

# 🌟 技能四：十面埋伏 —— 绕着 BOSS 一圈生成，全部朝玩家汇聚
func _pattern_surround() -> void:
	var target := _target_pos()
	var n := 12
	for i in n:
		var ang := TAU * float(i) / float(n)
		var from := global_position + Vector3(cos(ang) * 8.0, sin(ang) * 5.0, -2.0)
		var dir := (target - from).normalized()
		projectile_requested.emit(from, dir, projectile_speed * _atk_speed_mult * 0.9)
	_play_sfx()

# 🌟 技能五：快速点射 6 发（每发重新瞄一次）
func _pattern_snipe() -> void:
	for i in 6:
		if not is_alive:
			return
		var target := _target_pos()
		var dir := (target - global_position).normalized()
		projectile_requested.emit(global_position + dir * 3.0, dir, projectile_speed * _atk_speed_mult * 1.6)
		_play_sfx()
		await get_tree().create_timer(0.18).timeout

# 🌟 三阶段：从左到右一列一列扫射，高度上下浮动，直到被打死
func _phase3_sweep() -> void:
	while is_alive:
		_sweep_phase += 0.75      # 每一轮整体上移/下移一点，形成波浪
		for i in PHASE3_COLUMNS:
			if not is_alive:
				return
			var target := _target_pos()
			# 出生高度按正弦上下浮动，躲在高处也不安全
			var wave := sin(float(i) * 0.85 + _sweep_phase) * 3.5
			var from := global_position + Vector3(-14.0 + i * 3.5, 0.6 + wave, 1.0)
			var dir := (target - from).normalized()
			projectile_requested.emit(from, dir, projectile_speed * _atk_speed_mult)
			if i % 3 == 0:
				_play_sfx()
			await get_tree().create_timer(0.13).timeout
		await get_tree().create_timer(0.45).timeout
