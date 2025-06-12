extends Node

const SETTINGS_PATH = "res://settings.cfg"

# Дефолтные настройки
var settings = {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"fullscreen": true
}

func _ready():
	load_settings()

# Загрузка настроек из файла
func load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for key in settings.keys():
			settings[key] = config.get_value("settings", key, settings[key])
	apply_settings()

# Сохранение настроек в файл
func save_settings():
	var config = ConfigFile.new()
	for key in settings.keys():
		config.set_value("settings", key, settings[key])
	config.save(SETTINGS_PATH)

# Применение настроек
func apply_settings():
	# Аудио
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(settings["master_volume"])
	)
	
	# Графика
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	)
