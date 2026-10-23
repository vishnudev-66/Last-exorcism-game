extends SceneTree
## Headless smoke test: loads every scene and script, fails on any error.
## Run from the project dir:  godot --headless --path . --script tests/smoke.gd

var _errors := 0


func _initialize() -> void:
	_check_scenes()
	_check_scripts()
	print("SMOKE RESULT: ", "PASS" if _errors == 0 else "FAIL(%d)" % _errors)
	quit(0 if _errors == 0 else 1)


func _check_scenes() -> void:
	var scenes := ["res://scenes/MainMenu.tscn", "res://scenes/Level1.tscn",
		"res://scenes/Player.tscn", "res://scenes/HUD.tscn", "res://scenes/PauseMenu.tscn"]
	for s in scenes:
		var ps: PackedScene = load(s)
		if ps == null:
			_errors += 1
			print("SMOKE FAIL scene-load: ", s)
		else:
			var inst: Node = ps.instantiate()
			if inst == null:
				_errors += 1
				print("SMOKE FAIL instantiate: ", s)
			else:
				inst.free()
				print("SMOKE OK scene: ", s)


func _check_scripts() -> void:
	var scripts := []
	_collect(DirAccess.open("res://scripts"), "res://scripts", scripts)
	_collect(DirAccess.open("res://scripts/autoload"), "res://scripts/autoload", scripts)
	for sc in scripts:
		var gs = load(sc)
		if gs == null or not (gs is GDScript):
			_errors += 1
			print("SMOKE FAIL script: ", sc)
		elif not (gs as GDScript).can_instantiate():
			_errors += 1
			print("SMOKE FAIL compile: ", sc)
		else:
			print("SMOKE OK script: ", sc)


func _collect(d: DirAccess, base: String, out: Array) -> void:
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not f.begins_with("."):
			if d.current_is_dir():
				_collect(DirAccess.open(base + "/" + f), base + "/" + f, out)
			elif f.ends_with(".gd"):
				var p := base + "/" + f
				if not out.has(p):
					out.append(p)
		f = d.get_next()
	d.list_dir_end()
