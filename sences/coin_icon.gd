extends Node

# ===================== 金币图标 =====================
# 复用 evil_gold.tscn 那 4 帧动画，但做成 2D 的，供 HUD / 商店使用。
# 用法：CoinIcon.make(44) 得到一个 44×44 的动画图标（Control，能放进容器）
# 想换成静态图：把 make() 换成返回 TextureRect，texture 用 texture()

const FRAMES: Array = [
	preload("res://picture/95d1cc4f-0819-42a7-8f36-66b108bbf476-0.png"),
	preload("res://picture/95d1cc4f-0819-42a7-8f36-66b108bbf476-1.png"),
	preload("res://picture/95d1cc4f-0819-42a7-8f36-66b108bbf476-2.png"),
	preload("res://picture/95d1cc4f-0819-42a7-8f36-66b108bbf476-3.png"),
]
const SOURCE_SIZE := 200.0    # 原图边长
const FPS := 5.0              # 和 evil_gold 里的 speed 一致

static func frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("spin")
	sf.set_animation_speed("spin", FPS)
	sf.set_animation_loop("spin", true)
	for tex in FRAMES:
		sf.add_frame("spin", tex)
	return sf

static func texture() -> Texture2D:
	return FRAMES[0]

# size：图标边长（像素）
static func make(size: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 不吃鼠标
	
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames()
	anim.animation = "spin"
	anim.scale = Vector2.ONE * (size / SOURCE_SIZE)
	anim.position = Vector2(size, size) * 0.5
	holder.add_child(anim)
	anim.play("spin")
	
	return holder
