extends Area3D

var rotate_speed := 10.0
var can_move = true

var current_pierce: int

# 🌟 大招子弹：只往前飞，不受当前弹道影响
var force_straight: bool = false
var _wave_t: float = 0.0

func _ready() -> void:
	current_pierce = Global.laser_pierce
	
	$Red.scale = Vector3(0.1, 0.1, 0.1)
	var tween = create_tween()
	tween.tween_property($Red, "scale", Vector3(0.3, 0.3, 0.3), 0.7)
	$AudioStreamPlayer3D.play()

func _process(delta: float) -> void:
	if can_move:
		position.z -= 15 * delta
		rotate_object_local(Vector3(0, 0, 1), rotate_speed * delta)
		
		# 🌟 波动弹道：边往前飞边左右小幅摆（速度型，不需要记基准位置）
		if not force_straight and Global.current_trajectory == Global.LaserTrajectory.SINE:
			_wave_t += delta
			position.x += cos(_wave_t * 5.0) * 4.5 * delta
		
	if position.z <= Global.laser_range:
		queue_free()
		
func destroy():
	if not can_move:
		return
		
	current_pierce -= 1
	
	if current_pierce > 0:
		return
		
	can_move = false
	monitoring = false
	
	var tween = create_tween()
	tween.tween_property($Red, "scale", Vector3(0.0001, 0.0001, 0.0001), Global.laser_delay) 
	
	await get_tree().create_timer(Global.laser_delay).timeout
	queue_free()
