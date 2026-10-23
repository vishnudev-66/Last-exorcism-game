extends Control
## Main menu: New Game / Continue / Multiplayer (Phase 8) / Settings / Quit.
## Dark atmospheric styling with restrained red accents (design §13).

var _net_panel: VBoxContainer


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.02, 0.02)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "THE LAST EXORCISM"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.75, 0.1, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "a cooperative survival horror prototype"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_spacer(24))

	_button(box, "New Game", func(): get_tree().change_scene_to_file("res://scenes/Level1.tscn"))
	var cont := _button(box, "Continue", func():
		if SaveSystem.load_game(0):
			get_tree().change_scene_to_file("res://scenes/Level1.tscn"))
	cont.disabled = not SaveSystem.has_save(0)
	_button(box, "Multiplayer Lobby", _toggle_net)
	_button(box, "Settings", func(): PauseMenu.toggle())
	_button(box, "Quit", func(): get_tree().quit())

	_net_panel = VBoxContainer.new()
	_net_panel.visible = false
	box.add_child(_net_panel)
	var addr := LineEdit.new()
	addr.name = "Addr"
	addr.text = "127.0.0.1"
	_net_panel.add_child(addr)
	var host_b := Button.new()
	host_b.text = "Host 5-player session"
	host_b.pressed.connect(func():
		NetHost.host_game(5)
		get_tree().change_scene_to_file("res://scenes/Level1.tscn"))
	_net_panel.add_child(host_b)
	var join_b := Button.new()
	join_b.text = "Join address"
	join_b.pressed.connect(func():
		NetHost.join_game(addr.text)
		get_tree().change_scene_to_file("res://scenes/Level1.tscn"))
	_net_panel.add_child(join_b)


func _toggle_net() -> void:
	_net_panel.visible = not _net_panel.visible


func _button(parent: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 44)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
