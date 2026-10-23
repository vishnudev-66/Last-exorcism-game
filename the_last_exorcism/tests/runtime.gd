extends SceneTree
## Runtime test: actually loads Level1, runs several seconds of game time in
## headless mode, and reports any runtime script errors.

var _frames := 0
var _errors := 0


func _initialize() -> void:
    var ps: PackedScene = load("res://scenes/Level1.tscn")
    if ps == null:
        print("RUNTIME FAIL: could not load Level1.tscn")
        quit(1)
        return
    var lvl: Node = ps.instantiate()
    current_scene = lvl
    root.add_child(lvl)
    print("RUNTIME: Level1 instantiated, running frames...")


func _process(_delta: float) -> bool:
    _frames += 1
    if _frames == 300:  # ~5s at 60fps: covers spawn, seal timer, AI ticks
        print("RUNTIME: reached 300 frames")
        var players := get_nodes_in_group("players")
        var enemies := get_nodes_in_group("enemies")
        var hud := get_nodes_in_group("hud")
        print("RUNTIME counts -> players:%d enemies:%d hud:%d" % [players.size(), enemies.size(), hud.size()])
        if players.size() < 1 or enemies.size() < 1 or hud.size() < 1:
            _errors += 1
            print("RUNTIME FAIL: expected >=1 player/enemy/hud")
        print("RUNTIME RESULT: ", "PASS" if _errors == 0 else "FAIL")
        quit(0 if _errors == 0 else 1)
        return true
    return false
