extends Node

# --- Секция переменных ---
var ws = WebSocketPeer.new()
var rooms = {}
var json = JSON.new()
var session_id: String
const CLOUD_SERVER = "wss://www.mempack.fun"
var ws_connected := false
var connection_attempts := 0
const MAX_ATTEMPTS := 6
const RECONNECT_DELAY := 2.0
var player_id : String

# --- Секция сигналов ---
signal room_created(room_code: String, join_link: String)
signal player_joined(room: String, player_name: String)
signal player_disconnected(room: String, player_name: String)
signal error_occurred(error: String)

# --- Сохранение состояния комнаты ---
var room_state = {} # { room_code: { players: [{name: String, score: int}] } }

# --- Инициализация ---
func start_server():
	_generate_unique_session_id()
	# Генерация уникального ID для игрока
	var file = FileAccess.open("user://player_id.txt", FileAccess.READ)
	if file:
		player_id = file.get_as_text()
		file.close()
	if not player_id:
		player_id = generate_unique_id()
		file = FileAccess.open("user://player_id.txt", FileAccess.WRITE)
		file.store_string(player_id)
		file.close()
	print("Player ID: " + player_id)

func generate_unique_id():
	var uuid = ""
	for i in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			uuid += "4"
		else:
			var hex_value = "%x" % (randi() % 16)
			uuid += hex_value
	return uuid

# --- Обработка WebSocket ---
func _process(_delta):
	ws.poll()
	var state = ws.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not ws_connected:
			print("WebSocket-соединение открыто, отправляем запрос на создание комнаты")
			send_request({ "type": "create", "id": player_id })
			if room_state.has(session_id) and room_state[session_id].size() > 0:
				send_request({ "type": "restore", "room": session_id, "state": room_state[session_id], "id": player_id })
			ws_connected = true
			connection_attempts = 0
	elif state == WebSocketPeer.STATE_CLOSING:
		print("WebSocket закрывается, код закрытия: ", ws.get_close_code(), ", причина: ", ws.get_close_reason())
	elif state == WebSocketPeer.STATE_CLOSED:
		if ws_connected:
			print("WebSocket закрыт, код закрытия: ", ws.get_close_code(), ", причина: ", ws.get_close_reason())
			ws_connected = false
			emit_signal("error_occurred", "Соединение с сервером потеряно.")
			_reconnect()
	
	while ws.get_available_packet_count() > 0:
		var packet = ws.get_packet()
		var message = packet.get_string_from_utf8()
		print("Получен необработанный пакет: ", message)
		var error = json.parse(message)
		if error == OK:
			var data = json.get_data()
			_handle_message(data)
		else:
			print("Ошибка парсинга JSON: ", json.get_error_message())
			emit_signal("error_occurred", "Ошибка парсинга ответа сервера.")

# --- Обработка сообщений ---
func _handle_message(data: Dictionary):
	print("Получено от сервера: ", data)
	if data["type"] == "room_created":
		session_id = data["roomCode"]
		var join_link = data["link"]
		print("Комната создана, ссылка: ", join_link)
		DisplayServer.clipboard_set(join_link)
		emit_signal("room_created", session_id, join_link)
	elif data["type"] == "system":
		if data["text"].ends_with("joined"):
			var player_name = data["text"].split(" ")[0]
			print("Извлечено имя игрока: ", player_name)
			if not rooms.has(session_id):
				rooms[session_id] = []
			rooms[session_id].append(player_name)
			if not room_state.has(session_id):
				room_state[session_id] = []
			room_state[session_id].append({"name": player_name, "score": 0})
			emit_signal("player_joined", session_id, player_name)
		elif data["text"].ends_with("disconnected"):
			var player_name = data["text"].split(" ")[0]
			print("Извлечено имя отключённого игрока: ", player_name)
			if rooms.has(session_id) and player_name in rooms[session_id]:
				rooms[session_id].erase(player_name)
				if room_state.has(session_id):
					room_state[session_id] = room_state[session_id].filter(func(p): return p.name != player_name)
				emit_signal("player_disconnected", session_id, player_name)
	elif data["type"] == "restore":
		if data.has("state") and room_state.has(session_id):
			room_state[session_id] = data["state"]
			for player in room_state[session_id]:
				emit_signal("player_joined", session_id, player.name)
	elif data["type"] == "join":
		if not rooms.has(session_id):
			rooms[session_id] = []
		rooms[session_id].append(data["name"])
		if not room_state.has(session_id):
			room_state[session_id] = []
		room_state[session_id].append({"name": data["name"], "score": 0})
		emit_signal("player_joined", session_id, data["name"])
		_broadcast(session_id, { "type": "join", "name": data["name"], "text": data["text"] })
	elif data["type"] == "ping":
		print("Получен пинг от сервера")
		send_request({ "type": "pong", "id": player_id })
		print("Отправлен pong с id: ", player_id)
	elif data["type"] == "error":
		print("Ошибка сервера: ", data["text"])
		if data["text"].contains("Room already exists"):
			_generate_unique_session_id()
		else:
			emit_signal("error_occurred", "Ошибка: " + data["text"])

# --- Вспомогательные функции ---
func send_request(data: Dictionary):
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var payload = JSON.stringify(data)
		ws.send_text(payload)
		print("Отправлено: ", payload)
	else:
		print("Невозможно отправить запрос: WebSocket не подключён")
		emit_signal("error_occurred", "WebSocket не подключён.")

func _broadcast(room: String, data: Dictionary):
	if rooms.has(room):
		var payload = JSON.stringify(data)
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(payload)
		print("Пересылка в комнату ", room, ": ", payload)

func generate_session_id() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var id = ""
	for i in 6:
		id += chars[randi() % chars.length()]
	return id

func _generate_unique_session_id():
	session_id = generate_session_id()
	print("Попытка создать комнату с session_id: ", session_id)
	connection_attempts = 0
	_connect_to_server()

func _connect_to_server():
	ws = WebSocketPeer.new()
	print("Попытка подключения к: ", CLOUD_SERVER + "/ws/" + session_id)
	var error = ws.connect_to_url(CLOUD_SERVER + "/ws/" + session_id)
	var start_time = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_time < 2000:
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			connection_attempts = 0
			print("Подключение успешно: ", CLOUD_SERVER + "/ws/" + session_id)
			return
		await get_tree().create_timer(0.1).timeout
	connection_attempts += 1
	print("Не удалось подключиться, попытка ", connection_attempts, " из ", MAX_ATTEMPTS)
	if connection_attempts < MAX_ATTEMPTS:
		await get_tree().create_timer(RECONNECT_DELAY).timeout
		_connect_to_server()
	else:
		print("Исчерпаны все попытки подключения")
		emit_signal("error_occurred", "Не удалось подключиться к серверу после " + str(MAX_ATTEMPTS) + " попыток.")

func _reconnect():
	if connection_attempts < MAX_ATTEMPTS:
		connection_attempts += 1
		print("Попытка переподключения ", connection_attempts, " из ", MAX_ATTEMPTS)
		await get_tree().create_timer(RECONNECT_DELAY).timeout
		_connect_to_server()
	else:
		print("Исчерпаны все попытки переподключения")
		emit_signal("error_occurred", "Не удалось переподключиться после " + str(MAX_ATTEMPTS) + " попыток.")
