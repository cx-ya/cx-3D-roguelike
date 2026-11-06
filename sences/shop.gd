extends Control

# ===================== 商店（游戏外成长）=====================
# 布局全部用代码生成；商品数据来自 Global.UPGRADES，加商品只需改那张表

const CoinIcon := preload("res://sences/coin_icon.gd")

var _currency_label: Label
var _msg_label: Label
var _cards: Dictionary = {}   # id -> {"level": Label, "button": Button}

func _ready() -> void:
	_build()
	Global.currency_changed.connect(_on_currency_changed)
	Global.upgrade_level_changed.connect(func(_id, _lv): _refresh_all())
	_on_currency_changed(Global.currency)
	_refresh_all()

# ---------------- 搭界面 ----------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 四周留白
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	add_child(margin)
	
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)
	
	# ---- 顶栏：标题 + 金币 ----
	var top := HBoxContainer.new()
	root.add_child(top)
	
	var title := Label.new()
	title.text = "升级商店"
	title.add_theme_font_size_override("font_size", 40)
	top.add_child(title)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	
	# 金币：动画图标 + 数字
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 10)
	top.add_child(coin_row)
	coin_row.add_child(CoinIcon.make(48))
	
	_currency_label = Label.new()
	_currency_label.add_theme_font_size_override("font_size", 32)
	_currency_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_currency_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_row.add_child(_currency_label)
	
	# ---- 商品卡片（4 列网格，商品多了会换行）----
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grid)
	
	for item in Global.UPGRADES:
		grid.add_child(_make_card(item))
	
	# ---- 底栏：提示 + 开始游戏 ----
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	
	_msg_label = Label.new()
	_msg_label.add_theme_font_size_override("font_size", 20)
	_msg_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	bottom.add_child(_msg_label)
	
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer2)
	
	# 🛠 调试用：新存档一分钱都没有，先给点钱方便试买
	var cheat := Button.new()
	cheat.text = "+100 金币（调试）"
	cheat.custom_minimum_size = Vector2(170, 44)
	cheat.add_theme_font_size_override("font_size", 16)
	cheat.pressed.connect(func(): Global.add_currency(100))
	bottom.add_child(cheat)
	
	# 回主菜单
	var home := Button.new()
	home.text = "主 菜 单"
	home.custom_minimum_size = Vector2(130, 44)
	home.add_theme_font_size_override("font_size", 16)
	home.pressed.connect(func():
		Global.save_game()
		get_tree().change_scene_to_file("res://sences/main_menu.tscn"))
	bottom.add_child(home)
	
	# 🔄 重置存档（要点两下，防误触）
	var reset := Button.new()
	reset.text = "重置存档"
	reset.custom_minimum_size = Vector2(130, 44)
	reset.add_theme_font_size_override("font_size", 16)
	reset.pressed.connect(_on_reset_pressed)
	bottom.add_child(reset)
	
	var start := Button.new()
	start.text = "开 始 游 戏"
	start.custom_minimum_size = Vector2(200, 62)
	start.add_theme_font_size_override("font_size", 24)
	start.pressed.connect(_on_start_pressed)
	bottom.add_child(start)

func _make_card(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(230, 0)
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	
	var name_label := Label.new()
	name_label.text = String(item["name"])
	name_label.add_theme_font_size_override("font_size", 24)
	box.add_child(name_label)
	
	var desc_label := Label.new()
	desc_label.text = String(item["desc"])
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 16)
	box.add_child(desc_label)
	
	# 占位，把按钮顶到底部
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	
	var level_label := Label.new()
	level_label.add_theme_font_size_override("font_size", 17)
	box.add_child(level_label)
	
	# 🌟 生效值：当前 → 下一级
	var effect_label := Label.new()
	effect_label.add_theme_font_size_override("font_size", 17)
	effect_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(effect_label)
	
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 50)
	buy.add_theme_font_size_override("font_size", 20)
	buy.icon = CoinIcon.texture()                               # 🌟 按钮上的金币图标
	buy.add_theme_constant_override("icon_max_width", 28)
	buy.pressed.connect(func(): _on_buy_pressed(item))
	box.add_child(buy)
	
	_cards[String(item["id"])] = {"level": level_label, "effect": effect_label, "button": buy}
	return panel

# ---------------- 刷新 ----------------

func _refresh_all() -> void:
	for item in Global.UPGRADES:
		var id := String(item["id"])
		var card: Dictionary = _cards[id]
		var level_label: Label = card["level"]
		var effect_label: Label = card["effect"]
		var buy: Button = card["button"]
		
		var lv := Global.level_of(id)
		var maxed := Global.is_maxed(item)
		var locked := Global.is_locked(item)
		level_label.text = "等级 %d / %d" % [lv, int(item["max"])]
		
		# 🌟 前置没买 → 整张卡灰掉，按钮上直接写原因
		if locked:
			effect_label.text = "🔒 需先购买「大招：五连发」"
			buy.text = "需先购买大招"
			buy.disabled = true
			continue
		
		# 生效值：没满级就显示 当前 → 下一级
		if maxed:
			effect_label.text = Global.effect_text(id, lv) + "（已满）"
		else:
			effect_label.text = "%s  →  %s" % [Global.effect_text(id, lv), Global.effect_text(id, lv + 1)]
		
		if maxed:
			buy.text = "已 满 级"
			buy.disabled = true
		else:
			var price := Global.price_of(item)
			buy.text = "%d" % price
			buy.disabled = Global.currency < price   # 买不起就灰掉

func _on_currency_changed(value: int) -> void:
	_currency_label.text = str(value)
	_refresh_all()   # 钱变了，按钮能不能点也要刷新

# ---------------- 交互 ----------------

func _on_buy_pressed(item: Dictionary) -> void:
	var result := Global.buy_upgrade(item)
	match result:
		0:
			_msg_label.text = "✅ 升级成功：" + String(item["name"])
		1:
			_msg_label.text = "已经满级了"
		2:
			_msg_label.text = "❌ 金币不足"
		3:
			_msg_label.text = "🔒 需要先购买「大招：五连发」"
	_refresh_all()

func _on_start_pressed() -> void:
	Global.save_game()
	Global.stop_bullet_time()        # 别让子弹时间的慢放带进下一局
	Global.intro_active = false
	get_tree().change_scene_to_file("res://sences/game.tscn")

# 🌟 重置存档：第一下只"上膛"，3 秒内再点一下才真的清空
var _reset_armed := false

func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_msg_label.text = "⚠ 再点一次「重置存档」确认：金币和所有升级都会清空"
		await get_tree().create_timer(3.0).timeout
		_reset_armed = false
		return
	
	_reset_armed = false
	Global.reset_save()
	Global.last_run_victory = false
	_msg_label.text = "✅ 存档已清空，一切从头开始"
	_refresh_all()
