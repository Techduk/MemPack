extends Node

const PACK_DIR = "user://packs/"

func export_pack(pack_name: String, source_dir: String):
	print("Экспорт пака: ", pack_name)
	var manifest = {
		"name": pack_name,
		"version": "1.0",
		"entry_scene": "Main.tscn",
		"pack_code": "NaN",
		"thumbnail": "thumbnail.png",
		"assets": [],
		"asset_offsets": {}
	}
	
	# Шаг 1: Собираем данные файлов
	var dir = DirAccess.open(source_dir)
	if not dir:
		print("Ошибка: не удалось открыть директорию ", source_dir)
		return false
	
	var asset_data = {}
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn") or file_name.ends_with(".png") or file_name.ends_with(".wav"):
			var file_path = source_dir + "/" + file_name
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var data = file.get_buffer(file.get_length())
				if data.size() == 0:
					print("Ошибка: файл ", file_name, " пуст")
					file.close()
					return false
				asset_data[file_name] = data
				manifest["assets"].append(file_name)
				print("Добавлен файл: ", file_name, ", размер: ", data.size())
				if file_name.ends_with(".png") and data.size() >= 4:
					print("Первые 4 байта ", file_name, ": ", [data[0], data[1], data[2], data[3]])
					if data[0] != 137 or data[1] != 80 or data[2] != 78 or data[3] != 71:
						print("Ошибка: файл ", file_name, " не является валидным PNG")
						file.close()
						return false
				file.close()
			else:
				print("Ошибка открытия файла: ", file_path)
				return false
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if asset_data.size() == 0:
		print("Ошибка: не найдено ни одного ассета в директории ", source_dir)
		return false
	
	# Шаг 2: Формируем буфер
	var pack_buffer = PackedByteArray()
	
	# Записываем манифест с заглушками
	for asset in manifest["assets"]:
		manifest["asset_offsets"][asset] = {"offset": 0, "size": asset_data[asset].size()}
	
	print("Составление манифеста")
	var manifest_data = JSON.stringify(manifest).to_utf8_buffer()
	var manifest_size = manifest_data.size()
	print("Размер манифеста: ", manifest_size)
	
	var size_bytes = PackedByteArray()
	size_bytes.resize(4)
	size_bytes[0] = manifest_size & 0xFF
	size_bytes[1] = (manifest_size >> 8) & 0xFF
	size_bytes[2] = (manifest_size >> 16) & 0xFF
	size_bytes[3] = (manifest_size >> 24) & 0xFF
	print("Байты размера манифеста: ", size_bytes)
	
	pack_buffer.append_array(size_bytes)
	pack_buffer.append_array(manifest_data)
	print("Манифест записан в буфер, текущий размер буфера: ", pack_buffer.size())
	
	# Шаг 3: Записываем данные ассетов и обновляем оффсеты
	for asset in manifest["assets"]:
		var offset = pack_buffer.size()
		var data = asset_data[asset]
		pack_buffer.append_array(data)
		manifest["asset_offsets"][asset]["offset"] = offset
		print("Ассет записан: ", asset, ", offset: ", offset, ", размер: ", data.size())
		if asset.ends_with(".png") and data.size() >= 4:
			print("Первые 4 байта ", asset, " в буфере: ", [pack_buffer[offset], pack_buffer[offset + 1], pack_buffer[offset + 2], pack_buffer[offset + 3]])
	
	# Шаг 4: Перезаписываем манифест с обновлёнными оффсетами
	print("Обновление манифеста с новыми оффсетами")
	manifest_data = JSON.stringify(manifest).to_utf8_buffer()
	manifest_size = manifest_data.size()
	print("Новый размер манифеста: ", manifest_size)
	
	size_bytes[0] = manifest_size & 0xFF
	size_bytes[1] = (manifest_size >> 8) & 0xFF
	size_bytes[2] = (manifest_size >> 16) & 0xFF
	size_bytes[3] = (manifest_size >> 24) & 0xFF
	print("Обновлённые байты размера манифеста: ", size_bytes)
	
	# Перезаписываем начало буфера
	for i in range(4):
		pack_buffer[i] = size_bytes[i]
	for i in range(manifest_size):
		if i < manifest_data.size():
			pack_buffer[4 + i] = manifest_data[i]
	
	# Шаг 5: Проверяем манифест
	print("Проверка манифеста перед сохранением")
	if manifest["asset_offsets"].size() != manifest["assets"].size():
		print("Ошибка: несоответствие в манифесте. Ожидалось ", manifest["assets"].size(), " ассетов, найдено ", manifest["asset_offsets"].size(), " оффсетов")
		return false
	
	for asset in manifest["assets"]:
		if not asset in manifest["asset_offsets"]:
			print("Ошибка: ассет ", asset, " отсутствует в asset_offsets")
			return false
		var offset_data = manifest["asset_offsets"][asset]
		if not "offset" in offset_data or not "size" in offset_data:
			print("Ошибка: некорректные данные оффсета для ассета ", asset)
			return false
		if offset_data["size"] != asset_data[asset].size():
			print("Ошибка: размер ассета ", asset, " в манифесте (", offset_data["size"], ") не совпадает с реальным (", asset_data[asset].size(), ")")
			return false
	
	# Шаг 6: Выводим буфер для отладки
	print("Финальный буфер (первые 500 байт): ", pack_buffer.slice(0, 500) if pack_buffer.size() > 500 else pack_buffer)
	
	# Шаг 7: Сохраняем пак
	var dir_access = DirAccess.open("user://")
	if dir_access:
		var err = dir_access.make_dir_recursive("packs")
		if err != OK:
			print("Ошибка создания директории ", PACK_DIR, ": ", err)
			return false
	else:
		print("Ошибка: не удалось открыть user://")
		return false
	
	var pack_path = PACK_DIR + pack_name + ".mempack"
	var file = FileAccess.open(pack_path, FileAccess.WRITE)
	if file:
		file.store_buffer(pack_buffer)
		file.close()
		print("Пак сохранён: ", pack_path, ", размер: ", pack_buffer.size())
	else:
		print("Ошибка: не удалось сохранить файл ", pack_path)
		return false
	
	# Шаг 8: Проверяем сохранённый пак
	print("Проверка сохранённого пака: ", pack_path)
	file = FileAccess.open(pack_path, FileAccess.READ)
	if not file:
		print("Ошибка: не удалось открыть сохранённый пак для проверки")
		return false
	
	var saved_buffer = file.get_buffer(file.get_length())
	file.close()
	
	if saved_buffer.size() != pack_buffer.size():
		print("Ошибка: размер сохранённого пака (", saved_buffer.size(), ") не совпадает с ожидаемым (", pack_buffer.size(), ")")
		return false
	
	var saved_manifest_size = (saved_buffer[3] << 24) | (saved_buffer[2] << 16) | (saved_buffer[1] << 8) | saved_buffer[0]
	if saved_manifest_size != manifest_size:
		print("Ошибка: размер манифеста в сохранённом паке (", saved_manifest_size, ") не совпадает с ожидаемым (", manifest_size, ")")
		return false
	
	var saved_manifest_data = saved_buffer.slice(4, 4 + saved_manifest_size)
	var saved_manifest = JSON.parse_string(saved_manifest_data.get_string_from_utf8())
	if not saved_manifest:
		print("Ошибка: не удалось разобрать манифест из сохранённого пака")
		return false
	
	if saved_manifest["asset_offsets"].size() != manifest["assets"].size():
		print("Ошибка: в сохранённом манифесте несоответствие количества оффсетов (", saved_manifest["asset_offsets"].size(), ") и ассетов (", manifest["assets"].size(), ")")
		return false
	
	for asset in saved_manifest["assets"]:
		if not asset in saved_manifest["asset_offsets"]:
			print("Ошибка: в сохранённом манифесте отсутствует оффсет для ассета ", asset)
			return false
		var offset_data = saved_manifest["asset_offsets"][asset]
		var offset = offset_data["offset"]
		var size = offset_data["size"]
		var asset_bytes = saved_buffer.slice(offset, offset + size)
		if asset_bytes.size() != size:
			print("Ошибка: размер извлечённого ассета ", asset, " (", asset_bytes.size(), ") не совпадает с ожидаемым (", size, ")")
			return false
		if asset.ends_with(".png") and asset_bytes.size() >= 4:
			print("Проверка ", asset, " в сохранённом паке: первые 4 байта: ", [asset_bytes[0], asset_bytes[1], asset_bytes[2], asset_bytes[3]])
			if asset_bytes[0] != 137 or asset_bytes[1] != 80 or asset_bytes[2] != 78 or asset_bytes[3] != 71:
				print("Ошибка: в сохранённом паке ассет ", asset, " не является валидным PNG")
				return false
	
	print("Пак успешно прошёл проверку")
	return true
