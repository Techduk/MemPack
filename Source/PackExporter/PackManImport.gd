extends Node

const Launcher = preload("res://Source/Launcher.gd")

func _ready():
	print("Запуск PackManImport.gd")
	var device_id = "1d2caea35407520b0005988da45067fbb982273e1dc13e397724af839640d62c"
	var license_keys = {"DeBity": "NaN"}
	print("Device ID: ", device_id)
	print("License keys: ", license_keys)
	
	var launcher = Launcher.new()
	print("Попытка загрузки Launcher.gd")
	if launcher:
		print("Launcher загружен")
		launcher.import_pack()
	else:
		print("Ошибка загрузки Launcher.gd")
