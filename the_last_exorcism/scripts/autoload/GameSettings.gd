extends Node
## GameSettings autoload - accessible settings, remappable controls, quality presets.
## Settings persist to user://settings.cfg so players keep preferences between runs.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

var brightness := 1.0              # 0.5 (dark) .. 2.0 (bright) - accessibility
var master_volume := 0.8
var sfx_volume := 1.0
var music_volume := 0.6
var subtitles_enabled := true      # accessible subtitles for whispers/scares
var gore_intensity := 1.0          # 0.0 = none, 1.0 = full
var camera_shake := 1.0            # motion-sensitivity control
var flash_reduction := false       # reduce strobe/flicker intensity
var graphics_quality := 1          # 0 low / 1 medium / 2 high
var mouse_sensitivity := 1.0
var vsync_enabled := true

# Remapped control names -> physical keycodes (see docs/CONTROLS.md for defaults)
var keybinds := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"crouch": KEY_CTRL,
	"interact": KEY_E,
	"flashlight": KEY_F,
	"sprint": KEY_SHIFT,
	"inventory": KEY_I,
	"journal": KEY_J,
	"map": KEY_M,
}


func _ready() -> void:
	load_settings()
	apply_all()


func apply_all() -> void:
	_apply_keybinds()
	_apply_volumes()
	_apply_quality()
	settings_changed.emit()


func _apply_keybinds() -> void:
	# Rebuild each InputMap action with the currently-bound physical key.
	for action in keybinds.keys():
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keybinds[action]
		InputMap.action_add_event(action, ev)
	# Mouse bindings are fixed for now (RMB use, LMB attack-block, Esc pause).


func rebind(action: String, keycode: int) -> void:
	if keybinds.has(action):
		keybinds[action] = keycode
		_apply_keybinds()
		save_settings()
		settings_changed.emit()


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	var idx_sfx := AudioServer.get_bus_index("SFX")
	var idx_music := AudioServer.get_bus_index("Music")
	if idx_sfx >= 0:
		AudioServer.set_bus_volume_db(idx_sfx, linear_to_db(sfx_volume))
	if idx_music >= 0:
		AudioServer.set_bus_volume_db(idx_music, linear_to_db(music_volume))


func _apply_quality() -> void:
	# Shadow resolution scales with quality to protect the RTX 3050 budget.
	var size := 1024 if graphics_quality == 0 else 2048
	RenderingServer.directional_shadow_atlas_set_size(size, true)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "brightness", brightness)
	cfg.set_value("general", "subtitles", subtitles_enabled)
	cfg.set_value("general", "gore", gore_intensity)
	cfg.set_value("general", "shake", camera_shake)
	cfg.set_value("general", "no_flash", flash_reduction)
	cfg.set_value("general", "quality", graphics_quality)
	cfg.set_value("general", "sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	for action in keybinds:
		cfg.set_value("keys", action, keybinds[action])
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return  # first run - defaults are fine
	brightness = cfg.get_value("general", "brightness", brightness)
	subtitles_enabled = cfg.get_value("general", "subtitles", subtitles_enabled)
	gore_intensity = cfg.get_value("general", "gore", gore_intensity)
	camera_shake = cfg.get_value("general", "shake", camera_shake)
	flash_reduction = cfg.get_value("general", "no_flash", flash_reduction)
	graphics_quality = cfg.get_value("general", "quality", graphics_quality)
	mouse_sensitivity = cfg.get_value("general", "sensitivity", mouse_sensitivity)
	master_volume = cfg.get_value("audio", "master", master_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	for action in keybinds.keys():
		keybinds[action] = cfg.get_value("keys", action, keybinds[action])


## Effective flicker strength after accessibility filters.
func flicker_amount() -> float:
	return 0.15 if flash_reduction else 1.0
