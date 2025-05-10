shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.85; // Скорость анимации (как spd)
uniform float noise_scale : hint_range(0.0001, 0.01) = 0.0028; // Масштаб шума (как scale)
uniform float grid_size : hint_range(5.0, 20.0) = 11.0; // Размер ячейки (как pos)

// Базовая функция шума (без рекурсии)
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Упрощённый 3D Simplex Noise (адаптация из твоего JS-кода)
float simplex3(vec3 p) {
	const float F3 = 1.0 / 3.0;
	const float G3 = 1.0 / 6.0;

	// Скос координат
	float s = (p.x + p.y + p.z) * F3;
	vec3 i = floor(p + s);
	float t = (i.x + i.y + i.z) * G3;
	vec3 x0 = p - i + t; // Расстояние от точки до первой ячейки

	// Определяем порядок симплекса
	vec3 i1, i2;
	if (x0.x >= x0.y) {
		if (x0.y >= x0.z) { i1 = vec3(1.0, 0.0, 0.0); i2 = vec3(1.0, 1.0, 0.0); }
		else if (x0.x >= x0.z) { i1 = vec3(1.0, 0.0, 0.0); i2 = vec3(1.0, 0.0, 1.0); }
		else { i1 = vec3(0.0, 0.0, 1.0); i2 = vec3(1.0, 0.0, 1.0); }
	} else {
		if (x0.y < x0.z) { i1 = vec3(0.0, 0.0, 1.0); i2 = vec3(0.0, 1.0, 1.0); }
		else if (x0.x < x0.z) { i1 = vec3(0.0, 1.0, 0.0); i2 = vec3(0.0, 1.0, 1.0); }
		else { i1 = vec3(0.0, 1.0, 0.0); i2 = vec3(1.0, 1.0, 0.0); }
	}

	// Координаты трёх углов симплекса
	vec3 x1 = x0 - i1 + G3;
	vec3 x2 = x0 - i2 + 2.0 * G3;
	vec3 x3 = x0 - 1.0 + 3.0 * G3;

	// Градиенты
	vec4 n;
	vec4 t4 = vec4(0.6) - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3));
	t4 = max(t4, 0.0);
	t4 *= t4;

	n.x = t4.x * t4.x * hash(i);
	n.y = t4.y * t4.y * hash(i + i1);
	n.z = t4.z * t4.z * hash(i + i2);
	n.w = t4.w * t4.w * hash(i + vec3(1.0));

	return 32.0 * (n.x + n.y + n.z + n.w); // Результат в диапазоне [-1, 1]
}

// Преобразование HSV в RGB
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// Координаты в сетке
	vec2 grid_uv = floor(FRAGCOORD.xy / grid_size);
	vec2 local_uv = fract(FRAGCOORD.xy / grid_size);
	float time = TIME * speed; // Анимация по времени

	// Значение шума (как getValue)
	vec3 noise_pos = vec3(grid_uv.x * noise_scale, grid_uv.y * noise_scale, time);
	float noise_value = simplex3(noise_pos) * 3.14159 * 2.0; // Умножаем на 2*PI
	float radius = abs(2.0 * noise_value); // Радиус как в JS
	float value = min(abs(noise_value), 1.0); // Нормализация как в JS

	// Цвет как в JS: hsl(281, 49%, 10*value%)
	float hue = 281.0 / 360.0;
	float saturation = 0.49;
	float brightness = floor(10.0 * value) / 100.0; // 0-10% яркость
	vec3 hsv = vec3(hue, saturation, brightness);
	vec3 rgb = hsv2rgb(hsv);

	// Рисуем круг без чёрного фона
	float dist = length(local_uv - vec2(0.5));
	float circle = smoothstep(radius + 0.05, radius - 0.05, dist); // Плавные края
	vec3 color = mix(rgb, vec3(0.1, 0.1, 0.1), circle); // Лёгкий серый фон вместо чёрного

	COLOR = vec4(color, 1.0);
}
