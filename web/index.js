const express = require("express");
const WebSocket = require("ws");
const app = express();
const server = require("http").createServer(app);
const wss = new WebSocket.Server({ server });

// Хранилище комнат: { roomCode: { host: WebSocket, players: WebSocket[] } }
const rooms = {};

// Генерация кода комнаты
function generateRoomCode() {
    const chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    let code = "";
    for (let i = 0; i < 6; i++) {
        code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
}

// Главная страница с формой
app.get("/", (req, res) => {
    const roomCode = req.query.roomCode || ""; // Получаем roomCode из URL-параметра
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Game Chat Server</title>
            <style>
                body { font-family: Arial, sans-serif; background-color: #fffacd; padding: 20px; }
                .form-container { max-width: 400px; margin: 0 auto; padding: 20px; background: #fff; border-radius: 5px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
                input, button { width: 100%; padding: 10px; margin: 10px 0; box-sizing: border-box; }
                button { background-color: #4CAF50; color: white; border: none; cursor: pointer; }
                button:hover { background-color: #45a049; }
                .error { color: red; display: none; }
            </style>
        </head>
        <body>
            <div class="form-container">
                <h1>Game Chat Server</h1>
                <p>Enter room code and nickname to join the chat.</p>
                <form id="joinForm" onsubmit="joinChat(event)">
                    <input type="text" id="roomCode" value="${roomCode}" placeholder="Room Code (e.g., JFPr06)" maxlength="6" required>
                    <div id="roomCodeError" class="error">Room code must be 6 characters long.</div>
                    <input type="text" id="nickname" placeholder="Nickname" maxlength="9" required>
                    <div id="nicknameError" class="error">Nickname must be 1-9 characters long.</div>
                    <button type="submit">Join Chat</button>
                </form>
            </div>
            <script>
                function joinChat(event) {
                    event.preventDefault();
                    const roomCode = document.getElementById('roomCode').value.trim();
                    const nickname = document.getElementById('nickname').value.trim();
                    const roomCodeError = document.getElementById('roomCodeError');
                    const nicknameError = document.getElementById('nicknameError');

                    // Сброс ошибок
                    roomCodeError.style.display = 'none';
                    nicknameError.style.display = 'none';

                    // Валидация
                    let isValid = true;
                    if (roomCode.length !== 6) {
                        roomCodeError.style.display = 'block';
                        isValid = false;
                    }
                    if (nickname.length === 0 || nickname.length > 9) {
                        nicknameError.style.display = 'block';
                        isValid = false;
                    }

                    if (isValid) {
                        localStorage.setItem('nickname', nickname);
                        window.location.href = '/join/' + roomCode;
                    }
                }
            </script>
        </body>
        </html>
    `);
    console.log("Served root page with form");
});

// Раздача HTML-страницы для чата
app.get("/join/:roomCode", (req, res) => {
    const roomCode = req.params.roomCode;
    console.log(`Serving chat page for room: ${roomCode}`);
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Game Chat - Room ${roomCode}</title>
            <style>
                body { font-family: Arial, sans-serif; padding: 20px; background-color: #fffacd; }
                #chat { height: 300px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background: #fff; }
                input { width: 70%; padding: 10px; margin: 10px 0; box-sizing: border-box; }
                button { padding: 10px; background-color: #4CAF50; color: white; border: none; cursor: pointer; }
                button:hover { background-color: #45a049; }
            </style>
            <script>
                let username = localStorage.getItem('nickname') || 'Unknown';
                console.log("Username initialized: " + username);
                const ws = new WebSocket("wss://" + window.location.host + "/ws/${roomCode}");

                // Проверка ника и перенаправление, если его нет
                if (!username || username === 'Unknown') {
                    window.location.href = '/?roomCode=${roomCode}';
                }

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
                    if (text.length > 999) {
                        const chat = document.getElementById('chat');
                        chat.innerHTML += \`<p style="color: red;">Error: Message cannot exceed 999 characters.</p>\`;
                        chat.scrollTop = chat.scrollHeight;
                        return;
                    }
                    if (text && ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify({
                            type: "chat",
                            text: text,
                            name: username,
                            room: "${roomCode}"
                        }));
                        input.value = '';
                    } else {
                        console.error("WebSocket is not connected or message is empty");
                        const chat = document.getElementById('chat');
                        chat.innerHTML += \`<p style="color: red;">Error: Not connected to server or message is empty</p>\`;
                        chat.scrollTop = chat.scrollHeight;
                    }
                };
            </script>
        </head>
        <body>
            <h1>Chat - Room ${roomCode}</h1>
            <div id="chat"></div>
            <input type="text" id="message" placeholder="Type message..." maxlength="999">
            <button onclick="sendMessage()">Send</button>
        </body>
        </html>
    `);
});

// Обработка WebSocket-соединений
wss.on("connection", (ws, req) => {
    console.log("New WebSocket connection");

    // Извлекаем roomCode из пути (например, /ws/mQ73Z7)
    const roomCode = req.url.slice(4); // Удаляем "/ws/"
    console.log(`WebSocket connection for room: ${roomCode}`);

    ws.on("message", (message) => {
        try {
            const data = JSON.parse(message);
            console.log("Received:", data);

            if (data.type === "create") {
                // Хост создаёт комнату
                if (!rooms[roomCode]) {
                    rooms[roomCode] = { host: ws, players: [] };
                    console.log(`Room ${roomCode} created`);
                    ws.send(
                        JSON.stringify({
                            type: "room_created",
                            roomCode,
                            link: `https://${req.headers.host}/join/${roomCode}`,
                        }),
                    );
                } else {
                    ws.send(
                        JSON.stringify({
                            type: "error",
                            text: "Room already exists",
                        }),
                    );
                }
            } else if (data.type === "join") {
                // Игрок присоединяется
                if (rooms[roomCode]) {
                    rooms[roomCode].players.push(ws);
                    broadcast(roomCode, {
                        type: "system",
                        text: `${data.name || "Anonymous"} joined`,
                    });
                    console.log(`Player joined room ${roomCode}`);
                } else {
                    ws.send(
                        JSON.stringify({
                            type: "error",
                            text: "Room does not exist",
                        }),
                    );
                }
            } else if (data.type === "chat") {
                // Пересылка сообщения чата
                broadcast(roomCode, {
                    type: "message",
                    name: data.name,
                    text: data.text,
                });
            }
        } catch (err) {
            console.error("Message parse error:", err);
        }
    });

    ws.on("close", () => {
        // Удаляем игрока или хоста при отключении
        if (rooms[roomCode]) {
            if (rooms[roomCode].host === ws) {
                // Хост отключился, закрываем комнату
                broadcast(roomCode, {
                    type: "system",
                    text: "Host disconnected",
                });
                rooms[roomCode].players.forEach((player) => player.close());
                delete rooms[roomCode];
                console.log(`Room ${roomCode} closed`);
            } else {
                // Игрок отключился
                rooms[roomCode].players = rooms[roomCode].players.filter(
                    (p) => p !== ws,
                );
                broadcast(roomCode, {
                    type: "system",
                    text: "Player disconnected",
                });
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
        rooms[roomCode].players.forEach((player) => {
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
