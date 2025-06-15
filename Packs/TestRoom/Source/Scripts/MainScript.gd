extends Node

var is_fullscreen

func _ready():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	
	if get_window().mode == Window.MODE_FULLSCREEN:
		is_fullscreen = true

# F11 or FullScreen
func _input(event):
	# Проверяем, была ли нажата клавиша F11
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			toggle_fullscreen()

func toggle_fullscreen():
	if is_fullscreen:
		# Переключаем в оконный режим 1280x720
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		# Центрируем окно (опционально)
		var screen_size = DisplayServer.screen_get_size()
		var window_size = Vector2i(1280, 720)
		DisplayServer.window_set_position((screen_size - window_size) / 2)
	else:
		# Переключаем в полноэкранный режим
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Инвертируем состояние
	is_fullscreen = !is_fullscreen
