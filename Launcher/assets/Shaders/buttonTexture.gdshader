shader_type canvas_item;

uniform sampler2D texture_mask; // Текстура маски (белый = видимая область, чёрный/прозрачный = обрезанная)

void fragment() {
    // Получаем цвет пикселя из основной текстуры
    vec4 color = texture(TEXTURE, UV);
    
    // Получаем значение маски для текущей координаты
    vec4 mask = texture(texture_mask, UV);
    
    // Применяем маску: умножаем альфа-канал цвета на альфа-канал маски
    color.a *= mask.a;
    
    COLOR = color;
}