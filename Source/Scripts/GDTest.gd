extends Node2D

var socket = WebSocketPeer.new()
var last_state = WebSocketPeer.STATE_CLOSED

const roomName = "Tea"
const userName = "Godot"

signal connected_to_server()
signal connection_closed()
signal message_received(message: Variant)

@onready var textEdit = $TextEdit

func poll() -> void:
	if socket.get_ready_state() != socket.STATE_CLOSED:
		socket.poll()
		
	var state = socket.get_ready_state()
	
	if last_state != state:
		last_state = state
		
		if state == socket.STATE_OPEN:
			connected_to_server.emit()
		elif state == socket.STATE_CLOSED:
			connection_closed.emit()
			
	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
		message_received.emit(get_message())
	
func send(message) -> int:
	if typeof(message) == TYPE_STRING:
		return socket.send_text(message)
	return socket.send(var_to_bytes(message))
	
func get_message() -> Variant:
	if socket.get_available_packet_count() < 1:
		return null
	
	var packet = socket.get_packet()
	if socket.was_string_packet():
		return packet.get_string_from_utf8()
		
	return bytes_to_var(packet)
	
func close(code := 1000, reason := "") -> void:
	socket.close(code,reason)
	last_state = socket.get_ready_state()
	
func get_socket() -> WebSocketPeer:
	return socket


# Called when the node enters the scene tree for the first time. (URL!)
func _ready() -> void:
	var error = socket.connect_to_url("ws://localhost:3001/chat/"+roomName)
	if error != OK:
		print(error)
		
	last_state = socket.get_ready_state()
	
	
	connect("connected_to_server", _on_connected_to_server)
	connect("connection_closed", _connectinon_closed)
	connect("message_received", _on_message_received)
	
	
	#socket.send(JSON.stringify({ type: "join", name: username }));
func _on_message_received(message: Variant) -> void:
	print("Received message:", message)
	
func _on_connected_to_server():
		var data = { "type": "join", "name": userName }
		send(JSON.stringify(data)) # Отправляем JSON-строку
	
func _connectinon_closed():
	print("Connection closed")
	
	
func _process(delta: float) -> void:
	poll()
	


func _on_button_pressed():
	var data = { "type": "chat", "text": textEdit.text }
	send(JSON.stringify(data))
