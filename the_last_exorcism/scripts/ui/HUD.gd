extends CanvasLayer
class_name HUDClass
## In-game HUD: crosshair, interaction prompt, message toast, objective tracker,
## health/stamina/battery bars, inventory strip, teammate status, ghost energy,
## journal & map overlays. Accessible subtitles toggle honoured for whispers.

var message_label: Label
var prompt_label: Label
var objective_label: Label
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var battery_bar: ProgressBar
var energy_bar: ProgressBar
var inv_panel: PanelContainer
var inv_grid: GridContainer
var journal_panel: PanelContainer
var journal_text: RichTextLabel
var map_panel: PanelContainer
var subtitle_label: Label
var vignette: TextureRect
var _msg_t := 0.0
var _player: PlayerController


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_build_ui()
	GameState.objective_updated.connect(func(_id, _d): _refresh_objective())
	GameState.player_state_changed.connect(func(_i, _s): _refresh_energy_visibility())


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	prompt_label = _label(root, Vector2(0, -70), PRESET_BOTTOM_LEFT)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message_label = _label(root, Vector2(0, -110), PRESET_BOTTOM_LEFT)
	objective_label = _label(root, Vector2(0, 12), PRESET_TOP_LEFT)
	subtitle_label = _label(root, Vector2(0, 60), PRESET_BOTTOM_WIDE)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	health_bar = _bar(root, Vector2(16, 16), Color(0.55, 0.08, 0.08), "Health")
	stamina_bar = _bar(root, Vector2(16, 44), Color(0.15, 0.4, 0.2), "Stamina")
	battery_bar = _bar(root, Vector2(16, 72), Color(0.7, 0.6, 0.15), "Battery")
	energy_bar = _bar(root, Vector2(16, 100), Color(0.35, 0.5, 0.85), "Spirit")
	energy_bar.visible = false

	# Crosshair
	var xh := ColorRect.new()
	xh.color = Color(0.9, 0.9, 0.9, 0.6)
	xh.size = Vector2(3, 3)
	xh.position = Vector2(get_viewport_rect().size.x / 2 - 1.5, get_viewport_rect().size.y / 2 - 1.5)
	root.add_child(xh)

	inv_panel = PanelContainer.new()
	inv_panel.set_anchors_preset(PRESET_TOP_RIGHT)
	inv_panel.position = Vector2(-220, 12)
	inv_grid = GridContainer.new()
	inv_grid.columns = 4
	inv_panel.add_child(inv_grid)
	root.add_child(inv_panel)

	journal_panel = _overlay_panel("Journal - Exorcism Book")
	journal_text = journal_panel.get_node("Box/Text")
	root.add_child(journal_panel)

	map_panel = _overlay_panel("Mansion Map (unlocks as you explore)")
	root.add_child(map_panel)


func _label(parent: Control, offset: Vector2, preset: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.position = offset
	l.add_theme_font_size_override("font_size", 16)
	parent.add_child(l)
	return l


func _bar(parent: Control, pos: Vector2, color: Color, _name: String) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = Vector2(180, 12)
	b.min_value = 0
	b.max_value = 100
	b.show_percentage = false
	b.modulate = color
	parent.add_child(b)
	return b


func _overlay_panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(PRESET_FULL_RECT)
	p.visible = false
	var box := VBoxContainer.new()
	box.name = "Box"
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 22)
	box.add_child(t)
	var txt := RichTextLabel.new()
	txt.name = "Text"
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(txt)
	p.add_child(box)
	return p


func bind_player(p: PlayerController) -> void:
	_player = p
	_refresh_objective()


func _process(delta: float) -> void:
	if _player == null:
		return
	health_bar.value = maxf(_player.health, 0)
	stamina_bar.value = _player.stamina
	battery_bar.value = _player.battery
	energy_bar.visible = _player.is_ghost
	if _player.is_ghost:
		energy_bar.value = GameState.spiritual_energy
	# Hovered interactable prompt
	var it := _player.get_hovered_interactable()
	if it != null and it.can_interact(_player):
		prompt_label.text = "[E] %s" % it.get_prompt(_player)
	else:
		prompt_label.text = ""
	# Message fade
	if _msg_t > 0:
		_msg_t -= delta
		if _msg_t <= 0:
			message_label.text = ""
	_refresh_inventory_strip()


func show_message(text: String) -> void:
	message_label.text = text
	_msg_t = 3.5
	if GameSettings.subtitles_enabled:
		subtitle_label.text = ""


func show_subtitle(text: String) -> void:
	if GameSettings.subtitles_enabled:
		subtitle_label.text = text
		get_tree().create_timer(4.0).timeout.connect(func(): subtitle_label.text = "")


func _refresh_objective() -> void:
	if _player:
		objective_label.text = "OBJECTIVE: " + _player.current_objective_text()


func _refresh_energy_visibility() -> void:
	pass


func _refresh_inventory_strip() -> void:
	for c in inv_grid.get_children():
		c.queue_free()
	for i in _player.inventory.slots.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		var s = _player.inventory.slots[i]
		btn.text = ("%" % s["name"][0]).left(1) + ("\n%d" % s["count"] if s["count"] > 1 else "") \
			if s != null else "-"
		btn.tooltip_text = str(s.get("name", "")) if s != null else "Empty"
		btn.pressed.connect(_player.inventory.select_slot.bind(i))
		if i == _player.inventory.selected_index:
			btn.modulate = Color(1.0, 0.85, 0.85)
		inv_grid.add_child(btn)


func toggle_inventory() -> void:
	pass  # inventory strip always visible; full panel comes with Phase 2 polish


func toggle_journal() -> void:
	journal_panel.visible = not journal_panel.visible
	if journal_panel.visible:
		var sb := ""
		for e in GameState.journal_entries:
			sb += "• " + e["text"] + "\n"
		sb += "\n-- Rituals --\n"
		for name in GameState.exorcisms:
			var ex = GameState.exorcisms[name]
			sb += "%s: %d/%d steps%s\n" % [name, ex["progress"], ex["steps"].size(),
				" [COMPLETE]" if ex["complete"] else ""]
		journal_text.text = sb if sb.strip_edges() != "" else "Nothing recorded yet."
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if journal_panel.visible else Input.MOUSE_MODE_CAPTURED)


func toggle_map() -> void:
	map_panel.visible = not map_panel.visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if map_panel.visible else Input.MOUSE_MODE_CAPTURED)
