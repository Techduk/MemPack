extends Node

const SETTINGS_PATH = "res://settings.cfg"

const RESOLUTIONS : Dictionary = {
	"640x480" : Vector2i(640, 480),  # 4:3
	"800x600" : Vector2i(800, 600),  # 4:3
	"1024x768" : Vector2i(1024, 768),  # 4:3
	"1280x720" : Vector2i(1280, 720),  # 16:9
	"1280x1024" : Vector2i(1280, 1024),  # 4:3
	"1366x768" : Vector2i(1366, 768),  # 16:9
	"1440x900" : Vector2i(1440, 900),  # 16:10
	"1600x900" : Vector2i(1600, 900),  # 16:9
	"1920x1080 (Recommended)" : Vector2i(1920, 1080),  # 16:9
	"1920x1200" : Vector2i(1920, 1200),  # 16:10
	"2048x1080" : Vector2i(2048, 1080),  # 17:9
	"2560x1440" : Vector2i(2560, 1440),  # 16:9
	"3200x1800" : Vector2i(3200, 1800),  # 16:9
	"2560x1080" : Vector2i(2560, 1080),  # 21:9
	"3440x1440" : Vector2i(3440, 1440)  # 21:9
}

@onready var option_button = $Panel/ScreenSize  # Путь к твоему OptionButton


# Дефолтные настройки
var settings = {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"vsync": false,
	"fullscreen": true
}

# При запуске игры
func _ready():
	add_resolution_items()
	
	if not get_window().mode == Window.MODE_FULLSCREEN:
		_set_initial_resolution()

#
func _set_initial_resolution():
	var current_size = DisplayServer.window_get_size()
	for i in range(RESOLUTIONS.size()):
		if current_size == RESOLUTIONS.values()[i]:
			option_button.select(i)
			break
		else:
			option_button.select(3)
			DisplayServer.window_set_size(RESOLUTIONS.values()[3])
			break

# Vsync
func _on_v_sync_toggled(_toggled_on):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
func _on_v_sync_toggled_off(_toggled_off):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


# FullScreen
func _on_full_screen_pressed():
	var window = get_window()
	if window.mode == Window.MODE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
		$Panel/FullScreen.set_pressed(false)
	else:
		window.mode = Window.MODE_FULLSCREEN
		$Panel/FullScreen.set_pressed(true)


# Resolution
func add_resolution_items() -> void:
	for resolution_size_text in RESOLUTIONS:
		option_button.add_item(resolution_size_text)

func _on_screen_size_item_selected(index : int) -> void:
	DisplayServer.window_set_size(RESOLUTIONS.values()[index])
