extends Control

# Экспортируемые переменные для передачи данных
@export var player_name : String = "Player"
@export var player_id : String
@export var icon_texture : Texture2D

# Узлы сцены
@onready var player_icon = $PlayerIcon
@onready var player_label = $PlayerName
@onready var action_panel = $ActionPanel
@onready var freeze_button = $ActionPanel/FreezeButton

func _ready():
	print("PlayerItem _ready() called for ", player_name)  # Отладка
	if icon_texture:
		player_icon.texture = icon_texture
	else:
		print("Ошибка: icon_texture не задан для ", player_name)
	player_label.text = player_name
	action_panel.visible = false
	
	# Подключение сигнала клика на иконку
	player_icon.connect("gui_input", _on_icon_clicked)
	# Подключение сигнала кнопки
	if not freeze_button.is_connected("pressed", _on_freeze_button_pressed):
		freeze_button.connect("pressed", _on_freeze_button_pressed)

func _on_icon_clicked(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Уменьшаем иконку при нажатии с помощью Tween
			var tween = create_tween()
			tween.tween_property(player_icon, "scale", Vector2(0.9, 0.9), 0.05)  # Уменьшаем до 90% за 0.05 сек
			action_panel.visible = true
		else:
			# Возвращаем исходный размер при отпускании
			var tween = create_tween()
			tween.tween_property(player_icon, "scale", Vector2(1, 1), 0.05)
			print("Клик зарегистрирован на иконке для ", player_name)  # Отладка

# Отправка команды заморозки на сервер
func _on_freeze_button_pressed():
	var server_core = get_node("/root/ServerCore")
	if server_core and server_core.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		server_core.send_request({
			"type": "freeze",
			"id": player_id  # Используем переданный player_id
		})
		print("Sent freeze request for player_id: ", player_id)

# Пустая функция для кика игрока (будет реализована позже)
func _on_kick_player():
	pass

# Закрытие меню
func _on_close_menu():
	action_panel.visible = false
