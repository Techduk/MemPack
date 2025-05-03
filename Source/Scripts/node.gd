extends Node

var socket = WebSocketPeer.new()
var last_state = WebSocketPeer.STATE_CLOSED

const roomName = "Tea"
const userName = "Godot"
const SERVER_URL = "ws://localhost:3001/chat/%s" % roomName  # Добавляем endpoint

signal connected_to_server()
signal connection_closed()
signal message_received(message: Variant)

@onready var textEdit = $Button/TextEdit

func _ready():
	# Устанавливаем необходимые заголовки
	socket.handshake_headers = PackedStringArray([
		"Upgrade: websocket",
		"Connection: Upgrade"
	])
	
	var error = socket.connect_to_url(SERVER_URL)
	if error != OK:
		print("Connection error: ", error)
	
	connect("connected_to_server", _on_connected_to_server)
	connect("connection_closed", _connection_closed)
	connect("message_received", _on_message_received)

func _process(delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	if state != last_state:
		last_state = state
		match state:
			WebSocketPeer.STATE_OPEN:
				connected_to_server.emit()
			WebSocketPeer.STATE_CLOSED:
				connection_closed.emit()
	
	while socket.get_ready_state() == WebSocketPeer.STATE_OPEN and socket.get_available_packet_count():
		var message = socket.get_packet().get_string_from_utf8()
		message_received.emit(message)

func send_message(data: Dictionary):
	var payload = JSON.stringify(data)
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(payload)

func _on_connected_to_server():
	var data = { 
		"type": "join", 
		"name": userName,
		"room": roomName
	}
	send_message(data)

func _on_message_received(message: String):
	print("Received message: ", message)

func _connection_closed():
	print("Connection closed")

func _on_button_pressed():
	var data = { 
		"type": "chat", 
		"text": textEdit.text,
		"room": roomName,
		"name": userName
	}
	send_message(data)
