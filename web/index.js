const express = require("express");
const WebSocket = require("ws");
const app = express();
const server = require("http").createServer(app);
const wss = new WebSocket.Server({ server });

// Хранилище комнат: { roomCode: { host: WebSocket, players: { ws: WebSocket, name: String, id: String, lastPing: Number }[] } }
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

// Генерация уникального ID
function generateUniqueId() {
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(
        /[xy]/g,
        function (c) {
            const r = (Math.random() * 16) | 0,
                v = c === "x" ? r : (r & 0x3) | 0x8;
            return v.toString(16);
        },
    );
}

// Проверка пинга
function checkPings() {
    for (let roomCode in rooms) {
        const room = rooms[roomCode];
        const now = Date.now();
        room.players = room.players.filter((player) => {
            if (now - player.lastPing > 30000) {
                // 30 секунд
                if (player.ws.readyState === WebSocket.OPEN) {
                    player.ws.close();
                }
                broadcast(roomCode, {
                    type: "system",
                    text: `${player.name} disconnected due to inactivity`,
                });
                console.log(`${player.name} disconnected due to inactivity`);
                return false;
            }
            return true;
        });
        // Проверка хоста
        if (room.host && now - (room.host.lastPing || 0) > 30000) {
            if (room.host.readyState === WebSocket.OPEN) {
                room.host.close();
            }
            broadcast(roomCode, {
                type: "system",
                text: "Host disconnected due to inactivity",
            });
            console.log(
                `Host disconnected due to inactivity in room ${roomCode}`,
            );
            delete rooms[roomCode];
        }
    }
}
setInterval(checkPings, 30000); // Проверка каждые 30 секунд

// Главная страница с формой
app.get("/", (req, res) => {
    const roomCode = req.query.roomCode || "";
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
                let playerId = localStorage.getItem('playerId');
                if (!playerId) {
                    playerId = "${generateUniqueId()}";
                    localStorage.setItem('playerId', playerId);
                }

                function joinChat(event) {
                    event.preventDefault();
                    const roomCode = document.getElementById('roomCode').value.trim();
                    const nickname = document.getElementById('nickname').value.trim();
                    const roomCodeError = document.getElementById('roomCodeError');
                    const nicknameError = document.getElementById('nicknameError');

                    roomCodeError.style.display = 'none';
                    nicknameError.style.display = 'none';

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
                        window.location.href = '/join/' + roomCode + '?id=' + playerId;
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
    const playerId = req.query.id || generateUniqueId();
    console.log(
        `Serving chat page for room: ${roomCode}, playerId: ${playerId}`,
    );
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
                .disconnected { opacity: 0.5; }
            </style>
            <script>
                let username = localStorage.getItem('nickname') || 'Unknown';
                let playerId = "${playerId}";
                console.log("Username initialized: " + username + ", playerId: " + playerId);
                let ws = new WebSocket("wss://" + window.location.host + "/ws/${roomCode}");

                if (!username || username === 'Unknown') {
                    window.location.href = '/?roomCode=${roomCode}';
                }

                function reconnect() {
                    if (ws.readyState === WebSocket.CLOSED) {
                        console.log("Attempting to reconnect...");
                        ws = new WebSocket("wss://" + window.location.host + "/ws/${roomCode}");
                        setupWebSocket();
                    }
                }

                function setupWebSocket() {
                    ws.onopen = () => {
                        console.log("WebSocket connected");
                        ws.send(JSON.stringify({ 
                            type: "join", 
                            room: "${roomCode}", 
                            name: username,
                            id: playerId
                        }));
                    };

                    ws.onmessage = (e) => {
                        console.log("Received:", e.data);
                        try {
                            const data = JSON.parse(e.data);
                            if (data.type === "ping") {
                                ws.send(JSON.stringify({ type: "pong", id: playerId }));
                                console.log("Sent pong with playerId: " + playerId);
                            } else {
                                const chat = document.getElementById('chat');
                                chat.innerHTML += \`<p><b>\${data.name || 'Unknown'}:</b> \${data.text}</p>\`;
                                chat.scrollTop = chat.scrollHeight;
                            }
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
                        setTimeout(reconnect, 2000); // Переподключение каждые 2 секунды
                    };
                }

                setupWebSocket();

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
                            id: playerId,
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

    const roomCode = req.url.slice(4); // Удаляем "/ws/"
    console.log(`WebSocket connection for room: ${roomCode}`);

    ws.on("message", (message) => {
        try {
            const data = JSON.parse(message);
            console.log("Received:", data);

            if (data.type === "create") {
                if (!rooms[roomCode]) {
                    rooms[roomCode] = { host: ws, players: [] };
                    ws.lastPing = Date.now(); // Инициализируем lastPing для хоста
                    ws.id = data.id; // Сохраняем ID хоста
                    console.log(
                        `Room ${roomCode} created by host with id: ${data.id}`,
                    );
                    ws.send(
                        JSON.stringify({
                            type: "room_created",
                            roomCode,
                            link: `https://${req.headers.host}/join/${roomCode}`,
                        }),
                    );
                    // Запуск пинга для хоста
                    const pingInterval = setInterval(() => {
                        if (ws.readyState === WebSocket.OPEN) {
                            ws.send(
                                JSON.stringify({ type: "ping", id: data.id }),
                            );
                            console.log(
                                `Sent ping to host with id ${data.id} in room ${roomCode} at ${new Date().toISOString()}`,
                            );
                        }
                    }, 30000); // Пинг каждые 30 секунд
                    ws.on("close", () => {
                        clearInterval(pingInterval);
                        console.log(
                            `Stopped ping for host in room ${roomCode}`,
                        );
                    });
                } else {
                    ws.send(
                        JSON.stringify({
                            type: "error",
                            text: "Room already exists",
                        }),
                    );
                }
            } else if (data.type === "restore") {
                if (rooms[roomCode] && data.room === roomCode && data.state) {
                    console.log(
                        `Restoring room ${roomCode} with state:`,
                        data.state,
                    );
                    const existingPlayer = rooms[roomCode].players.find(
                        (p) => p.id === data.id,
                    );
                    if (existingPlayer) {
                        existingPlayer.ws = ws;
                        existingPlayer.lastPing = Date.now();
                    } else {
                        rooms[roomCode].players.push({
                            ws: ws,
                            name: data.state[0].name,
                            id: data.id,
                            lastPing: Date.now(),
                        });
                    }
                    broadcast(roomCode, {
                        type: "restore",
                        state: data.state,
                    });
                } else {
                    console.log(
                        "Restore failed: Room not found or state missing",
                    );
                }
            } else if (data.type === "join") {
                if (rooms[roomCode]) {
                    const existingPlayer = rooms[roomCode].players.find(
                        (p) => p.id === data.id,
                    );
                    if (!existingPlayer) {
                        rooms[roomCode].players.push({
                            ws: ws,
                            name: data.name,
                            id: data.id,
                            lastPing: Date.now(),
                        });
                        broadcast(roomCode, {
                            type: "system",
                            text: `${data.name || "Anonymous"} joined`,
                        });
                        console.log(
                            `Player ${data.name || "Anonymous"} joined room ${roomCode}`,
                        );
                    } else {
                        existingPlayer.ws = ws;
                        existingPlayer.lastPing = Date.now();
                        broadcast(roomCode, {
                            type: "system",
                            text: `${data.name} reconnected`,
                        });
                    }
                    // Запуск пинга для нового игрока
                    const pingInterval = setInterval(() => {
                        if (ws.readyState === WebSocket.OPEN) {
                            ws.send(
                                JSON.stringify({ type: "ping", id: data.id }),
                            );
                            console.log(
                                `Sent ping to player ${data.name} in room ${roomCode} at ${new Date().toISOString()}`,
                            );
                        }
                    }, 30000); // Пинг каждые 30 секунд
                    ws.on("close", () => {
                        clearInterval(pingInterval);
                        console.log(
                            `Stopped ping for player in room ${roomCode}`,
                        );
                    });
                } else {
                    ws.send(
                        JSON.stringify({
                            type: "error",
                            text: "Room does not exist",
                        }),
                    );
                }
            } else if (data.type === "chat") {
                broadcast(roomCode, {
                    type: "message",
                    name: data.name,
                    text: data.text,
                });
            } else if (data.type === "pong") {
                const player = rooms[roomCode]?.players.find(
                    (p) => p.id === data.id,
                );
                if (player) {
                    player.lastPing = Date.now();
                    console.log(
                        `Received pong from player ${player.name} in room ${roomCode}`,
                    );
                } else if (
                    rooms[roomCode]?.host &&
                    rooms[roomCode].host.id === data.id
                ) {
                    rooms[roomCode].host.lastPing = Date.now();
                    console.log(
                        `Received pong from host with id ${data.id} in room ${roomCode}`,
                    );
                } else {
                    console.log(
                        `Received pong from unknown client with id ${data.id} in room ${roomCode}`,
                    );
                }
            }
        } catch (err) {
            console.error("Message parse error:", err);
            ws.send(
                JSON.stringify({
                    type: "error",
                    text: "Invalid message format",
                }),
            );
        }
    });

    ws.on("close", () => {
        if (rooms[roomCode]) {
            if (rooms[roomCode].host === ws) {
                broadcast(roomCode, {
                    type: "system",
                    text: "Host disconnected",
                });
                rooms[roomCode].players.forEach((player) => player.ws.close());
                delete rooms[roomCode];
                console.log(`Room ${roomCode} closed`);
            } else {
                const player = rooms[roomCode].players.find((p) => p.ws === ws);
                if (player) {
                    rooms[roomCode].players = rooms[roomCode].players.filter(
                        (p) => p.ws !== ws,
                    );
                    broadcast(roomCode, {
                        type: "system",
                        text: `${player.name} disconnected`,
                    });
                    console.log(`${player.name} left room ${roomCode}`);
                }
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
            if (player.ws.readyState === WebSocket.OPEN) {
                player.ws.send(payload);
            }
        });
    }
}

// Запуск сервера
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
