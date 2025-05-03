extends Node

var _server = WebSocketServer.new()
var rooms = {}
var json = JSON.new()
var external_ip: String
var session_id: String

func _ready():
	# Настройка UPnP
	var upnp = UPNP.new()
	var discover_result = upnp.discover(2000, 2, "InternetGatewayDevice")
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		var gateway = upnp.get_gateway()
		if gateway and gateway.is_valid_gateway():
			var map_result_tcp_3001 = upnp.add_port_mapping(3001, 3001, "godot_websocket", "TCP", 0)
			var map_result_tcp_8080 = upnp.add_port_mapping(8080, 8080, "godot_http", "TCP", 0)
			if map_result_tcp_3001 != UPNP.UPNP_RESULT_SUCCESS:
				print("UPnP: Failed to map port 3001, error:", map_result_tcp_3001)
				_show_warning("UPnP: Failed to open port 3001. Manually open port 3001 (TCP).")
			if map_result_tcp_8080 != UPNP.UPNP_RESULT_SUCCESS:
				print("UPnP: Failed to map port 8080, error:", map_result_tcp_8080)
				_show_warning("UPnP: Failed to open port 8080. Manually open port 8080 (TCP).")
			print("UPnP: Ports 3001 (TCP) and 8080 (TCP) opened")
		else:
			print("UPnP: No valid gateway found")
			_show_warning("UPnP: No gateway found. Manually open ports 3001 and 8080 (TCP).")
	else:
		print("UPnP: Discovery failed, error:", discover_result)
		_show_warning("UPnP failed (error: %d). Manually open ports 3001 and 8080 (TCP)." % discover_result)

	# Получаем внешний IP
	external_ip = upnp.query_external_address()
	if external_ip:
		print("External IP via UPnP:", external_ip)
	else:
		print("Failed to get external IP via UPnP, trying fallback...")
		external_ip = await _get_external_ip_fallback()
		if external_ip:
			print("External IP (fallback):", external_ip)
		else:
			print("Failed to get external IP")
			_show_warning("Failed to get external IP. Players cannot connect.")
			return

	# Запускаем WebSocket-сервер
	var error = _server.listen(3001)
	if error != OK:
		print("Failed to start WebSocket server, error:", error)
		_show_warning("Failed to start WebSocket server. Try restarting the game.")
		return
	add_child(_server)
	_server.client_connected.connect(_on_client_connected)
	_server.message_received.connect(_on_data)
	print("WebSocket Server started on ws://%s:3001" % external_ip)

	# Генерируем session_id и ссылку
	session_id = _generate_session_id()
	#var join_link = "http://" + external_ip + ":8080/" + session_id
	var join_link = "https://bit.ly/mempack/" + session_id
	print("Join link:", join_link)
	# Отображаем ссылку в интерфейсе
	var link_label = Label.new()
	link_label.text = "Share this link: " + join_link
	link_label.position = Vector2(10, 50)
	add_child(link_label)

	# Копируем ссылку в буфер обмена
	DisplayServer.clipboard_set(join_link)
	print("Link copied to clipboard")

func _get_external_ip_fallback() -> String:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var services = [
		"https://api.ipify.org?format=json",
		"https://ifconfig.me/ip",
		"https://api.myip.com",
		"https://ipapi.co/json/"
	]
	var ip = ""
	
	for url in services:
		var error = http_request.request(url)
		if error != OK:
			print("Failed to request IP from", url, "Error:", error)
			continue
		
		var result = await http_request.request_completed
		if result[0] == HTTPRequest.RESULT_SUCCESS:
			var response_body = result[3].get_string_from_utf8()
			var json_parser = JSON.new()
			var parse_error = json_parser.parse(response_body)
			if parse_error == OK:
				var response = json_parser.get_data()
				if url.begins_with("https://api.ipify.org"):
					if response.has("ip"):
						ip = response.ip
						break
				elif url.begins_with("https://api.myip.com"):
					if response.has("ip"):
						ip = response.ip
						break
				elif url.begins_with("https://ipapi.co"):
					if response.has("ip"):
						ip = response.ip
						break
				else:
					ip = response_body.strip_edges()
					break
			else:
				print("JSON parse error for", url, ":", json_parser.get_error_message())
		else:
			print("HTTP request failed for", url, "Status:", result[0])
	
	http_request.queue_free()
	return ip

func _generate_session_id() -> String:
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

func _on_client_connected(id: int):
	print("Client connected with ID:", id)
	if _server.peers.has(id):
		print("Peer found for client:", id)
	else:
		print("Peer not found for client:", id)

func _on_data(id: int, message: Variant):
	print("Data received from client:", id)
	if not _server.peers.has(id):
		print("Peer not found for client:", id)
		return
	
	var peer = _server.peers[id]
	
	if typeof(message) == TYPE_STRING:
		var data = message
		if data.strip_edges() == "":
			print("Received empty data from client", id)
			return
		
		var error = json.parse(data)
		if error == OK:
			var msg = json.get_data()
			print("Parsed message from client", id, ":", msg)
			_handle_message(id, msg)
		else:
			print("JSON parse error from client", id, ":", json.get_error_message())
	else:
		print("Unsupported message type from client", id)

func _handle_message(id: int, msg: Dictionary):
	print("Handling message:", msg)
	var room = msg.get("room", session_id)
	var name = msg.get("name", "Anonymous")
	var text = msg.get("text", "")
	
	match msg.get("type"):
		"join":
			if not rooms.has(room):
				rooms[room] = []
			if id not in rooms[room]:
				rooms[room].append(id)
			_broadcast(room, {"type": "system", "text": name + " joined"})
			print("[Join] Client", id, "joined room", room)
		
		"chat":
			_broadcast(room, {"type": "message", "name": name, "text": text})
			print("[Chat] Message from", name, ":", text)

func _broadcast(room: String, data: Dictionary):
	if rooms.has(room):
		var payload = json.stringify(data) + "\n"
		print("Broadcasting:", payload)
		for client_id in rooms[room]:
			if _server.peers.has(client_id):
				var peer = _server.peers[client_id]
				if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
					var error = peer.send_text(payload)
					if error != OK:
						print("Failed to send to client", client_id, ":", error)
				else:
					print("Peer", client_id, "is not connected")
			else:
				print("Peer not found for client:", client_id)

func _process(delta):
	_server.poll()
