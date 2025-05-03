const express = require('express');
const WebSocket = require('ws');
const app = express();
const server = require('http').createServer(app);
const wss = new WebSocket.Server({ server });

// Хранилище комнат: { roomCode: { host: WebSocket, players: WebSocket[] } }
const rooms = {};

// Генерация кода комнаты
function generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
}

// Раздача HTML-страницы
app.get('/join/:roomCode', (req, res) => {
    const roomCode = req.params.roomCode;
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Game Chat</title>
            <script>
                let username = "User" + Math.floor(Math.random() * 1000);
                console.log("Username initialized: " + username);
                const ws = new WebSocket("wss://" + window.location.host + "/ws/${roomCode}");

                ws.onopen = () => {
                    console.log("WebSocket connected");
                    ws.send(JSON.stringify({ 
                        type: "join", 
                        room: "${roomCode}", 
                        name: username 
                    }));
                };

                ws.onmessage = (e) => {
                    console.log("Received:", e.data);
                    try {
                        const data = JSON.parse(e.data);
                        const chat = document.getElementById('chat');
                        chat.innerHTML += \`<p><b>\${data.name || 'Unknown'}:</b> \${data.text}</p>\`;
                        chat.scrollTop = chat.scrollHeight;
                    } catch (err) {
                        console.error("Failed to parse message:", err);
                    }
                };

                ws.onerror = (error) => {
                    console.error("WebSocket Error:", error);
                    const chat = document.getElementById('chat');
                    chat.innerHTML += \`<p style="color: red;">Error: Could not connect to server</p>\`;
                };

                ws.onclose = (e) => {
                    console.log("WebSocket closed:", e.reason);
                    const chat = document.getElementById('chat');
                    chat.innerHTML += \`<p style="color: red;">Disconnected from server</p>\`;
                };

                window.sendMessage = function() {
                    const input = document.getElementById('message');
                    const text = input.value.trim();
                    if (text && ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify({
                            type: "chat",
                            text: text,
                            name: username,
                            room: "${roomCode}"
                        }));
                        input.value = '';
                    } else {
                        console.error("WebSocket is not connected");
                        const chat = document.getElementById('chat');
                        chat.innerHTML += \`<p style="color: red;">Error: Not connected to server</p>\`;
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
    `);
});

// Обработка WebSocket-соединений
wss.on('connection', (ws, req) => {
    console.log('New WebSocket connection');
    
    // Извлекаем roomCode из пути (например, /ws/mQ73Z7)
    const roomCode = req.url.slice(4); // Удаляем "/ws/"

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            console.log('Received:', data);

            if (data.type === 'create') {
                // Хост создаёт комнату
                if (!rooms[roomCode]) {
                    rooms[roomCode] = { host: ws, players: [] };
                    console.log(`Room ${roomCode} created`);
                    ws.send(JSON.stringify({ 
                        type: 'room_created', 
                        roomCode, 
                        link: `https://${req.headers.host}/join/${roomCode}` 
                    }));
                } else {
                    ws.send(JSON.stringify({ type: 'error', text: 'Room already exists' }));
                }
            } else if (data.type === 'join') {
                // Игрок присоединяется
                if (rooms[roomCode]) {
                    rooms[roomCode].players.push(ws);
                    broadcast(roomCode, { type: 'system', text: `${data.name || 'Anonymous'} joined` });
                    console.log(`Player joined room ${roomCode}`);
                } else {
                    ws.send(JSON.stringify({ type: 'error', text: 'Room does not exist' }));
                }
            } else if (data.type === 'chat') {
                // Пересылка сообщения чата
                broadcast(roomCode, { type: 'message', name: data.name, text: data.text });
            }
        } catch (err) {
            console.error('Message parse error:', err);
        }
    });

    ws.on('close', () => {
        // Удаляем игрока или хоста при отключении
        if (rooms[roomCode]) {
            if (rooms[roomCode].host === ws) {
                // Хост отключился, закрываем комнату
                broadcast(roomCode, { type: 'system', text: 'Host disconnected' });
                rooms[roomCode].players.forEach(player => player.close());
                delete rooms[roomCode];
                console.log(`Room ${roomCode} closed`);
            } else {
                // Игрок отключился
                rooms[roomCode].players = rooms[roomCode].players.filter(p => p !== ws);
                broadcast(roomCode, { type: 'system', text: 'Player disconnected' });
                console.log(`Player left room ${roomCode}`);
            }
        }
    });
});

// Трансляция сообщения всем в комнате
function broadcast(roomCode, data) {
    if (rooms[roomCode]) {
        const payload = JSON.stringify(data);
        if (rooms[roomCode].host.readyState === WebSocket.OPEN) {
            rooms[roomCode].host.send(payload);
        }
        rooms[roomCode].players.forEach(player => {
            if (player.readyState === WebSocket.OPEN) {
                player.send(payload);
            }
        });
    }
}

// Запуск сервера
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});