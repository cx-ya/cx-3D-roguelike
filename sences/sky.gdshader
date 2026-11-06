shader_type sky;

// ===================== 天空参数 =====================
uniform vec3 zenith_color : source_color = vec3(0.02, 0.015, 0.06);   // 天顶
uniform vec3 horizon_color : source_color = vec3(0.35, 0.22, 0.45);  // 地平线（品红紫）
uniform vec3 ground_color : source_color = vec3(0.06, 0.03, 0.10);   // 地平线以下
uniform float horizon_sharpness : hint_range(0.1, 4.0) = 1.2;        // 渐变收得多快

uniform float star_density : hint_range(0.0, 0.2) = 0.012;           // 星星密度
uniform float star_brightness : hint_range(0.0, 5.0) = 2.0;          // 星星亮度

uniform float nebula_strength : hint_range(0.0, 1.0) = 0.25;         // 星云强度
uniform vec3 nebula_color : source_color = vec3(0.55, 0.25, 0.65);

// 便宜的三维哈希：给同一个格子稳定的"随机数"
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// 三维值噪声：8 个角点做三线性插值
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash13(i + vec3(0.0, 0.0, 0.0));
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float f2 = hash13(i + vec3(1.0, 0.0, 1.0));
	float g = hash13(i + vec3(0.0, 1.0, 1.0));
	float h2 = hash13(i + vec3(1.0, 1.0, 1.0));
	
	float x1 = mix(a, b, f.x);
	float x2 = mix(c, d, f.x);
	float x3 = mix(e, f2, f.x);
	float x4 = mix(g, h2, f.x);
	
	return mix(mix(x1, x2, f.y), mix(x3, x4, f.y), f.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);   // 这个像素看向哪里
	float h = dir.y;                // -1 = 朝下，+1 = 朝上
	
	// ① 上下渐变：天顶 → 地平线 → 地面
	vec3 col = mix(horizon_color, zenith_color, pow(clamp(h, 0.0, 1.0), horizon_sharpness));
	col = mix(col, ground_color, smoothstep(0.0, -0.25, h));
	
	// ② 星尘：把方向切成格子，每个格子掷一次骰子，少数格子亮
	vec3 sp = dir * 180.0;
	vec3 cell = floor(sp);
	float roll = hash13(cell);
	float is_star = step(1.0 - star_density, roll);
	// 越靠近格子中心越亮，星点才是圆的而不是方块
	vec3 cell_center_offset = fract(sp) - 0.5;
	float soft = 1.0 - smoothstep(0.0, 0.45, length(cell_center_offset));
	// 只在地平线以上有星星
	col += vec3(is_star * soft * star_brightness) * smoothstep(0.0, 0.06, h);
	
	// ③ 星云：两层噪声叠，pow 压出絮状
	float n = vnoise(dir * 2.5) * 0.6 + vnoise(dir * 6.0) * 0.4;
	col += nebula_color * pow(n, 3.0) * nebula_strength * smoothstep(-0.15, 0.5, h);
	
	COLOR = col;
}
