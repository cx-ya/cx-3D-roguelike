extends CharacterBody3D

var direction: float
var speed := 4

# --- 生命值（上限从全局读，方便以后升级 / 血条 UI）---
var hp: int = Global.player_max_hp

var recoil_pitch := 0.0
var recoil_back := 0.0

# --- 冲刺相关变量 ---
var last_d_press_time: float = -1.0
var last_a_press_time: float = -1.0
var dash_timer: float = 0.0
var is_dashing: bool = false

# ================= 无敌 =================
# 三个来源合成一个状态：冲刺 / 开场飞入 / 临时无敌（set_invincible）
var invincible_timer: float = 0.0   # 剩余无敌秒数
var is_invincible: bool = false     # 🌟 给外部读的：陨石、障碍物都靠它判断

# ================= 射击 / 大招计时 =================
var shoot_timer: float = 0.0        # 射击冷却（秒）
var ultimate_timer: float = 0.0     # 大招冷却（秒）

# ================= 护盾（一次性，抵挡一次伤害）=================
const SHIELD_CD := 30.0
var shield_ready: bool = false      # 有护盾且已充能
var shield_timer: float = 0.0       # 破盾后的充能倒计时

# ================= 完美闪避射击（3 颗直线，30 秒 CD）=================
const DODGE_CD := 30.0
var dodge_cd: float = 0.0
signal dodge_shots_requested(pos: Vector3)

func _ready() -> void:
	# 大招开局就进入冷却，而不是一进场就放
	ultimate_timer = Global.ultimate_interval
	# 局内拿到护盾就立刻可用
	shield_ready = Global.run_level("shield") > 0
	Global.perfect_dodge.connect(_on_perfect_dodge)
	hp_changed.emit(hp, Global.player_max_hp)

# 🌟 完美闪避（冲刺撞碎陨石）：直线补 3 发
func _on_perfect_dodge() -> void:
	if Global.run_level("dodge_shot") <= 0:
		return
	if dodge_cd > 0.0:
		return
	dodge_cd = DODGE_CD
	dodge_shots_requested.emit(global_position)

# 护盾 / 闪避射击的冷却推进
func _tick_run_abilities(delta: float) -> void:
	if Global.run_level("shield") > 0 and not shield_ready:
		shield_timer = maxf(shield_timer - delta, 0.0)
		if shield_timer <= 0.0:
			shield_ready = true
	
	if dodge_cd > 0.0:
		dodge_cd = maxf(dodge_cd - delta, 0.0)

# 通用无敌：给多少秒就无敌多少秒；重复调用取较长的一次，不会叠加
func set_invincible(duration: float) -> void:
	invincible_timer = maxf(invincible_timer, duration)
	is_invincible = true

# 每帧把三个来源合成一次（冲刺、开场、计时器）
func _refresh_invincible() -> void:
	is_invincible = invincible_timer > 0.0 or is_dashing or is_intro_playing

signal shoot_laser(pos: Vector3)
# 🌟 大招：并列发射 5 颗子弹
signal ultimate_fired(pos: Vector3)
# 🌟 冲刺信号（dir: 1为向右，-1为向左），给音效/残影预留
signal dash_started(dir: int)

# ================= 开场：飞船自己飞进来 =================
# ① 报开场（带时长）：Game 拿它去快进时间
signal intro_started(duration: float)
# ② 请镜头配合：Game 拿它去播飞入镜头
signal intro_camera_requested
# ③ 飞入结束（完全落位）：Game 拿它去放 BOSS
signal intro_finished
# 🌟 血量变化：HUD 靠它刷新
signal hp_changed(hp: int, max_hp: int)

var intro_time: float = 4.0                      # 飞入时长（真实秒）
var intro_offset: Vector3 = Vector3(0, 9, -55)   # 起点 = 岗位 + 这个偏移（远处高空）
var is_intro_playing: bool = false
var home_position: Vector3                       # 记得住岗位，飞完停在这
@export var intro_after_invincible: float = 3.0  # 🌟 落地后额外再送几秒无敌

# 开局飞入：把飞船挪到远处，再用 Tween 飞回岗位
func play_intro() -> void:
	if is_intro_playing:
		return
	
	home_position = position
	is_intro_playing = true
	
	intro_started.emit(intro_time)           # ① 先报开场
	position = home_position + intro_offset  # ② 挪到远处
	intro_camera_requested.emit()            # ③ 再请镜头跟上
	
	var tween = create_tween()
	# 🚨 开场时 time_scale 很高，这里必须用真实时间，否则 3 秒飞完的部分瞬间就结束了
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "position", home_position, intro_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(func():
		is_intro_playing = false
		set_invincible(intro_after_invincible)   # 🌟 落地后再送 3 秒缓冲无敌
		intro_finished.emit()
	)

func _physics_process(delta: float) -> void:
	# 无敌倒计时（用游戏时间：子弹时间里也一起变慢，符合直觉）
	if invincible_timer > 0.0:
		invincible_timer = maxf(invincible_timer - delta, 0.0)
	_refresh_invincible()
	
	# 护盾 / 闪避射击冷却
	_tick_run_abilities(delta)
	
	# 开场飞入期间：位置完全交给 Tween，物理、输入、冷却全部让开
	if is_intro_playing:
		velocity = Vector3.ZERO
		return
	
	# 更新冷却时间
	if dash_timer > 0:
		dash_timer -= delta

	# 检测输入和冷却
	check_dash_input()
	
	# 如果正在冲刺，跳过普通的移动和倾斜逻辑
	if is_dashing:
		# 🚨 冲刺位移完全交给 Tween，物理速度必须清零，否则 move_and_slide 会再推一段
		velocity = Vector3.ZERO
		move_and_slide()
		return

	direction = Input.get_axis("left", "right")
	velocity.x = direction * speed
	$craft_speederA.rotation.z = move_toward($craft_speederA.rotation.z, -direction / 2.0, delta)
	
	velocity.y = (sin(Time.get_ticks_msec() / 500.0) / 4.0 + sin(Time.get_ticks_msec() / 600.0) / 10) * 2.0
	
	move_and_slide()
	
	# 🌟 射击：有间隔，不能连点
	if shoot_timer > 0.0:
		shoot_timer -= delta
	if Input.is_action_just_pressed("Laser") and shoot_timer <= 0.0:
		shoot_timer = Global.shoot_interval
		shoot_laser.emit(global_position)
	
	# 🌟 大招：计时到了就自动放
	if Global.ultimate_unlocked:
		ultimate_timer -= delta
		if ultimate_timer <= 0.0:
			ultimate_timer = Global.ultimate_interval
			ultimate_fired.emit(global_position)
	else:
		ultimate_timer = Global.ultimate_interval
		
	if Input.is_action_just_pressed("ui_accept"):
		recoil_pitch = recoil_pitch + deg_to_rad(15.0)
		recoil_back = recoil_back + 0.25
		
	recoil_pitch = move_toward(recoil_pitch, 0.0, delta * 2.5)
	recoil_back = move_toward(recoil_back, 0.0, delta * 6.0)
	
	$craft_speederA.rotation.x = recoil_pitch
	$craft_speederA.position.z = recoil_back

# 检测双击逻辑
func check_dash_input() -> void:
	if dash_timer > 0 or is_dashing: 
		return # 在冷却中或正在冲刺，不响应

	var current_time = Time.get_ticks_msec() / 1000.0 # 获取当前时间（秒）
	
	# 检测向右 (D键)
	if Input.is_action_just_pressed("right"):
		if current_time - last_d_press_time <= 0.25:
			start_dash(1) # 触发右冲刺
			last_d_press_time = -1.0 # 重置，防止三连击无限触发
		else:
			last_d_press_time = current_time # 记录第一次按下的时间
			
	# 检测向左 (A键)
	if Input.is_action_just_pressed("left"):
		if current_time - last_a_press_time <= 0.25:
			start_dash(-1) # 触发左冲刺
			last_a_press_time = -1.0
		else:
			last_a_press_time = current_time

# 执行冲刺逻辑（is_dashing == true 期间 = 无敌帧）
func start_dash(dir: int) -> void:
	is_dashing = true
	is_invincible = true      # 🌟 立刻生效，不等下一帧
	dash_timer = Global.dash_cooldown # 进入冷却
	
	# 🌟 在翻滚前发射冲刺信号
	dash_started.emit(dir)
	
	var tween = create_tween()
	# 🚨 冲刺不受子弹时间影响：世界变慢，玩家照常翻滚位移
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true) # 翻转和位移同时进行
	
	# 1. 翻滚 360 度 (TAU = 2*PI = 360度)
	# 根据方向决定翻转的起始角度
	var target_rotation = $craft_speederA.rotation.z - (dir * TAU) 
	tween.tween_property($craft_speederA, "rotation:z", target_rotation, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2. 冲刺位移（向右/向左移动 5 米）
	# 用 Tween 移动 position，避免与 move_and_slide() 的物理检测打架
	var target_x = position.x + (dir * 5.0)
	tween.tween_property(self, "position:x", target_x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 冲刺结束后的收尾工作
	tween.finished.connect(func():
		is_dashing = false
		# 强制把模型旋转归零，防止角度累计导致飞船永久歪着
		$craft_speederA.rotation.z = 0.0 
	)

# 🌟 扣血：Game 转达陨石的 player_damaged 信号后调这里
func take_damage(amount: int) -> void:
	if is_invincible:
		return # 🌟 无敌中：冲刺 / 开场飞入 / set_invincible 期间都免疫
	if hp <= 0:
		return # 已经死了，别重复扣
	
	# 🌟 护盾：抵挡这一次伤害，然后进入 30 秒充能
	if Global.run_level("shield") > 0 and shield_ready:
		shield_ready = false
		shield_timer = SHIELD_CD
		print("🛡 护盾抵挡了这次伤害，充能 %.0f 秒" % SHIELD_CD)
		return
	
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, Global.player_max_hp)   # 🌟 HUD 靠这个刷新血条
	print("❤️ 玩家血量：", hp, "/", Global.player_max_hp)
	
	# TODO: 受击闪烁 / 短暂无敌 挂在这里
	if hp <= 0:
		die()

# 🌟 死亡：存盘 → 结算画面
func die() -> void:
	print("💀 玩家阵亡，本局结束")
	Global.last_run_victory = false
	Global.save_game()
	Global.stop_bullet_time()      # 别把子弹时间的慢放带进结算
	Global.intro_active = false
	# 🚨 die() 是在物理回调里被调用的，必须延迟换场景，
	# 否则会报 "Removing a CollisionObject node during a physics callback"
	get_tree().call_deferred("change_scene_to_file", "res://sences/game_over.tscn")
