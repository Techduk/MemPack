extends Control

var progress_bar: ProgressBar

func _ready():
	progress_bar = $ProgressBar
	start_loading()

func start_loading():
	var thread = Thread.new()
	thread.start(Callable(self, "_load_resources"))

func _load_resources():
	# Здесь извлекай ресурсы из .mempack, например:
	#var entry_scene_data = extract_from_pack()  # Твоя функция извлечения
	#save_to_temp_file(entry_scene_data)         # Сохранение сцены
	#call_deferred("_on_loading_complete")
	pass

func _on_loading_complete():
	var tween = create_tween()
	tween.tween_property($ColorRect, "modulate:a", 1.0, 0.5)  # Затемнение за 0.5 сек
	tween.tween_callback(Callable(self, "_switch_to_game"))

func _switch_to_game():
	var entry_scene = load("user://temp_main.tscn")
	get_tree().change_scene_to_packed(entry_scene)
