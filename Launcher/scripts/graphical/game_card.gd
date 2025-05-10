extends Control

var pack_data: Dictionary
var pack_buffer: PackedByteArray

func set_data(data: Dictionary, buffer: PackedByteArray):
	pack_data = data
	pack_buffer = buffer
	
	# Устанавливаем имя пака в описание
	var description_node = $Panel/HBoxContainer/DescriptionLabel
	if description_node and description_node is Label:
		description_node.text = pack_data.get("name", "Unknown Pack")
		print("Описание установлено: ", description_node.text)
	
	# Устанавливаем обложку
	var thumbnail_key = pack_data.get("thumbnail", "thumbnail.png")
	if not thumbnail_key in pack_data["asset_offsets"]:
		print("Ошибка: thumbnail ", thumbnail_key, " не найден в asset_offsets")
		return
	
	var thumbnail_offset = pack_data["asset_offsets"][thumbnail_key]["offset"]
	var thumbnail_size = pack_data["asset_offsets"][thumbnail_key]["size"]
	var thumbnail_data = pack_buffer.slice(thumbnail_offset, thumbnail_offset + thumbnail_size)
	
	if thumbnail_data.size() != thumbnail_size:
		print("Ошибка: размер thumbnail не совпадает, ожидалось ", thumbnail_size, ", получено ", thumbnail_data.size())
		return
	
	if thumbnail_data[0] != 137 or thumbnail_data[1] != 80 or thumbnail_data[2] != 78 or thumbnail_data[3] != 71:
		print("Ошибка: thumbnail не является валидным PNG")
		return
	
	var img = Image.new()
	var err = img.load_png_from_buffer(thumbnail_data)
	if err != OK:
		print("Ошибка загрузки PNG: ", err)
		return
	
	var thumbnail_node = $Panel/HBoxContainer/Prewiew
	if thumbnail_node and thumbnail_node is TextureRect:
		var texture = ImageTexture.create_from_image(img)
		thumbnail_node.texture = texture
		print("Обложка установлена для карточки пака: ", pack_data["name"])
	
	# Подключаем кнопку "Играть"
	var play_button = $Panel/PlayButton
	if play_button and play_button is Button:
		play_button.connect("pressed", Callable(self, "_on_play_button_pressed"))
		print("Кнопка 'Играть' подключена")

func _on_play_button_pressed():
	print("Запуск пака: ", pack_data["name"])
	
	# Извлекаем entry_scene
	var entry_scene_key = pack_data.get("entry_scene", "Main.tscn")
	if not entry_scene_key in pack_data["asset_offsets"]:
		print("Ошибка: entry_scene ", entry_scene_key, " не найдена в asset_offsets")
		return
	
	var entry_scene_offset = pack_data["asset_offsets"][entry_scene_key]["offset"]
	var entry_scene_size = pack_data["asset_offsets"][entry_scene_key]["size"]
	var entry_scene_data = pack_buffer.slice(entry_scene_offset, entry_scene_offset + entry_scene_size)
	
	# Сохраняем entry_scene во временный файл
	var temp_path = "user://temp_main.tscn"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		file.store_buffer(entry_scene_data)
		file.close()
		print("Entry scene сохранена во временный файл: ", temp_path)
	else:
		print("Ошибка: не удалось сохранить entry scene во временный файл")
		return
	
	# Загружаем сцену
	var entry_scene = load(temp_path)
	if not entry_scene:
		print("Ошибка: не удалось загрузить entry scene из ", temp_path)
		return
	
	# Переключаемся на новую сцену
	var err = get_tree().change_scene_to_packed(entry_scene)
	if err != OK:
		print("Ошибка при переключении на новую сцену: ", err)
		return
	
	print("Успешно переключились на сцену пака: ", pack_data["name"])
