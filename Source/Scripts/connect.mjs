const ws = new WebSocket("ws://localhost:3001");
const chatDiv = document.getElementById('chat');
let playerName = "Player" + Math.floor(Math.random()*1000);

// Инициализация
ws.onopen = () => {
	console.log("Connected to server");
	ws.send(JSON.stringify({
		type: "join",
		room: "main",
		name: playerName
	}));
};

// Обработка ошибок
ws.onerror = (error) => {
	console.error("WebSocket Error:", error);
};

// Получение сообщений
ws.onmessage = (e) => {
	try {
		const data = JSON.parse(e.data);
		console.log("Received:", data);
		chatDiv.innerHTML += `<p><b>${data.name}:</b> ${data.text}</p>`;
		chatDiv.scrollTop = chatDiv.scrollHeight;
	} catch(err) {
		console.error("Parse error:", err);
	}
};

// Отправка сообщений
function sendMessage() {
	const input = document.getElementById('message');
	const text = input.value.trim();
	
	if(text) {
		ws.send(JSON.stringify({
			type: "chat",
			room: "main",
			name: playerName,
			text: text
		}));
		input.value = '';
	}
}
