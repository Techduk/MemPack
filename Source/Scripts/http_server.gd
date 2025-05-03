extends Node

var tcp_server = TCPServer.new()
const PORT = 8080
var external_ip: String

func _ready():
	# Получаем внешний IP
	external_ip = await _get_external_ip()
	if external_ip:
		print("HTTP Server: External IP:", external_ip)
	else:
		print("HTTP Server: Failed to get external IP")
		_show_warning("Failed to get external IP. Players cannot connect.")
		return

	tcp_server.listen(PORT)
	print("HTTP Server started on http://%s:%d" % [external_ip, PORT])

func _get_external_ip() -> String:
	var upnp = UPNP.new()
	var discover_result = upnp.discover(2000, 2, "InternetGatewayDevice")
	var ip = ""
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		ip = upnp.query_external_address()
		if ip:
			return ip
	
	# Запасной вариант
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var services = [
		"https://api.ipify.org?format=json",
		"https://ifconfig.me/ip",
		"https://api.myip.com",
		"https://ipapi.co/json/"
	]
	
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

func _show_warning(message: String):
	var warning_label = Label.new()
	warning_label.text = message
	warning_label.position = Vector2(10, 10)
	warning_label.modulate = Color.RED
	add_child(warning_label)

func _process(delta):
	if tcp_server.is_connection_available():
		var client = tcp_server.take_connection()
		_handle_request(client)

func _handle_request(client: StreamPeerTCP):
	var request = ""
	var max_attempts = 100
	var attempts = 0
	
	while client.get_available_bytes() > 0 or attempts < max_attempts:
		var chunk = client.get_utf8_string(client.get_available_bytes())
		request += chunk
		if request.contains("\r\n\r\n"):
			break
		attempts += 1
		OS.delay_msec(10)
	
	print("Received request:\n", request)
	
	var response = ""
	if request.begins_with("OPTIONS"):
		response = (
			"HTTP/1.1 204 No Content\r\n" +
			"Access-Control-Allow-Origin: *\r\n" +
			"Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
			"Access-Control-Allow-Headers: Content-Type\r\n" +
			"Connection: close\r\n\r\n"
		)
	elif request.begins_with("GET /favicon.ico"):
		response = (
			"HTTP/1.1 404 Not Found\r\n" +
			"Content-Type: text/plain\r\n" +
			"Access-Control-Allow-Origin: *\r\n" +
			"Connection: close\r\n\r\n" +
			"Not Found"
		)
	else:
		# Извлекаем session_id из запроса
		var session_id = ""
		if request.contains("/"):
			var parts = request.split(" ")[1].split("/")
			if parts.size() > 1:
				session_id = parts[1]
		response = (
			"HTTP/1.1 200 OK\r\n" +
			"Content-Type: text/html; charset=utf-8\r\n" +
			"Access-Control-Allow-Origin: *\r\n" +
			"Connection: close\r\n\r\n" +
			_get_html(session_id)
		)
	
	client.put_data(response.to_utf8_buffer())
	client.disconnect_from_host()

func _get_html(session_id: String) -> String:
	return """
	<!DOCTYPE html>
	<html>
	<head>
		<meta charset="UTF-8">
		<title>Chat</title>
		<script>
			let username = "User" + Math.floor(Math.random() * 1000);
			console.log("Username initialized: " + username);
			const ws = new WebSocket("ws://%s:3001");

			ws.onopen = () => {
				console.log("WebSocket connected");
				if (!username) {
					username = "User" + Math.floor(Math.random() * 1000);
					console.warn("Username was undefined, reinitialized: " + username);
				}
				ws.send(JSON.stringify({ 
					type: "join", 
					room: "%s", 
					name: username 
				}));
			};

			ws.onmessage = (e) => {
				console.log("Received:", e.data);
				try {
					const data = JSON.parse(e.data);
					const chat = document.getElementById('chat');
					chat.innerHTML += `<p><b>${data.name || 'Unknown'}:</b> ${data.text}</p>`;
					chat.scrollTop = chat.scrollHeight;
				} catch (err) {
					console.error("Failed to parse message:", err);
				}
			};

			ws.onerror = (error) => {
				console.error("WebSocket Error:", error);
				const chat = document.getElementById('chat');
				chat.innerHTML += `<p style="color: red;">Error: Could not connect to server</p>`;
			};

			ws.onclose = (e) => {
				console.log("WebSocket closed:", e.reason);
				const chat = document.getElementById('chat');
				chat.innerHTML += `<p style="color: red;">Disconnected from server</p>`;
			};

			window.sendMessage = function() {
				const input = document.getElementById('message');
				const text = input.value.trim();
				if (text && ws.readyState === WebSocket.OPEN) {
					if (!username) {
						username = "User" + Math.floor(Math.random() * 1000);
						console.warn("Username was undefined, reinitialized: " + username);
					}
					console.log("Sending:", text);
					ws.send(JSON.stringify({
						type: "chat",
						text: text,
						name: username,
						room: "%s"
					}));
					input.value = '';
				} else if (ws.readyState !== WebSocket.OPEN) {
					console.error("WebSocket is not connected");
					const chat = document.getElementById('chat');
					chat.innerHTML += `<p style="color: red;">Error: Not connected to server</p>`;
				}
			};
		</script>
	</head>
	<body>
		<div id="chat" style="height: 300px; overflow-y: auto; border: 1px solid #ccc;"></div>
		<input type="text" id="message" placeholder="Type message...">
		<button onclick="sendMessage()">Send</button>
	</body>
	</html>
	""" % [external_ip, session_id, session_id]
