extends SceneTree
## Headless smoke test: loads every scene and script, fails on any error.
## Run from the project dir:  godot --headless --path . --script tests/smoke.gd

var _errors := 0


func _init() -> void:
	# In --script mode autoloads are not instantiated; register them as named
	# globals so scripts referencing GameState/SaveSystem/etc. can compile.
	if root == null:
		root = Node.new()
		root.name = "root"
		add_child(root)  # deferred-safe: SceneTree owns it now
	_add_autoload("GameSettings", "res://scripts/autoload/GameSettings.gd")
	_add_autoload("GameState", "res://scripts/autoload/GameState.gd")
	_add_autoload("SaveSystem", "res://scripts/autoload/SaveSystem.gd")
	_add_autoload("AudioDirector", "res://scripts/autoload/AudioDirector.gd")

	_check_scenes()
	_check_scripts()
	print("SMOKE RESULT: ", "PASS" if _errors == 0 else "FAIL(%d)" % _errors)
	quit(0 if _errors == 0 else 1)


func _add_autoload(gname: String, path: String) -> void:
	if root.get_node_or_null(NodePath(gname)) != null:
		return
	var s = load(path)
	if s == null:
		_errors += 1
		print("SMOKE FAIL autoload missing: ", path)
		return
	var inst = s.new()
	inst.name = gname
	root.add_child.call_deferred(inst)


func _check_scenes() -> void:
	var scenes := ["res://scenes/MainMenu.tscn", "res://scenes/Level1.tscn",
		"res://scenes/Player.tscn", "res://scenes/HUD.tscn", "res://scenes/PauseMenu.tscn"]
	for s in scenes:
		var ps: PackedScene = load(s)
		if ps == null:
			_errors += 1
			print("SMOKE FAIL scene-load: ", s)
		else:
			var inst := ps.instantiate()
			if inst == null:
				_errors += 1
				print("SMOKE FAIL instantiate: ", s)
			else:
				inst.free()
				print("SMOKE OK scene: ", s)


func _check_scripts() -> void:
	var scripts := []
	_collect(DirAccess.open("res://scripts"), "res://scripts", scripts)
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
				out.append(base + "/" + f)
		f = d.get_next()
	d.list_dir_end()
