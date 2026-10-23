extends CanvasLayer
class_name PauseMenuClass
## Pause menu with Settings (accessibility + audio + quality) and Controls
## remapping UI. Esc toggles; game tree paused while open.

var panel: PanelContainer
var _listening_for := ""


func _ready() -> void:
	layer = 20
	add_to_group("pause_menu")
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_button(box, "Resume", toggle)
	_button(box, "Save Game", _save)
	_button(box, "Settings", _show_settings)
	_button(box, "Controls", _show_controls)
	_button(box, "Quit to Menu", _quit)


static func toggle() -> void:
	for m in Engine.get_main_loop().root.get_children():
		if m is PauseMenuClass:
			m._toggle_impl()
			return


func _toggle_impl() -> void:
	panel.visible = not panel.visible
	get_tree().paused = panel.visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if panel.visible else Input.MOUSE_MODE_CAPTURED)


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _save() -> void:
	SaveSystem.save_game(0)
	GameState.call_deferred("set_process", true)


func _show_settings() -> void:
	var w := Window.new()
	w.title = "Settings"
	add_child(w)
	var box := VBoxContainer.new()
	w.add_child(box)
	_slider(box, "Brightness", GameSettings.brightness, 0.5, 2.0,
		func(v): GameSettings.brightness = v; GameSettings.save_settings())
	_slider(box, "Master volume", GameSettings.master_volume, 0.0, 1.0,
		func(v): GameSettings.master_volume = v; GameSettings.apply_all(); GameSettings.save_settings())
	_slider(box, "Gore intensity", GameSettings.gore_intensity, 0.0, 1.0,
		func(v): GameSettings.gore_intensity = v; GameSettings.save_settings())
	_slider(box, "Camera shake", GameSettings.camera_shake, 0.0, 1.0,
		func(v): GameSettings.camera_shake = v; GameSettings.save_settings())
	_check(box, "Subtitles", GameSettings.subtitles_enabled,
		func(on): GameSettings.subtitles_enabled = on; GameSettings.save_settings())
	_check(box, "Reduce flashing", GameSettings.flash_reduction,
		func(on): GameSettings.flash_reduction = on; GameSettings.save_settings())
	_option(box, "Graphics quality", ["Low", "Medium", "High"], GameSettings.graphics_quality,
		func(i): GameSettings.graphics_quality = i; GameSettings.apply_all(); GameSettings.save_settings())
	w.popup_centered(Vector2i(420, 480))


func _show_controls() -> void:
	var w := Window.new()
	w.title = "Controls - click a binding then press a key"
	add_child(w)
	var grid := GridContainer.new()
	grid.columns = 2
	w.add_child(grid)
	for action in GameSettings.keybinds.keys():
		var l := Label.new()
		l.text = action
		grid.add_child(l)
		var b := Button.new()
		b.text = OS.get_keycode_string(GameSettings.keybinds[action])
		b.pressed.connect(_start_rebind.bind(action, b, w))
		grid.add_child(b)
	w.popup_centered(Vector2i(360, 420))


func _start_rebind(action: String, btn: Button, win: Window) -> void:
	_listening_for = action
	btn.text = "Press any key..."
	get_viewport().gui_input.connect(_on_rebind_input.bind(btn, win), CONNECT_ONE_SHOT)


func _on_rebind_input(ev: InputEvent, btn: Button, _win: Window) -> void:
	if _listening_for != "" and ev is InputEventKey and ev.pressed:
		GameSettings.rebind(_listening_for, ev.physical_keycode)
		btn.text = OS.get_keycode_string(ev.physical_keycode)
		_listening_for = ""


func _slider(parent: Control, label_text: String, val: float, vmin: float, vmax: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(140, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = vmin
	s.max_value = vmax
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	h.add_child(s)
	parent.add_child(h)


func _check(parent: Control, label_text: String, val: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.text = label_text
	c.button_pressed = val
	c.toggled.connect(cb)
	parent.add_child(c)


func _option(parent: Control, label_text: String, opts: PackedStringArray, idx: int, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(140, 0)
	h.add_child(l)
	var o := OptionButton.new()
	for s in opts:
		o.add_item(s)
	o.select(idx)
	o.item_selected.connect(cb)
	h.add_child(o)
	parent.add_child(h)


func _quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
