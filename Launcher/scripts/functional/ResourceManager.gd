extends Node

# Массив текстур иконок
var icon_textures: Array[Texture2D] = []
# Список использованных индексов иконок
var used_icons: Array[int] = []

func _ready():
	# Загружаем иконки при старте
	load_icons_from_dev()

func load_icons_from_dev():
	# Загружаем иконки из папки разработки
	var dir_path = "res://Packs/TestRoom/Source/Images/Player_icons/"
	print("Попытка открыть папку: ", dir_path)
	var dir = DirAccess.open(dir_path)
	icon_textures.clear()
	used_icons.clear()
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		print("Файлы в папке: ", file_name)
		while file_name != "":
			print("Обработка файла: ", file_name)
			if file_name.ends_with(".png"):
				var full_path = dir_path + file_name
				print("Загрузка: ", full_path)
				var texture = load(full_path)
				if texture:
					icon_textures.append(texture)
					print("Иконка загружена: ", file_name)
				else:
					print("Ошибка: Не удалось загрузить иконку: ", full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		print("Загружены иконки (разработка): ", icon_textures.size())
	else:
		print("Ошибка: Не удалось открыть папку: ", dir_path)

func load_icons_from_mempack(pack_data: Dictionary, pack_buffer: PackedByteArray):
	# Загружаем иконки из .mempack
	icon_textures.clear()
	used_icons.clear()
	for asset_key in pack_data["asset_offsets"]:
		if asset_key.begins_with("Images/Player_icons/") and asset_key.ends_with(".png"):
			var offset = pack_data["asset_offsets"][asset_key]["offset"]
			var size = pack_data["asset_offsets"][asset_key]["size"]
			var image_data = pack_buffer.slice(offset, offset + size)
			if image_data.size() >= 4 and image_data[0] == 137 and image_data[1] == 80 and image_data[2] == 78 and image_data[3] == 71:
				var img = Image.new()
				if img.load_png_from_buffer(image_data) == OK:
					var texture = ImageTexture.create_from_image(img)
					icon_textures.append(texture)
					print("Загружена иконка из .mempack: ", asset_key)
				else:
					print("Ошибка: Не удалось загрузить PNG: ", asset_key)
			else:
				print("Ошибка: Файл не является PNG: ", asset_key)
	if icon_textures.is_empty():
		print("Ошибка: Иконки не найдены в .mempack")

func get_random_icon() -> Texture2D:
	# Возвращаем случайную иконку, не занятую другим игроком
	if icon_textures.is_empty():
		print("Ошибка: Нет доступных иконок")
		return null
	var icon_index = randi() % icon_textures.size()
	while icon_index in used_icons and used_icons.size() < icon_textures.size():
		icon_index = randi() % icon_textures.size()
	used_icons.append(icon_index)
	print("Выбрана иконка с индексом: ", icon_index)
	return icon_textures[icon_index]

func reset_used_icons():
	# Сбрасываем использованные иконки
	used_icons.clear()
