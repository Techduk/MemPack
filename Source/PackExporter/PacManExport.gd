extends Node

const PackExporter = preload("res://Source/PackExporter/PackExporter.gd")

func _ready():
	print("Запуск PacManExport.gd")
	var device_id = "1d2caea35407520b0005988da45067fbb982273e1dc13e397724af839640d62c"
	var license_keys = {"DeBity": "NaN"}
	print("Device ID: ", device_id)
	print("License keys: ", license_keys)
	
	print("Попытка загрузки PackExporter.gd")
	var exporter = PackExporter.new()
	if exporter:
		print("PackExporter загружен")
		export_pack("DeBity", "res://Packs/CrashTest")
	else:
		print("Ошибка загрузки PackExporter.gd")

func export_pack(pack_name: String, source_dir: String):
	print("Попытка экспорта пака ", pack_name)
	var exporter = PackExporter.new()
	if exporter.export_pack(pack_name, source_dir):
		print("Экспорт пака ", pack_name, " успешно завершён")
	else:
		print("Экспорт пака ", pack_name, " завершился с ошибкой")
