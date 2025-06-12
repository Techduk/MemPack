extends Node
var settings_opened = false

# Play button
func _on_PB_mouse_entered():
	var tween = create_tween()
	tween.tween_property($Menu/Play, "position", Vector2(43, 742), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	$Menu/Play.text = " x Play"

func _on_PB_mouse_exited():
	var tween = create_tween()
	tween.tween_property($Menu/Play, "position", Vector2(23, 742), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	$Menu/Play.text = "| Play"


# Settings button animation
func _on_SB_mouse_entered():
	var tween = create_tween()
	tween.tween_property($Menu/Settings, "position", Vector2(43, 837), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	$Menu/Settings.text = " x Settings"

func _on_SB_mouse_exited():
	var tween = create_tween()
	tween.tween_property($Menu/Settings, "position", Vector2(23, 837), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	$Menu/Settings.text = "| Settings"

func _on_settings_pressed():
	var tween = create_tween().set_parallel(true)
	if settings_opened == false:
		tween.tween_property($Settings, "position", Vector2(1280, 0), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property($Logo, "position", Vector2(105, 47), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		settings_opened = true
	else:
		tween.tween_property($Settings, "position", Vector2(1920, 0), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property($Logo, "position", Vector2(1381, 47), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		settings_opened = false

# Exit button animation
func _on_EB_mouse_entered():
	var tween = create_tween()
	tween.tween_property($Menu/Exit, "position", Vector2(43, 932), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	$Menu/Exit.text = " x Exit"

func _on_EB_mouse_exited():
	var tween = create_tween()
	tween.tween_property($Menu/Exit, "position", Vector2(23, 932), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	$Menu/Exit.text = "| Exit"
