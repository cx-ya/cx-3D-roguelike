shader_type spatial;

// 1. 暴露一个槽位，让你在编辑器里把长条图拖进来
uniform sampler2D sprite_sheet : source_color;

// 2. 暴露参数，方便你在编辑器里调播放速度和总帧数
uniform float fps : hint_range(1.0, 30.0) = 8.0; // 每秒播放几张
uniform int total_frames = 4; // 你的长条图里有几张图（你的是4张）

void fragment() {
	// 3. 计算当前时间应该播放第几帧（利用内置时间 TIME）
	// floor 向下取整，mod 取余数，确保在 0, 1, 2, 3 之间无限循环
	float frame_index = mod(floor(TIME * fps), float(total_frames));
	
	// 4. 计算当前帧在长条图上的横向偏移量
	// 因为每张图占据 1/4 的宽度，所以偏移量就是 索引 / 4 (即 0.0, 0.25, 0.5, 0.75)
	float offset_x = frame_index / float(total_frames);
	
	// 5. 重新映射 UV 坐标（核心魔法！）
	// UV.x 默认是 0 到 1。除以 total_frames 后，把它压缩到了 0 到 0.25。
	// 加上 offset_x，就能准确“抠”出长条图上当前那一帧的画面。
	vec2 animated_uv = vec2(UV.x / float(total_frames) + offset_x, UV.y);
	
	// 6. 采样贴图，并赋给基础颜色
	vec4 tex_color = texture(sprite_sheet, animated_uv);
	ALBEDO = tex_color.rgb;
	ALPHA = tex_color.a; // 如果你的表情包有透明背景，这行很重要
}