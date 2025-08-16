shader_type canvas_item;

vec2 rot(vec2 uv, float r) {
    float s = sin(r);
    float c = cos(r);
    return vec2(
        uv.x * c - uv.y * s,
        uv.x * s + uv.y * c
    );
}

void fragment() {
    float s = 7.0;        // stripes
    float st = 0.2;       // stripe thickness

    // Получаем размер экрана в пикселях
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

    // Нормализация координат с переворотом Y (Godot: 0=верх, ShaderToy: 0=низ)
    vec2 uv_coord = FRAGCOORD.xy / screen_size;
    uv_coord.y = 1.0 - uv_coord.y;

    // Вращение
    vec2 uv = rot(uv_coord, -0.2 + sin(TIME) * 0.05);

    // Осцилляция и повторение полос
    float osc = sin(uv.x * (uv.x + 0.5) * 15.0) * 0.2;
    uv.y += osc * sin(TIME + uv.x * 2.0);
    uv.y = fract(uv.y * s);

    // Цвета
    vec3 fg = vec3(1.0, 1.0, 1.0);
    vec3 bg = vec3(0.0, 0.0, 0.0);

    // Маска для полос
    float mask = smoothstep(0.5, 0.55, uv.y);
    mask += smoothstep(0.5 + st, 0.55 + st, 1.0 - uv.y);

    // Смешивание цветов
    vec3 col = mask * bg + (0.25 - mask) * fg;

    COLOR = vec4(col, 1.0);
}