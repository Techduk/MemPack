shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.85; // Скорость анимации
uniform float noise_scale : hint_range(0.0001, 0.01) = 0.0028; // Масштаб шума
uniform float grid_size : hint_range(5.0, 20.0) = 11.0; // Размер ячейки

// Функция шума (упрощённая версия)
float noise(vec2 p) {
return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
vec2 i = floor(p);
vec2 f = fract(p);
vec2 u = f * f * (3.0 - 2.0 * f); // Сглаживание
return mix(mix(noise(i + vec2(0.0, 0.0)), noise(i + vec2(1.0, 0.0)), u.x),
mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0, 1.0)), u.x), u.y);
}

float perlin_noise(vec2 p) {
float total = 0.0;
float persistence = 0.5;
float n = 4.0; // Количество октав
float amplitude = 1.0;
float frequency = 1.0;
for (int i = 0; i < int(n); i++) {
total += smooth_noise(p * frequency) * amplitude;
frequency *= 2.0;
amplitude *= persistence;
}
return total;
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
vec2 local_uv = fract(FRAGCOORD.xy / grid_size); // Локальные координаты в ячейке
float time = TIME * speed; // Анимация по времени

// Генерация шума с анимацией
float noise_value = perlin_noise(grid_uv * noise_scale + vec2(time, time));
float radius = clamp(abs(noise_value) * 0.4, 0.1, 0.5); // Радиус круга от 0.1 до 0.5
noise_value = clamp(noise_value, 0.0, 1.0); // Нормализуем для цвета

// Цвет в формате HSV
float hue = fract(time * 0.05); // Плавная смена оттенка
float saturation = 0.8; // Более яркая насыщенность
float value = noise_value * 0.8 + 0.2; // Яркость от 0.2 до 1.0
vec3 hsv = vec3(hue, saturation, value);
vec3 rgb = hsv2rgb(hsv); // Преобразование HSV в RGB

// Рисуем чёткий круг
float dist = length(local_uv - vec2(0.5)); // Расстояние от центра ячейки
float circle = step(dist, radius); // Чёткий круг
vec3 color = mix(vec3(0.0), rgb, circle); // Цвет круга или прозрачный фон

COLOR = vec4(color, 1.0);
}