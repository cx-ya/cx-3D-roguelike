extends Area3D

# 🌟 统一成 2 个参数
signal meteor_hit(hit_pos: Vector3, meteor_node: Area3D)
# 🌟 撞到玩家：陨石只管喊"我撞人了"，由 Game 转达给 Player 扣血
signal player_damaged(damage: int)

const NORMAL_SPEED := 2.0          # 自然生成时的基础速度

var speed : float
var direction_x: float
var can_move := true

# 🌟 BOSS 用：定向投射物（朝一个坐标一直飞，不锁定）
var is_projectile: bool = false
var fly_dir: Vector3 = Vector3(0, 0, 1)
var fly_speed: float = 12.0

func _ready() -> void:
	direction_x = randf_range(-1, 1)
	position.z = -80
	position.x = randf_range(-20, 15)
	# 🚨 陨石要飞在飞船的高度带里（飞船 y=0.6），否则激光从它们头顶掠过
	position.y = randf_range(0.35, 0.85)
	var random_scale = randf_range(1, 3)
	scale = Vector3(random_scale, random_scale, random_scale)
	speed = randf_range(3, 5)

# BOSS 发射：只取一次目标坐标，之后一直朝那个方向飞（不追踪）
func make_projectile(from: Vector3, dir: Vector3, spd: float, size_scale: float = 1.4) -> void:
	is_projectile = true
	fly_dir = dir.normalized()
	fly_speed = spd
	global_position = from
	scale = Vector3.ONE * size_scale * randf_range(0.9, 1.15)

func _physics_process(delta: float) -> void:
	if not can_move: 
		return
	
	# —— BOSS 投射物：直线飞，飞出很远就销毁 ——
	if is_projectile:
		position += fly_dir * fly_speed * delta
		rotate_z(3.0 * delta)
		if position.length() > 140.0:
			queue_free()
		return
	
	# —— 自然生成的陨石：朝 +Z 慢慢飘 ——
	position.z += NORMAL_SPEED * Global.meteor_speed_mult * delta
	position.x += direction_x * delta
	rotate_z(0.25 * delta)
	rotate_y(1.5 * delta)
	
	# 🚨 飞到相机后面才销毁（别用"出没出屏幕"，相机一变焦点就会误删一片）
	if position.z > Global.despawn_z:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if not can_move:
		return
	
	if area.has_method("destroy"):
		area.destroy()
		
	_die()

# 🚨 玩家碰撞：冲刺中 = 无敌帧 → 击碎陨石 + 子弹时间
func _on_body_entered(body: CharacterBody3D) -> void:
	if not can_move:
		return
	
	# ① 冲刺撞上来：无敌帧生效，击碎陨石 + 进子弹时间（必须放在无敌判断之前）
	# 用 get() 动态取值，避免静态类型检查报 "CharacterBody3D 没有 is_dashing"
	if body.get("is_dashing") == true:
		print("💥 冲刺击碎陨石！")
		Global.start_bullet_time()
		Global.perfect_dodge.emit()   # 🌟 广播完美闪避（闪避射击靠它触发）
		_die()
		return
	
	# ② 其它无敌：开场快进 / 落地缓冲 3 秒 / 以后的护盾道具 —— 直接穿过去
	if Global.intro_active or body.get("is_invincible") == true:
		return
	
	# ③ 真撞上：发信号扣血，陨石自己也撞碎（但不爆金币）
	print("💀 陨石撞到玩家")
	player_damaged.emit(Global.meteor_damage)
	_die(false)

# 统一的死亡表现：停住 → 爆金币 → 粉红闪烁 → 缩小 → 渐隐销毁
# award = false 时不给奖励（比如撞玩家的同归于尽）
func _die(award: bool = true) -> void:
	if not can_move:
		return
	# 🚨 已经不在场景树里（比如正在切场景）就别再动了
	if not is_inside_tree():
		return
	can_move = false
	
	# 🌟 发射 2 个参数：位置 和 自己
	if award:
		meteor_hit.emit(global_position, self)
	
	var mat = $meteor.material_overlay
	
	if mat:
		var blink_tween = create_tween().set_loops()
		blink_tween.tween_method(func(p): mat.set_shader_parameter('progress', p), 1.0, 0.2, 0.05)
		blink_tween.tween_method(func(p): mat.set_shader_parameter('progress', p), 0.2, 1.0, 0.05)
	
	var shrink_tween = create_tween()
	# 🌟 修复了 ZERO 导致的报错
	shrink_tween.tween_property(self, "scale", Vector3(0.0001, 0.0001, 0.0001), Global.meteor_delay)
	
	# 🚨 先把 tree 存下来：await 期间如果切了场景，get_tree() 会变成 null
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(Global.meteor_delay).timeout
	
	# 等待期间场景可能已经被换掉了，节点已经不在树里
	if not is_inside_tree():
		return
	
	if mat:
		var fade_tween = create_tween()
		fade_tween.tween_method(func(p): mat.set_shader_parameter('progress', p), 1.0, 0.0, 0.2)
		await fade_tween.finished
		if not is_inside_tree():
			return
		
	queue_free()


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	# 🚨 这里故意不销毁。
	# "屏幕可见性"会跟着相机变化：子弹时间/开场俯冲一改镜头，画面边缘的陨石会被判出屏，
	# 一删一大片。真正的销毁在 _physics_process 里按世界坐标 z 判断。
	pass
