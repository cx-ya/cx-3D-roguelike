extends Node3D

# 出生后等多久才开始转（真实秒）
@export var delay_time: float = 0.3
# 转一整圈用多久（真实秒）
@export var spin_time: float = 0.4

func _ready() -> void:
	# 🚨 整个效果按真实时间跑：子弹时间里的慢放不会把它拖成好几秒
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	
	# 1. 先愣 0.2 秒
	tween.tween_interval(delay_time)
	
	# 2. 0.5 秒内绕 Z 轴转一整圈（TAU = 2π = 360°）
	var spin := tween.tween_property(self, "rotation:z", rotation.z + TAU, spin_time)
	spin.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. 转完立刻自毁
	tween.tween_callback(queue_free)
