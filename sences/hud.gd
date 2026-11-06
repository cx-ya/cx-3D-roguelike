extends Control

# ===================== HUD：货币 + 血条 + 冲刺冷却 =====================
# 整个界面用代码生成，省得手动拖布局；想改成编辑器搭的话照着 _build() 摆就行

const CoinIcon := preload("res://sences/coin_icon.gd")

var _currency_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _dash_label: Label
var _shoot_label: Label
var _ult_label: Label
var _shield_label: Label
var _dodge_label: Label
var _boss_root: Control
var _boss_bar: ProgressBar
var _boss_label: Label
var _level_label: Label
var _player: Node

func _ready() -> void:
	_build()
	# 监听 Global 的货币变化
	Global.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(Global.currency)
	# 等级 / 击杀数
	Global.kills_changed.connect(func(_k, _t): _refresh_level())
	Global.level_changed.connect(func(_l): _refresh_level())
	_refresh_level()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# HUD 只是显示，不能吃鼠标事件（否则挡住后面的东西）
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var box := VBoxContainer.new()
	box.position = Vector2(28, 20)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	
	# 金币：动画图标 + 数字
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 8)
	box.add_child(coin_row)
	coin_row.add_child(CoinIcon.make(44))
	
	_currency_label = Label.new()
	_currency_label.add_theme_font_size_override("font_size", 28)
	_currency_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_currency_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_row.add_child(_currency_label)
	
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(260, 20)
	_hp_bar.show_percentage = false
	box.add_child(_hp_bar)
	
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 16)
	box.add_child(_hp_label)
	
	# 🌟 射击冷却（一位小数）
	_shoot_label = Label.new()
	_shoot_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_shoot_label)
	
	# 🌟 冲刺冷却（整数秒）
	_dash_label = Label.new()
	_dash_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_dash_label)
	
	# 🌟 大招冷却（没买大招就不显示）
	_ult_label = Label.new()
	_ult_label.add_theme_font_size_override("font_size", 20)
	_ult_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.9))
	_ult_label.visible = false
	box.add_child(_ult_label)
	
	# 🌟 护盾（局内拿到才显示）
	_shield_label = Label.new()
	_shield_label.add_theme_font_size_override("font_size", 20)
	_shield_label.visible = false
	box.add_child(_shield_label)
	
	# 🌟 闪避射击（局内拿到才显示）
	_dodge_label = Label.new()
	_dodge_label.add_theme_font_size_override("font_size", 20)
	_dodge_label.visible = false
	box.add_child(_dodge_label)
	
	# 🌟 等级：放在屏幕正上方居中
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 26)
	_level_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.anchor_left = 0.5
	_level_label.anchor_right = 0.5
	_level_label.offset_left = -260
	_level_label.offset_right = 260
	_level_label.offset_top = 18
	_level_label.offset_bottom = 64
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_label)
	
	# 🌟 BOSS 血条：屏幕正上方（等级下面），默认隐藏
	_boss_root = VBoxContainer.new()
	_boss_root.anchor_left = 0.5
	_boss_root.anchor_right = 0.5
	_boss_root.offset_left = -290
	_boss_root.offset_right = 290
	_boss_root.offset_top = 76
	_boss_root.offset_bottom = 140
	_boss_root.add_theme_constant_override("separation", 4)
	_boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_root.visible = false
	add_child(_boss_root)
	
	_boss_label = Label.new()
	_boss_label.add_theme_font_size_override("font_size", 20)
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_root.add_child(_boss_label)
	
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(580, 24)
	_boss_bar.show_percentage = false
	_boss_root.add_child(_boss_bar)

# 🌟 Game 生成 BOSS 后调这个
func bind_boss(b: Node) -> void:
	_boss_root.visible = true
	if b.has_signal("hp_changed"):
		b.hp_changed.connect(_on_boss_hp_changed)
	_on_boss_hp_changed(0, int(b.get("max_hits")))

func _on_boss_hp_changed(hits: int, max_hits: int) -> void:
	_boss_bar.max_value = max_hits
	_boss_bar.value = max_hits - hits          # 血条显示的是"还剩多少"
	_boss_label.text = "BOSS   剩 %d / %d" % [max_hits - hits, max_hits]

# 🌟 Game 会调这个把玩家接进来
func bind_player(p: Node) -> void:
	_player = p
	if p.has_signal("hp_changed"):
		p.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(int(p.get("hp")), Global.player_max_hp)

# 冷却类每帧从玩家身上读，避免高频信号
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	
	# 🌟 射击冷却（一位小数）
	var st := maxf(float(_player.get("shoot_timer")), 0.0)
	if st <= 0.0:
		_shoot_label.text = "🔫 就绪"
		_shoot_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	else:
		_shoot_label.text = "🔫 %.1f" % st
		_shoot_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	
	# 冲刺冷却（整数秒）
	var cd := float(_player.get("dash_timer"))
	if cd <= 0.0:
		_dash_label.text = "⚡ 冲刺就绪"
		_dash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	else:
		_dash_label.text = "⚡ 冲刺 %d" % ceili(cd)
		_dash_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	
	# 🌟 大招冷却
	_ult_label.visible = Global.ultimate_unlocked
	if Global.ultimate_unlocked:
		var ut := maxf(float(_player.get("ultimate_timer")), 0.0)
		_ult_label.text = "🚀 大招 %d" % ceili(ut)
	
	# 🌟 护盾（一次性，破盾后 30 秒充能）
	var has_shield := Global.run_level("shield") > 0
	_shield_label.visible = has_shield
	if has_shield:
		if bool(_player.get("shield_ready")):
			_shield_label.text = "🛡 护盾就绪"
			_shield_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
		else:
			_shield_label.text = "🛡 %d" % ceili(maxf(float(_player.get("shield_timer")), 0.0))
			_shield_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# 🌟 闪避射击冷却
	var has_dodge := Global.run_level("dodge_shot") > 0
	_dodge_label.visible = has_dodge
	if has_dodge:
		var dc := maxf(float(_player.get("dodge_cd")), 0.0)
		if dc <= 0.0:
			_dodge_label.text = "🎯 闪避射击就绪"
			_dodge_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
		else:
			_dodge_label.text = "🎯 %d" % ceili(dc)
			_dodge_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func _on_currency_changed(value: int) -> void:
	_currency_label.text = str(value)

func _on_hp_changed(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "❤ %d / %d" % [hp, max_hp]

func _refresh_level() -> void:
	if Global.level >= Global.MAX_LEVEL:
		_level_label.text = "等级 %d   ·   已满级（%d 击杀）" % [Global.level, Global.kills]
	else:
		_level_label.text = "等级 %d   ·   %d / %d" % [Global.level, Global.kills, Global.kill_target()]
