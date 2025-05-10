extends Node

var PACK_DIR = ""

func _ready():
	PACK_DIR = OS.get_executable_path().get_base_dir() + "/packs/"
	print("Launcher.gd: Запуск")
	print("Размер viewport'а: ", get_viewport().size)
	import_pack()

func import_pack():
	print("Сканирование директории: ", PACK_DIR)
	var dir = DirAccess.open(PACK_DIR)
	if not dir:
		print("Ошибка: не удалось открыть директорию ", PACK_DIR)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".mempack"):
			print("Обработка пака: ", file_name)
			var pack_path = PACK_DIR + file_name
			var file = FileAccess.open(pack_path, FileAccess.READ)
			if file:
				var pack_size = file.get_length()
				print("Размер пака: ", pack_size)
				
				var pack_buffer = file.get_buffer(pack_size)
				file.close()
				
				var manifest_size = (pack_buffer[3] << 24) | (pack_buffer[2] << 16) | (pack_buffer[1] << 8) | pack_buffer[0]
				print("Размер манифеста: ", manifest_size)
				
				var manifest_data = pack_buffer.slice(4, 4 + manifest_size)
				var manifest = JSON.parse_string(manifest_data.get_string_from_utf8())
				if not manifest:
					print("Ошибка: не удалось разобрать манифест")
					return
				print("Манифест: ", manifest)
				
				var thumbnail_key = manifest.get("thumbnail", "thumbnail.png")
				if not thumbnail_key in manifest["asset_offsets"]:
					print("Ошибка: thumbnail ", thumbnail_key, " не найден в asset_offsets")
					return
				
				var thumbnail_offset = manifest["asset_offsets"][thumbnail_key]["offset"]
				var thumbnail_size = manifest["asset_offsets"][thumbnail_key]["size"]
				print("Извлечение thumbnail: offset ", thumbnail_offset, ", размер ", thumbnail_size)
				
				var thumbnail_data = pack_buffer.slice(thumbnail_offset, thumbnail_offset + thumbnail_size)
				if thumbnail_data.size() != thumbnail_size:
					print("Ошибка: размер thumbnail не совпадает, ожидалось ", thumbnail_size, ", получено ", thumbnail_data.size())
					return
				
				print("Первые 4 байта thumbnail: ", [thumbnail_data[0], thumbnail_data[1], thumbnail_data[2], thumbnail_data[3]])
				if thumbnail_data[0] != 137 or thumbnail_data[1] != 80 or thumbnail_data[2] != 78 or thumbnail_data[3] != 71:
					print("Ошибка: thumbnail не является валидным PNG")
					return
				
				var img = Image.new()
				var err = img.load_png_from_buffer(thumbnail_data)
				if err != OK:
					print("Ошибка загрузки PNG: ", err)
					return
				
				var debug_file = FileAccess.open("user://thumbnail_debug.png", FileAccess.WRITE)
				if debug_file:
					debug_file.store_buffer(thumbnail_data)
					debug_file.close()
					print("Thumbnail сохранён: user://thumbnail_debug.png")
				
				if ResourceLoader.exists("res://Source/button.tscn"):
					var button_scene = load("res://Source/button.tscn")
					var button_instance = button_scene.instantiate()
					var thumbnail_node = button_instance.get_node("thumbnail")
					if thumbnail_node and thumbnail_node is TextureRect:
						var texture = ImageTexture.create_from_image(img)
						thumbnail_node.texture = texture
						print("Thumbnail установлен")
					button_instance.position = Vector2(50, 50)
					if button_instance is Button:
						button_instance.connect("pressed", Callable(self, "_on_pack_button_pressed").bind(manifest, pack_buffer))
					add_child(button_instance)
					print("Кнопка добавлена для пака: ", manifest["name"])
				else:
					print("Ошибка: не найдена сцена button.tscn")
			else:
				print("Ошибка: не удалось открыть файл ", pack_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_pack_button_pressed(pack_data: Dictionary, pack_buffer: PackedByteArray):
	print("Открытие карточки пака: ", pack_data["name"])
	if ResourceLoader.exists("res://Source/GameCard.tscn"):
		var card_scene = load("res://Source/GameCard.tscn")
		var card_instance = card_scene.instantiate()
		card_instance.set_data(pack_data, pack_buffer)
		add_child(card_instance)
		print("Карточка пака добавлена: ", pack_data["name"])
	else:
		print("Ошибка: не удалось загрузить сцену res://Source/GameCard.tscn")
