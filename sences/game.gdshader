shader_type spatial;

// ===================== 可调参数 =====================
// 地板颜色（原来的 StandardMaterial3D 就是 #FFC0FF，颜色搬到这里）
uniform vec3 albedo : source_color = vec3(1.0, 0.7529, 1.0);
// 噪声把地面抬高多少（单位：米）
uniform float noise_strength : hint_range(0.0, 5.0) = 0.5;
// 噪声贴图在地面上重复几次 / 偏移多少
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);
// 教程里预留的第二组 UV，先声明着，检查器里能看到
uniform vec3 uv2_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv2_offset = vec3(0.0, 0.0, 0.0);
// 噪声图
uniform sampler2D noise_texture : hint_default_white, repeat_enable;

// 把噪声值传给 fragment，用来做明暗变化
varying float v_noise;

void vertex() {
	// ① 缩放/偏移 UV：控制噪声在地面上"铺多大"
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
	// ② 采样噪声（只取红通道，得到 0~1 的数）
	float noise_sample = texture(noise_texture, UV).r;
	v_noise = noise_sample;
	
	// ③ 按噪声抬高顶点 —— 平板地面从此有起伏
	VERTEX += vec3(0.0, noise_sample * noise_strength, 0.0);
}

void fragment() {
	// 用回你原来的地板色 #FFC0FF
	ALBEDO = albedo;
	// 低处压暗一点，起伏在光照下更明显
	ALBEDO *= mix(1.0, 0.7, v_noise);
	ROUGHNESS = 0.9;
	
	// 顶点被抬高了，但法线还是平的 —— 用屏幕空间导数重新算一遍，
	// 否则地面会"看起来还是平的，只是颜色在变"。
	// （这两行如果报错就删掉，不影响其他地方）
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
}
