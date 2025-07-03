extends Control

# --- Секция переменных ---
@onready var room_label = $RoomLabel
@onready var players_container = $PlayersContainer

# Сохранение состояния игроков
var player_nodes = {}

func _ready():
	ServerCore.room_created.connect(_on_room_created)
	ServerCore.player_joined.connect(_on_player_joined)
	ServerCore.player_disconnected.connect(_on_player_disconnected)
	ServerCore.error_occurred.connect(_on_error)
	print("Room.tscn: Загрузка начата")
	print("RoomLabel: ", room_label)
	print("PlayersContainer: ", players_container)
	if ServerCore.player_joined.is_connected(_on_player_joined):
		print("Сигнал player_joined подключён")
	else:
		print("Ошибка: Сигнал player_joined НЕ подключён")

func _on_room_created(room_code: String, join_link: String):
	room_label.text = "Код комнаты: %s\nСсылка: %s" % [room_code, join_link]
	print("Отображено: ", room_label.text)

func _on_player_joined(_room: String, player_name: String):
	print("Игрок присоединился: ", player_name)
	if not player_nodes.has(player_name):
		var player_container = HBoxContainer.new()
		player_container.name = "Player_" + player_name
		print("Создан контейнер: ", player_container.name)
		
		var resource_manager = get_node_or_null("/root/ResourceManager")
		if not resource_manager:
			print("Ошибка: ResourceManager не найден")
			room_label.text += "\nОшибка: ResourceManager не найден"
			return
		var icon_texture = resource_manager.get_random_icon()
		if not icon_texture:
			print("Ошибка: Нет доступных иконок для игрока ", player_name)
			room_label.text += "\nОшибка: Нет иконок"
			return
		
		var icon = TextureRect.new()
		icon.texture = icon_texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(64, 64)
		player_container.add_child(icon)
		print("Добавлена иконка для ", player_name)
		
		var label = Label.new()
		label.text = player_name
		player_container.add_child(label)
		print("Добавлен ник: ", player_name)
		
		players_container.add_child(player_container)
		player_nodes[player_name] = player_container
	else:
		print("Игрок ", player_name, " уже существует, обновление пропущено")

func _on_player_disconnected(_room: String, player_name: String):
	var player_node = player_nodes.get(player_name)
	if player_node:
		player_node.queue_free()
		player_nodes.erase(player_name)
		print("Игрок ", player_name, " удалён из списка")

func _on_error(error: String):
	room_label.text += "\nОшибка: " + error
	print("Ошибка: ", error)
