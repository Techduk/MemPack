extends Control

var pack_data: Dictionary
var pack_buffer: PackedByteArray

func _ready():
	# Подключаем сигналы один раз при создании карточки
	var play_button = $Panel/PlayButton
	if play_button and play_button is Button:
		play_button.connect("pressed", Callable(self, "_on_play_button_pressed"))
		print("Кнопка 'Играть' подключена")
	
	var close_button = $Panel/Close
	if close_button and close_button is Button:
		close_button.connect("pressed", Callable(self, "_on_close_button_pressed"))
		print("Кнопка 'Close' подключена")

func set_data(data: Dictionary, buffer: PackedByteArray):
	pack_data = data
	pack_buffer = buffer
	
	# Устанавливаем имя пака в описание
	var description_node = $Panel/VBoxContainer/DescriptionLabel
	if description_node and description_node is Label:
		description_node.text = pack_data.get("name", "Unknown Pack")
		print("Описание установлено: ", description_node.text)
	
	# Устанавливаем обложку
	var preview_key = pack_data.get("preview", "preview.png")
	if not preview_key in pack_data["asset_offsets"]:
		print("Ошибка: preview ", preview_key, " не найден в asset_offsets")
		return
	
	var preview_offset = pack_data["asset_offsets"][preview_key]["offset"]
	var preview_size = pack_data["asset_offsets"][preview_key]["size"]
	var preview_data = pack_buffer.slice(preview_offset, preview_offset + preview_size)
	
	if preview_data.size() != preview_size:
		print("Ошибка: размер preview не совпадает, ожидалось ", preview_size, ", получено ", preview_data.size())
		return
	
	if preview_data[0] != 137 or preview_data[1] != 80 or preview_data[2] != 78 or preview_data[3] != 71:
		print("Ошибка: preview не является валидным PNG")
		return
	
	var img = Image.new()
	var err = img.load_png_from_buffer(preview_data)
	if err != OK:
		print("Ошибка загрузки PNG: ", err)
		return
	
	var preview_node = $Panel/VBoxContainer/Prewiew
	if preview_node and preview_node is TextureRect:
		var texture = ImageTexture.create_from_image(img)
		preview_node.texture = texture
		print("Обложка установлена для карточки пака: ", pack_data["name"])

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

func _on_close_button_pressed():
	print("Закрытие карточки пака: ", pack_data["name"])
	queue_free()
	print("Карточка пака успешно закрыта")

func _start_mouse_entered():
	var tween = create_tween()
	tween.tween_property($Panel/PlayButton, "scale", Vector2(1.05, 1.05), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _start_mouse_exited():
	var tween = create_tween()
	tween.tween_property($Panel/PlayButton, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _close_mouse_entered():
	var tween = create_tween()
	tween.tween_property($Panel/Close, "scale", Vector2(0.85, 0.85), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _close_mouse_exited():
	var tween = create_tween()
	tween.tween_property($Panel/Close, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
