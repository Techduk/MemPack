extends Control

# --- Секция переменных ---
@onready var room_label = $RoomLabel
@onready var players_container = $PlayersContainer

# Сохранение состояния игроков
var player_nodes = {}

func _ready():
	ServerCore.start_server()
	ServerCore.room_created.connect(_on_room_created)
	ServerCore.player_joined.connect(_on_player_joined)
	ServerCore.player_disconnected.connect(_on_player_disconnected)
	ServerCore.error_occurred.connect(_on_error)
	ServerCore.player_updated.connect(_on_player_updated)
	print("Room.tscn: Загрузка начата")
	print("RoomLabel: ", room_label)
	print("PlayersContainer: ", players_container)
	if ServerCore.player_joined.is_connected(_on_player_joined):
		print("Сигнал player_joined подключён")
	else:
		print("Ошибка: Сигнал player_joined НЕ подключён")

func _on_room_created(room_code: String, join_link: String):
	room_label.text = "Код комнаты: %s" % [room_code]
	$QRCodeRect.data = join_link
	$QRCodeRect.visible = true
	$Connecting.visible = false
	print("Отображено: ", room_label.text)

func _on_player_joined(_room: String, player_name: String, player_id: String):  # ИЗМЕНЕНО: Добавлен player_id
	print("Создание PlayerItem для ", player_name, " с ID: ", player_id)
	if not player_nodes.has(player_name):
		# Инстанцируем новую сцену PlayerItem
		var player_item = preload("res://Packs/TestRoom/TheRoom/PlayerItem.tscn").instantiate()
		player_item.player_name = player_name
		player_item.player_id = player_id  # ИЗМЕНЕНО: Устанавливаем player_id
		
		# Получаем случайную иконку из ResourceManager
		var resource_manager = get_node_or_null("/root/ResourceManager")
		if resource_manager:
			player_item.icon_texture = resource_manager.get_random_icon()
		else:
			print("Ошибка: ResourceManager не найден")
			room_label.text += "\nОшибка: ResourceManager не найден"
		
		players_container.add_child(player_item)
		player_nodes[player_name] = player_item
	else:
		print("Игрок ", player_name, " уже существует, обновление пропущено")

func _on_player_disconnected(_room: String, player_name: String):
	var player_node = player_nodes.get(player_name)
	if player_node:
		player_node.queue_free()
		player_nodes.erase(player_name)
		print("Игрок ", player_name, " удалён из списка")

func _on_player_updated(_room: String, player_name: String, frozen: bool):
	var player_node = player_nodes.get(player_name)
	if player_node:
		player_node.set_frozen(frozen)
		print("Игрок ", player_name, " обновлён, frozen: ", frozen)

func _on_error(error: String):
	room_label.text += "\nОшибка: " + error
	print("Ошибка: ", error)
