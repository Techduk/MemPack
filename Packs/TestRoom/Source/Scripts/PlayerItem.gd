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
@onready var kick_button = $ActionPanel/KickButton

var frozen : bool = false

func _ready():
	print("PlayerItem _ready() called for ", player_name, " with ID: ", player_id)
	if icon_texture:
		player_icon.texture = icon_texture
	else:
		print("Ошибка: icon_texture не задан для ", player_name)
	player_label.text = player_name
	action_panel.visible = false
	freeze_button.text = "Заморозить"
	player_icon.modulate = Color(1, 1, 1)
	
	# Подключение сигнала клика на иконку
	player_icon.connect("gui_input", _on_icon_clicked)
	# Подключение сигнала кнопки Freeze
	if not freeze_button.is_connected("pressed", _on_freeze_button_pressed):
		freeze_button.connect("pressed", _on_freeze_button_pressed)
	# Подключение сигнала кнопки Kick
	if kick_button and not kick_button.is_connected("pressed", _on_kick_player):
		kick_button.connect("pressed", _on_kick_player)

func _on_icon_clicked(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Уменьшаем иконку при нажатии с помощью Tween
			var tween = create_tween()
			tween.tween_property(player_icon, "scale", Vector2(0.9, 0.9), 0.05)
			action_panel.visible = true
		else:
			# Возвращаем исходный размер при отпускании
			var tween = create_tween()
			tween.tween_property(player_icon, "scale", Vector2(1, 1), 0.05)
			print("Клик зарегистрирован на иконке для ", player_name)

# Отправка команды заморозки или разморозки на сервер
func _on_freeze_button_pressed():
	var server_core = get_node("/root/ServerCore")
	if server_core and server_core.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if player_id == "":
			print("Ошибка: player_id пустой для ", player_name, ". Запрос не отправлен.")
			return
		var request_type = "unfreeze" if frozen else "freeze"
		server_core.send_request({
			"type": request_type,
			"id": player_id
		})
		print("Отправлен запрос ", request_type, " для player_id: ", player_id)
	else:
		print("Ошибка: WebSocket не подключён или ServerCore не найден для ", player_name)

# Отправка команды кика на сервер
func _on_kick_player():
	var server_core = get_node("/root/ServerCore")
	if server_core and server_core.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if player_id == "":
			print("Ошибка: player_id пустой для ", player_name, ". Запрос kick не отправлен.")
			return
		server_core.send_request({
			"type": "kick",
			"id": player_id
		})
		print("Отправлен запрос kick для player_id: ", player_id)
	else:
		print("Ошибка: WebSocket не подключён или ServerCore не найден для ", player_name)

# Метод для обновления статуса заморозки
func set_frozen(is_frozen: bool):
	frozen = is_frozen
	freeze_button.text = "Разморозить" if frozen else "Заморозить"
	player_icon.modulate = Color(0.5, 0.5, 0.5) if frozen else Color(1, 1, 1)
	print("Игрок ", player_name, " заморожен: ", frozen)

# Закрытие меню
func _on_close_menu():
	action_panel.visible = false
