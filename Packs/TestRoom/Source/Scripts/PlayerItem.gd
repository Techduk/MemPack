extends Control

# Экспортируемые переменные для передачи данных
@export var player_name : String = "Player"
@export var icon_texture : Texture2D

# Узлы сцены
@onready var player_icon = $PlayerIcon
@onready var player_label = $PlayerName
@onready var action_panel = $ActionPanel
@onready var freeze_button = $ActionPanel/FreezeButton

func _ready():
	# Установка данных
	if icon_texture:
		player_icon.texture = icon_texture
	player_label.text = player_name
	action_panel.visible = false
	
	# Подключение сигнала клика на иконку
	player_icon.connect("gui_input", _on_icon_clicked)

func _on_icon_clicked(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Уменьшаем иконку при нажатии с помощью Tween
			var tween = create_tween()
			tween.tween_property(player_icon, "scale", Vector2(0.9, 0.9), 0.05)  # Уменьшаем до 80% за 0.1 сек
			action_panel.visible = true
		else:
			# Возвращаем исходный размер и показываем панельку при отпускании
			var tween = create_tween()
			tween.tween_property(player_icon, "scale", Vector2(1, 1), 0.05)  # Возвращаем к 100x100

# Пустая функция для кика игрока (будет реализована позже)
func _on_kick_player():
	pass

# Пустая функция для заморозки игрока (будет реализована позже)
func _on_freeze_button_pressed():
	pass

# Закрытие меню
func _on_close_menu():
	action_panel.visible = false
