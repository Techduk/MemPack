extends ScrollContainer

# Сцена кнопки (предполагается, что у тебя уже есть PackButton.tscn)
const PACK_BUTTON_SCENE = preload("res://Source/button.tscn")

func _ready():
	scan_packs()

func scan_packs():
	var dir = DirAccess.open("user://packs/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".mempack"):
				create_pack_button(file_name.trim_suffix(".mempack"))
			file_name = dir.get_next()
		dir.list_dir_end()

func create_pack_button(pack_name):
	var button = PACK_BUTTON_SCENE.instantiate()
	button.name = pack_name
	$VBoxContainer.add_child(button)
	
	# Загрузка изображения из пака (пример, нужно доработать с расшифровкой)
	var image_path = "user://temp/" + pack_name + "_thumbnail.png"
	#if FileAccess.file_exists(image_path):
		#var image = Image.load(image_path)
		#var texture = ImageTexture.create_from_image(image)
		#button.get_node("TextureRect").texture = texture
   # else:
		#print("Изображение для " + pack_name + " не найдено")
	
	# Подключение сигнала для запуска пака
	button.connect("pressed", Callable(self, "_on_pack_button_pressed").bind(pack_name))

func _on_pack_button_pressed(pack_name):
	print("Запуск пака: " + pack_name)
	# Здесь логика запуска пака (доработаем позже)
	# Например: var scene_path = "res://packs/" + pack_name + "/game_main.tscn"
	# get_tree().change_scene_to_file(scene_path)
