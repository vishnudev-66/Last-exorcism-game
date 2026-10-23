extends Node
## GameSettings (autoload) - accessibility & performance settings (sec 3/9/16).
## Persisted to user://settings.cfg. Works on desktop AND HTML5/Web export.

signal settings_changed

const CFG_PATH := "user://settings.cfg"

var master_volume := 0.8          # linear 0..1
var music_volume := 0.5
var sfx_volume := 0.8
var brightness := 1.0             # 0.5 .. 2.0 canvas modulation
var subtitles_enabled := true
var gore_intensity := 1.0         # 0 none .. 1 full
var camera_shake := 1.0           # 0 off .. 1 full
var flash_reduction := false
var graphics_quality := 1         # 0 low, 1 medium, 2 high
var mouse_sensitivity := 1.0
var invert_y := false

# Remapped keys: action -> physical keycode
var keybinds := {
	"move_forward": 87, "move_back": 83, "move_left": 65, "move_right": 68,
	"jump": 32, "crouch": 4194310, "interact": 69, "flashlight": 70,
	"sprint": 4194325, "inventory": 73, "journal": 74, "map": 77, "pause": 4194305,
}


func _ready() -> void:
	load_settings()
	apply_all()


func apply_all() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(master_volume, 0.0001)))
	if AudioServer.get_bus_index("Music") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	if AudioServer.get_bus_index("SFX") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	for a in keybinds:
		_rebind(a)
	match graphics_quality:
		0:
			get_tree().directional_shadow_max_distance = 20.0
		1:
			get_tree().directional_shadow_max_distance = 40.0
		_:
			get_tree().directional_shadow_max_distance = 60.0
	settings_changed.emit()


func flicker_amount() -> float:
	return 0.25 if flash_reduction else 1.0


func shake_amount() -> float:
	return camera_shake


func rebind(action: String, physical_keycode: int) -> void:
	keybinds[action] = physical_keycode
	_rebind(action)
	save_settings()
	settings_changed.emit()


func reset_keybinds() -> void:
	keybinds = {
		"move_forward": 87, "move_back": 83, "move_left": 65, "move_right": 68,
		"jump": 32, "crouch": 4194310, "interact": 69, "flashlight": 70,
		"sprint": 4194325, "inventory": 73, "journal": 74, "map": 77, "pause": 4194305,
	}
	apply_all()
	save_settings()


func _rebind(action: String) -> void:
	if not InputMap.has_action(action):
		return
	# Rebuild the action with a single physical-key binding (remapping support).
	InputMap.erase_action(action)
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keybinds[action]
	InputMap.action_add_event(action, ev)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("s", "master", master_volume)
	cf.set_value("s", "music", music_volume)
	cf.set_value("s", "sfx", sfx_volume)
	cf.set_value("s", "brightness", brightness)
	cf.set_value("s", "subs", subtitles_enabled)
	cf.set_value("s", "gore", gore_intensity)
	cf.set_value("s", "shake", camera_shake)
	cf.set_value("s", "flash", flash_reduction)
	cf.set_value("s", "quality", graphics_quality)
	cf.set_value("s", "sens", mouse_sensitivity)
	cf.set_value("s", "invert", invert_y)
	var i := 0
	for k in keybinds:
		cf.set_value("k", "%d_a" % i, k)
		cf.set_value("k", "%d_c" % i, keybinds[k])
		i += 1
	cf.save(CFG_PATH)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return
	master_volume = float(cf.get_value("s", "master", master_volume))
	music_volume = float(cf.get_value("s", "music", music_volume))
	sfx_volume = float(cf.get_value("s", "sfx", sfx_volume))
	brightness = float(cf.get_value("s", "brightness", brightness))
	subtitles_enabled = bool(cf.get_value("s", "subs", subtitles_enabled))
	gore_intensity = float(cf.get_value("s", "gore", gore_intensity))
	camera_shake = float(cf.get_value("s", "shake", camera_shake))
	flash_reduction = bool(cf.get_value("s", "flash", flash_reduction))
	graphics_quality = int(cf.get_value("s", "quality", graphics_quality))
	mouse_sensitivity = float(cf.get_value("s", "sens", mouse_sensitivity))
	invert_y = bool(cf.get_value("s", "invert", invert_y))
	var i := 0
	while cf.has_value("k", "%d_a" % i):
		var a := String(cf.get_value("k", "%d_a" % i, ""))
		var c := int(cf.get_value("k", "%d_c" % i, 0))
		if keybinds.has(a) and c != 0:
			keybinds[a] = c
		i += 1
