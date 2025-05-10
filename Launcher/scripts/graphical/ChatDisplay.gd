extends Node

@onready var chat_text = $ChatText

func _ready():
	# Настраиваем TextEdit
	chat_text.editable = false  # Делаем текст только для чтения
	chat_text.scroll_fit_content_height = true
	chat_text.size = Vector2(400, 300)  # Размер области чата
	chat_text.position = Vector2(10, 100)  # Позиция ниже ссылки
	chat_text.text = "Chat started...\n"
	chat_text.visible = true  # Убеждаемся, что узел виден
	chat_text.add_theme_constant_override("margin_left", 5)
	chat_text.add_theme_constant_override("margin_right", 5)
	#chat_text.wrap_mode = TextEdit.LINE_WRAPPING_WRAP_AT_COLUMN  # Включаем перенос строк
	
	# Регистрируем себя у Server
	var server = get_node("../Server")
	if server:
		server.chat_display = self
		print("ChatDisplay registered with Server")

func add_message(message: String):
	# Добавляем новое сообщение с переносом строки
	chat_text.text += message + "\n"
	# Прокручиваем к последней строке
	#chat_text.scroll_to_line(chat_text.get_line_count() - 1)
	# Обновляем минимальный размер и перерисовываем
	chat_text.update_minimum_size()
	chat_text.queue_redraw()
	print("Message added to chat: ", message)  # Лог для отладки
