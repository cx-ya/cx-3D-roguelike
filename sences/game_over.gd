extends Control

# ===================== 游戏结束 / 胜利画面 =====================

func _ready() -> void:
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	
	var victory := Global.last_run_victory
	var title := Label.new()
	title.text = "胜 利" if victory else "游 戏 结 束"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if victory else Color(1.0, 0.45, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	
	var sub := Label.new()
	sub.text = "你击破了 BOSS" if victory else "飞船被击毁了"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	box.add_child(gap)
	
	# 本局数据
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	box.add_child(stats)
	stats.add_child(_stat_line("击杀陨石", "%d 颗" % Global.kills))
	stats.add_child(_stat_line("达到等级", "Lv.%d" % Global.level))
	stats.add_child(_stat_line("持有金币", "%d" % Global.currency))
	
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 20)
	box.add_child(gap2)
	
	var back := Button.new()
	back.text = "返 回 商 店"
	back.custom_minimum_size = Vector2(360, 68)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)

func _stat_line(name_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	
	var left := Label.new()
	left.text = name_text
	left.add_theme_font_size_override("font_size", 22)
	left.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	left.custom_minimum_size = Vector2(180, 0)
	row.add_child(left)
	
	var right := Label.new()
	right.text = value_text
	right.add_theme_font_size_override("font_size", 22)
	right.add_theme_color_override("font_color", Color(1, 1, 1))
	row.add_child(right)
	
	return row

func _on_back_pressed() -> void:
	Global.save_game()
	get_tree().change_scene_to_file("res://sences/shop.tscn")
