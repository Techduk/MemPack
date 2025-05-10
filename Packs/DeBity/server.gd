extends Node

var ws = WebSocketPeer.new()
var rooms = {}
var json = JSON.new()
var session_id: String
const CLOUD_SERVER = "wss://d157c5fe-adbb-4070-904d-12484e03e36b-00-1rf82vx1m48hg.spock.replit.dev"
var is_connected := false
var chat_display = null  # Инициализируем как null

func _ready():
	# Генерируем session_id
	session_id = generate_session_id()
	print("Generated session_id:", session_id)
	
	# Подключаемся к облачному серверу
	var error = ws.connect_to_url(CLOUD_SERVER + "/ws/" + session_id)
	if error != OK:
		print("Failed to connect to cloud server, error:", error)
		_show_warning("Failed to connect to server. Try restarting the game.")
		return
	print("Connecting to cloud server:", CLOUD_SERVER)
	
	# Пытаемся найти ChatDisplay
	chat_display = get_node_or_null("../ChatDisplay")
	if chat_display:
		print("ChatDisplay found")
	else:
		print("Warning: ChatDisplay not found in scene. Check scene hierarchy.")

func _process(delta):
	ws.poll()
	var state = ws.get_ready_state()
	#print("WebSocket state:", state)  # Добавляем лог состояния
	if state == WebSocketPeer.STATE_OPEN and not is_connected:
		print("WebSocket connection opened, sending create request")
		ws.send_text(JSON.stringify({ "type": "create" }))
		is_connected = true
	elif state == WebSocketPeer.STATE_CLOSING:
		print("WebSocket closing...")
	elif state == WebSocketPeer.STATE_CLOSED:
		print("WebSocket closed")
		_show_warning("Connection to server lost. Try restarting the game.")
	
	while ws.get_available_packet_count() > 0:
		var packet = ws.get_packet()
		var message = packet.get_string_from_utf8()
		print("Received raw packet:", message)  # Добавляем лог полученных данных
		var error = json.parse(message)
		if error == OK:
			var data = json.get_data()
			_handle_message(data)
		else:
			print("JSON parse error:", json.get_error_message())

func _handle_message(data: Dictionary):
	print("Received from cloud:", data)
	if data["type"] == "room_created":
		session_id = data["roomCode"]
		var join_link = data["link"]
		print("Room created, link:", join_link)
		
		# Отображаем ссылку в интерфейсе
		var link_label = Label.new()
		link_label.text = "Share this link: " + join_link
		link_label.position = Vector2(10, 50)
		add_child(link_label)
		
		# Копируем ссылку в буфер обмена
		DisplayServer.clipboard_set(join_link)
		print("Link copied to clipboard")
		if chat_display:
			chat_display.add_message("Room created: " + join_link)
	
	elif data["type"] == "join":
		if not rooms.has(session_id):
			rooms[session_id] = []
		rooms[session_id].append(data["name"])
		_broadcast(session_id, { "type": "join", "name": data["name"], "text": data["text"] })
		print("[Join] Player", data["name"], "joined room", session_id)
		if chat_display:
			chat_display.add_message(data["name"] + " joined")
	
	elif data["type"] == "message":
		_broadcast(session_id, { "type": "message", "name": data["name"], "text": data["text"] })
		print("[Chat] Message from", data["name"], ":", data["text"])
		if chat_display:
			chat_display.add_message(data["name"] + ": " + data["text"])
	
	elif data["type"] == "system":
		print("[System] ", data["text"])
		if chat_display:
			chat_display.add_message("[System] " + data["text"])
	
	elif data["type"] == "error":
		print("Cloud server error:", data["text"])
		_show_warning("Error: " + data["text"])
		if chat_display:
			chat_display.add_message("Error: " + data["text"])

func _broadcast(room: String, data: Dictionary):
	if rooms.has(room):
		var payload = JSON.stringify(data)
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(payload)
		print("Broadcasting:", payload)

func generate_session_id() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var id = ""
	for i in 6:
		id += chars[randi() % chars.length()]
	return id

func _show_warning(message: String):
	var warning_label = Label.new()
	warning_label.text = message
	warning_label.position = Vector2(10, 10)
	warning_label.modulate = Color.RED
	add_child(warning_label)
