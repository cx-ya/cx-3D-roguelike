extends Control

# ===================== BOSS 出场横幅 =====================

var _title: Label
var _sub: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	
	_title = Label.new()
	_title.text = "B O S S   出 现"
	_title.add_theme_font_size_override("font_size", 84)
	_title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.35))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_title.add_theme_constant_override("outline_size", 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	
	_sub = Label.new()
	_sub.text = "命中 100 次即可击破 · 免费获得 5 次强化"
	_sub.add_theme_font_size_override("font_size", 24)
	_sub.add_theme_color_override("font_color", Color(1.0, 0.9, 0.95))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_sub.add_theme_constant_override("outline_size", 8)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sub)

# 🌟 Game 生成 BOSS 时调用：淡入 → 停留 → 淡出
func show_banner(required_hits: int = 100) -> void:
	_sub.text = "命中 %d 次即可击破 · 免费获得 5 次强化" % required_hits
	visible = true
	modulate.a = 0.0
	_title.scale = Vector2.ONE
	_title.pivot_offset = _title.size * 0.5
	
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.7)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.finished.connect(func(): visible = false)
