extends Area3D

# meshs 里每个模型统一放大多少倍
@export var mesh_scale: float = 1.5

# 🌟 撞到玩家：障碍物只管喊“我撞人了”，由 Game 转达给 Player 扣血
signal player_damaged(damage: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 🚨 Area3D 默认 collision_mask = 1，而玩家在 layer 2，不改就永远检测不到
	collision_mask |= 2
	# 保证 body_entered 一定连上；已经连过就不会重复
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	var scale_random = randf_range(1,3)
	
	scale = Vector3(scale_random,scale_random,scale_random)
	rotate_y(randf_range(0, TAU))
	
	# 🚨 6 个模型在场景里默认全是可见的，直接 show() 等于没随机
	# 所以必须先全部藏起来，再随机露一个
	var meshs := $meshs as Node3D
	var models := meshs.get_children()
	for m in models:
		var model := m as Node3D
		model.visible = false
		model.scale *= mesh_scale   # 🌟 每个模型自身放大 N 倍（在原地变大，不会被推远）
	
	var chosen := models.pick_random() as Node3D
	chosen.visible = true
	
	# 🌟 模型原来偏在 (-2, 0, -1.5) 附近，先拉回障碍物原点
	meshs.position = -chosen.position
	
	# 🌟 碰撞盒按「实际几何体」重算，而不是用一个拍脑袋的固定尺寸
	_fit_collision(chosen)
	
	position.y = -2

# 用可见模型真实的包围盒撑碰撞盒：不管选中哪个模型、放大多少倍，盒子都刚好包住它
func _fit_collision(model: Node3D) -> AABB:
	var nodes := model.find_children("*", "MeshInstance3D", true, false)
	if nodes.is_empty() and model is MeshInstance3D:
		nodes.append(model)
	
	var bounds := AABB()
	var first := true
	
	for node in nodes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# mesh 的 AABB 是它自己的局部坐标，先转到「障碍物自己的局部坐标」再合并
		var to_local := global_transform.affine_inverse() * mi.global_transform
		var box := _xform_aabb(to_local, mi.get_aabb())
		bounds = box if first else bounds.merge(box)
		first = false
	
	if first:
		return AABB()  # 一个网格都没找到，就保留场景里原本的碰撞盒
	
	var col := $CollisionShape3D as CollisionShape3D
	var shape := BoxShape3D.new()       # 新建一个，别动场景里那个共享资源
	shape.size = bounds.size * 1.05     # 留 5% 余量，别让盒子和表面完全贴死
	col.shape = shape
	col.position = bounds.get_center()
	col.scale = Vector3.ONE             # AABB 里已经含了缩放，这里不能再乘
	
	return bounds

# 把 AABB 用 Transform3D 变换后重新求包围盒（8 个角点各变换一次取极值）
func _xform_aabb(t: Transform3D, aabb: AABB) -> AABB:
	var out := AABB(t * aabb.position, Vector3.ZERO)
	for i in 8:
		out = out.expand(t * aabb.get_endpoint(i))
	return out
# Called every frame. 'delta' is the elapsed time since the previous frame.
func set_xz_pos(x: float,z: float):
	position.x = x
	position.z = z
func _physics_process(delta: float) -> void:
	position.z += 2 * delta
	
	# 🌟 飞过死亡平面就销毁。用世界坐标判定，不依赖"屏幕可见性"：
	# 屏幕可见性会跟着相机变化（子弹时间推近 / 开场俯冲），一改镜头就误删一片。
	if position.z > Global.despawn_z:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	# 无敌（开场快进 / 落地缓冲 / 冲刺）→ 直接穿过去
	if Global.intro_active or body.get("is_invincible") == true:
		return
	
	# 只认玩家：有 take_damage 方法的才算，别让别的物理体误触发
	if body.has_method("take_damage"):
		player_damaged.emit(Global.obstacle_damage)
