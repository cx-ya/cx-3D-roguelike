extends Control

# ===================== 升级三选一（肉鸽）=====================
# 目前三个选项是空的，只把框架和暂停/恢复跑通

const OPTION_COUNT := 5

var _title: Label
var _options: Array[Button] = []
var _reroll: Button
var _current: Array = []      # 本次抽到的 3 个选项

func _ready() -> void:
	# 🚨 暂停时这个界面自己也要能响应点击
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 挡住鼠标，别点到底下的游戏
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 半透明黑底
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 居中面板
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	
	_title = Label.new()
	_title.text = "等级提升"
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	
	var hint := Label.new()
	hint.text = "前三项是机制强化 · 后两项是数值强化"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	
	# 🌟 一次 5 个选项：前 3 个是机制强化，后 2 个是数值强化
	for i in OPTION_COUNT:
		var btn := Button.new()
		btn.text = "选项 %d" % (i + 1)
		btn.custom_minimum_size = Vector2(560, 62)
		btn.add_theme_font_size_override("font_size", 19)
		btn.pressed.connect(func(): _on_option_pressed(i))
		box.add_child(btn)
		_options.append(btn)
	
	# 刷新
	_reroll = Button.new()
	_reroll.text = "刷 新"
	_reroll.custom_minimum_size = Vector2(0, 52)
	_reroll.add_theme_font_size_override("font_size", 20)
	_reroll.pressed.connect(_on_reroll_pressed)
	box.add_child(_reroll)

# 🌟 Game 收到 Global.level_up 后调这个；free = true 表示是 BOSS 送的免费强化
func open(new_level: int, free: bool = false) -> void:
	if free:
		_title.text = "免费强化   还剩 %d 次" % Global.pending_picks
	else:
		_title.text = "等级提升   Lv.%d" % new_level
	_draw_options()
	visible = true
	get_tree().paused = true      # 游戏停止

# 从池子里抽 3 个可选项刷新到按钮上
func _draw_options() -> void:
	_current = Global.roll_run_options(OPTION_COUNT)
	for i in _options.size():
		var btn: Button = _options[i]
		if i < _current.size():
			var item: Dictionary = _current[i]
			var id := String(item["id"])
			# 显示：名字 (当前等级→下一级) + 效果说明
			btn.text = "%s  (Lv.%d → %d)　·　%s" % [
				String(item["name"]),
				Global.run_level(id),
				Global.run_level(id) + 1,
				String(item["desc"]),
			]
			btn.disabled = false
		else:
			btn.text = "（没有更多可选项了）"
			btn.disabled = true

func _close() -> void:
	# 🌟 还有待领的免费强化（BOSS 出场送 5 次）就继续弹，不解除暂停
	if Global.pending_picks > 0:
		Global.pending_picks -= 1
		if Global.pending_picks > 0:
			_title.text = "免费强化   还剩 %d 次" % Global.pending_picks
			_draw_options()
			return
	
	visible = false
	get_tree().paused = false     # 恢复游戏

func _on_option_pressed(index: int) -> void:
	if index >= _current.size():
		return
	var item: Dictionary = _current[index]
	print("🔼 选择了：", item["name"])
	Global.take_run_upgrade(item)
	_close()

func _on_reroll_pressed() -> void:
	_draw_options()
