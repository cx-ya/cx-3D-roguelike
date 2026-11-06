extends Node3D # 或者你的根节点类型 (Area3D / MeshInstance3D)

func _ready() -> void:
	# 1. 闪烁动画（心跳缩放）
	var tween = create_tween().set_loops()
	var original_scale = scale
	tween.tween_property(self, "scale", original_scale * 0.5, 0.1)
	tween.tween_property(self, "scale", original_scale, 0.1)
	
	# 2. 3 秒后自己销毁
	await get_tree().create_timer(3.0).timeout
	queue_free()
