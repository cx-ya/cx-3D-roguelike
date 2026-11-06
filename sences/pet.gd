extends Node3D

# ===================== 宠物 =====================
# 位置由 Game 每帧 lerp 决定；这里只负责"每隔几秒往上蹦一下"的表现，
# 所以动画作用在子节点（模型）的本地 y 上，不碰根节点的位置。

@export var jump_interval: float = 2.5   # 每隔多久跳一次
@export var jump_height: float = 0.9     # 跳多高（米）
@export var jump_duration: float = 0.35  # 一次跳跃总时长

var _visuals: Array[Node3D] = []
var _base_ys: Array[float] = []

func _ready() -> void:
	# 收下所有子模型，并记住它们原来的高度（跳完要落回原位）
	for child in get_children():
		if child is Node3D:
			_visuals.append(child)
			_base_ys.append((child as Node3D).position.y)
	
	if _visuals.is_empty():
		return
	
	# 每只宠物的节奏错开一点，不然一群一起跳很假
	jump_interval *= randf_range(0.8, 1.3)
	
	var loop := create_tween()
	loop.set_loops()
	loop.tween_interval(jump_interval)
	loop.tween_callback(_do_jump)

func _do_jump() -> void:
	if not is_inside_tree():
		return
	for i in _visuals.size():
		var vis := _visuals[i]
		var base_y := _base_ys[i]
		var jump := create_tween()
		jump.set_trans(Tween.TRANS_SINE)
		# 起跳快、下落慢，带一点点重力感
		jump.tween_property(vis, "position:y", base_y + jump_height, jump_duration * 0.4).set_ease(Tween.EASE_OUT)
		jump.tween_property(vis, "position:y", base_y, jump_duration * 0.6).set_ease(Tween.EASE_IN)
