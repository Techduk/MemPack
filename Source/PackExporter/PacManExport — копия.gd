extends Node

const PACK_DIR = "user://packs/"
const DEVICE_ID_PATH = "user://device_id.txt"
const LICENSE_KEYS_PATH = "user://license_keys.json"

var device_id = ""
var license_keys = {} # {pack_name: pack_code}

func _ready():
	print("Запуск PacManExport.gd")
	# Генерируем или загружаем device_id
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var file = FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		device_id = file.get_line()
		file.close()
	else:
		device_id = str(randi()).sha256_text() # Генерируем уникальный ID
		var file = FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
		file.store_line(device_id)
		file.close()
	print("Device ID: ", device_id)
	
	# Загружаем сохранённые лицензионные ключи
	if FileAccess.file_exists(LICENSE_KEYS_PATH):
		var file = FileAccess.open(LICENSE_KEYS_PATH, FileAccess.READ)
		license_keys = JSON.parse_string(file.get_as_text())
		file.close()
	print("License keys: ", license_keys)
	
	# Тестирование: экспорт, активация и проверка
	print("Попытка загрузки PackExporter.gd")
	var exporter = null
	if ResourceLoader.exists("res://Source/PackExporter/PackExporter.gd"):
		exporter = preload("res://Source/PackExporter/PackExporter.gd").new()
		print("PackExporter загружен")
	else:
		print("Ошибка: PackExporter.gd не найден")
		return
	
	print("Попытка загрузки PackManImport.gd")
	var importer = null
	if ResourceLoader.exists("res://Source/PackExporter/PackManImport.gd"):
		importer = preload("res://Source/PackExporter/PackManImport.gd").new()
		print("PackManImport загружен")
	else:
		print("Ошибка: PackManImport.gd не найден")
		return
	
	print("Попытка экспорта пака DeBity")
	exporter.export_pack("DeBity", "res://Packs/DeBity", "NaN")
	
	var success = importer.activate_pack("DeBity", "NaN")
	if success:
		print("Пак активирован")
	
	var result = importer.check_pack("DeBity")
	if result["valid"]:
		print("Пак действителен: " + result["manifest"]["name"])
	else:
		print("Ошибка: " + result["error"])
