extends Control

# ===================== 主菜单 =====================
# 开始游戏 / 新手教程 / 退出游戏

var _tutorial: Control

func _ready() -> void:
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	
	var title := Label.new()
	title.text = "曾想 3D 飞机"
	title.add_theme_font_size_override("font_size", 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	
	var sub := Label.new()
	sub.text = "SPACE  SHOOTER"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	box.add_child(gap)
	
	box.add_child(_menu_button("开 始 游 戏", _on_start_pressed))
	box.add_child(_menu_button("新 手 教 程", _on_tutorial_pressed))
	box.add_child(_menu_button("退 出 游 戏", _on_quit_pressed))
	
	_build_tutorial()

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 70)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	return b

# ---------------- 新手教程 ----------------

func _build_tutorial() -> void:
	_tutorial = Control.new()
	_tutorial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial.visible = false
	add_child(_tutorial)
	
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial.add_child(dim)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial.add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	panel.add_child(margin)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	
	var title := Label.new()
	title.text = "新 手 教 程"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	
	var body := Label.new()
	body.text = """【操作】
A / D            左右移动
双击 A 或 D      冲刺（冲刺期间无敌，还能撞碎陨石）
空格             发射激光（有冷却，升满约 0.1 秒一发）

【两种危险物】
陨石 ── 撞上扣 50 点血；血条空了才会死。
        用冲刺撞碎它，会触发子弹时间，还能掉金币。

障碍物 ── 撞上扣 20 点血。
        看到就绕开，或者用冲刺躲过去。

【成长】
击杀陨石累计 25 / 50 / 100 / 200 / 320… 最高 11 级，
升级时游戏暂停，从五个强化里选一个。

升到 2 级时 BOSS 会苏醒，命中它 150 次即可击破，
苏醒时还会额外送你 5 次免费强化。

打碎陨石掉的金币是永久的，
可以在商店里买永久强化和大招。

祝你好运，飞行员。"""
	body.add_theme_font_size_override("font_size", 19)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color(0.88, 0.9, 1.0))
	box.add_child(body)
	
	var back := Button.new()
	back.text = "返 回 主 菜 单"
	back.custom_minimum_size = Vector2(0, 58)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_on_tutorial_back_pressed)
	box.add_child(back)

# ---------------- 按钮回调 ----------------

func _on_start_pressed() -> void:
	# 进游戏前把引擎状态复位，避免上一局的慢放带进来
	Engine.time_scale = 1.0
	Global.intro_active = false
	get_tree().change_scene_to_file("res://sences/game.tscn")

func _on_tutorial_pressed() -> void:
	_tutorial.visible = true

# 🌟 教程面板的「返回主菜单」：关掉面板就是回到主菜单（本来就在同一个场景里）
func _on_tutorial_back_pressed() -> void:
	_tutorial.visible = false

func _on_quit_pressed() -> void:
	Global.save_game()
	get_tree().quit()
