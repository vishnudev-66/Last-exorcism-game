extends Node
## LevelBuilder - procedurally constructs the Level 1 vertical slice:
## entrance hall -> long hallway -> locked servants' door -> side room with
## flashlight, key and a Butcher patrol. Pure code = no binary .blend assets,
## easy to review, and every mesh/shape is an original placeholder.
## Collision layers: 1 world, 2 players/triggers, 4 enemies.

const WALL_H := 3.4
const HALL_LEN := 26.0
const HALL_W := 3.4

var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_door: StandardMaterial3D
var _mat_item: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_world()
	_spawn_player()
	_spawn_props()
	_spawn_butcher()


func _make_materials() -> void:
	_mat_floor = StandardMaterial3D.new()
	_mat_floor.albedo_color = Color(0.16, 0.12, 0.1)
	_mat_floor.roughness = 0.9
	_mat_wall = StandardMaterial3D.new()
	_mat_wall.albedo_color = Color(0.22, 0.17, 0.15)
	_mat_wall.roughness = 0.85
	_mat_door = StandardMaterial3D.new()
	_mat_door.albedo_color = Color(0.3, 0.12, 0.1)
	_mat_item = StandardMaterial3D.new()
	_mat_item.albedo_color = Color(0.8, 0.75, 0.5)
	_mat_item.emission = Color(0.5, 0.45, 0.2)
	_mat_item.emission_enabled = true


func _build_world() -> void:
var parent := get_parent()
var hall_end := 8.0 + HALL_LEN
var world := StaticBody3D.new()
world.name = "World"
world.collision_layer = 1
world.collision_mask = 0
parent.add_child(world)
var collider := CollisionShape3D.new()
world.add_child(collider)
var shape := ConcavePolygonShape3D.new()
collider.shape = shape
var faces := PackedVector3Array()

# --- Entrance hall (x:-5..5, z:0..8); north wall has a doorway at x:-1..1
_add_room_with_gaps(faces, Vector3(-5, 0, 0), Vector3(5, WALL_H, 8),
{"north": [[-1.0, 1.0]]})
# --- Main hallway (x:-1.7..1.7, z:8..hall_end); south gap already shared;
# east wall opens into side room between z = hall_end-6 .. hall_end-4
_add_hallway(faces, hall_end)
# --- Side room (x:1.7..9, z:hall_end-8..hall_end); west wall doorway cut
_add_side_room(faces, hall_end)

shape.set_faces(faces)

# Visual mesh from the same triangle soup (single draw call - cheap §16).
var mesh_inst := MeshInstance3D.new()
mesh_inst.name = "WorldVisual"
var am := ArrayMesh.new()
var arrays := []
arrays[Mesh.ARRAY_VERTEX] = faces
var normals := PackedVector3Array()
for _i in faces.size():
normals.append(Vector3.UP)  # flashlight-dominant lighting keeps this fine
arrays[Mesh.ARRAY_NORMAL] = normals
var uvs := PackedVector2Array()
for i in faces.size():
uvs.append(Vector2(faces[i].x, faces[i].z))
arrays[Mesh.ARRAY_TEX_UV] = uvs
am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
mesh_inst.mesh = am
mesh_inst.material_override = _mat_wall
world.add_child(mesh_inst)

# Navigation region covering all walkable floors so the Butcher can path.
var nav := NavigationRegion3D.new()
nav.name = "NavRegion"
var nav_mesh := NavigationMesh.new()
# Build nav polygon from floor quads we added (first 2 tris per room).
_build_nav(nav_mesh, hall_end)
nav.navigation_mesh = nav_mesh
parent.add_child(nav)

# Two dim flickering lights only (limited dynamic lights §16).
for z in [4.0, hall_end - 4.0]:
var l := OmniLight3D.new()
l.position = Vector3(0 if z < 10 else 5.0, WALL_H - 0.3, z)
l.light_energy = 0.25
l.omni_range = 7.0
l.light_color = Color(0.9, 0.55, 0.35)
var fl := Node.new()
fl.set_script(FlickerLight.new())
l.add_child(fl)
parent.add_child(l)


func _add_room_with_gaps(faces: PackedVector3Array, mn: Vector3, mx: Vector3, gaps: Dictionary) -> void:
_floor_ceiling(faces, mn, mx)
var t := 0.25
_wall_seg(faces, Vector3(mn.x - t, 0, mn.z), Vector3(mn.x, mx.y, mx.z), "z", mn.z, mx.z, gaps.get("west", []), t)
_wall_seg(faces, Vector3(mx.x, 0, mn.z), Vector3(mx.x + t, mx.y, mx.z), "z", mn.z, mx.z, gaps.get("east", []), t)
_wall_seg(faces, Vector3(mn.x, 0, mn.z - t), Vector3(mx.x, mx.y, mn.z), "x", mn.x, mx.x, gaps.get("south", []), t)
_wall_seg(faces, Vector3(mn.x, 0, mx.z), Vector3(mx.x, mx.y, mx.z + t), "x", mn.x, mx.x, gaps.get("north", []), t)


func _add_hallway(faces: PackedVector3Array, hall_end: float) -> void:
var mn := Vector3(-HALL_W / 2, 0, 8.0)
var mx := Vector3(HALL_W / 2, WALL_H, hall_end)
_floor_ceiling(faces, mn, mx)
var t := 0.25
_wall_seg(faces, Vector3(mn.x - t, 0, mn.z), Vector3(mn.x, mx.y, mx.z), "z", mn.z, mx.z, [], t)
# East wall opens toward side room: gap z = hall_end-6 .. hall_end-4
_wall_seg(faces, Vector3(mx.x, 0, mn.z), Vector3(mx.x + t, mx.y, mx.z), "z", mn.z, mx.z,
[[hall_end - 6.0, hall_end - 4.0]], t)
# End wall replaced by ServantsDoor object; leave small frame boxes either side
_wall_seg(faces, Vector3(mn.x, 0, mx.z), Vector3(mx.x, mx.y, mx.z + t), "x", mn.x, mx.x,
[[-0.8, 0.8]], t)


func _add_side_room(faces: PackedVector3Array, hall_end: float) -> void:
var mn := Vector3(HALL_W / 2, 0, hall_end - 8.0)
var mx := Vector3(9.0, WALL_H, hall_end)
_floor_ceiling(faces, mn, mx)
var t := 0.25
# West wall shares corridor east wall; rebuild only its non-gap parts here
_wall_seg(faces, Vector3(mn.x - t, 0, mn.z), Vector3(mn.x, mx.y, mx.z), "z", mn.z, mx.z,
[[hall_end - 6.0, hall_end - 4.0]], t)
_wall_seg(faces, Vector3(mx.x, 0, mn.z), Vector3(mx.x + t, mx.y, mx.z), "z", mn.z, mx.z, [], t)
_wall_seg(faces, Vector3(mn.x, 0, mn.z - t), Vector3(mx.x, mx.y, mn.z), "x", mn.x, mx.x, [], t)
_wall_seg(faces, Vector3(mn.x, 0, mx.z), Vector3(mx.x, mx.y, mx.z + t), "x", mn.x, mx.x, [], t)


func _floor_ceiling(faces: PackedVector3Array, mn: Vector3, mx: Vector3) -> void:
faces.append(Vector3(mn.x, 0, mn.z)); faces.append(Vector3(mn.x, 0, mx.z)); faces.append(Vector3(mx.x, 0, mx.z))
faces.append(Vector3(mn.x, 0, mn.z)); faces.append(Vector3(mx.x, 0, mx.z)); faces.append(Vector3(mx.x, 0, mn.z))
faces.append(Vector3(mn.x, mx.y, mn.z)); faces.append(Vector3(mx.x, mx.y, mn.z)); faces.append(Vector3(mx.x, mx.y, mx.z))
faces.append(Vector3(mn.x, mx.y, mn.z)); faces.append(Vector3(mx.x, mx.y, mx.z)); faces.append(Vector3(mn.x, mx.y, mx.z))


func _build_nav(nm: NavigationMesh, hall_end: float) -> void:
nm.cell_size = 0.25
nm.filter_baking_aabb = AABB(Vector3(-20, -1, -5), Vector3(40, 6, 60))
var src := NavigationMeshSourceGeometryData3D.new()
# Bake from the collision shapes we just built (floors included).
var world := get_parent().get_node_or_null("World")
if world != null:
NavigationServer3D.parse_convex_mesh(src, world.get_node("WorldVisual").mesh, Transform3D())
nm.bake_from_source_geometry_data(src)

class FlickerLight extends Node:
	func _process(t: float) -> void:
		var f := GameSettings.flicker_amount()
		var base := 0.25
		get_parent().light_energy = base * (1.0 - 0.5 * f * (sin(t * 13.0) > 0.92 or randf() < 0.01 * f))


## Wall segment builder supporting door gaps. `axis` is the run direction;
## `gaps` is an array of [from, to] coordinates where NO wall is built
## (a doorway sits there instead). Lintels above gaps are omitted for
## simplicity - dark trim reads as a doorway in low light.
func _wall_seg(faces: PackedVector3Array, a: Vector3, b: Vector3, axis: String,
from: float, to: float, gaps: Array, _t: float) -> void:
var cursor := from
for g in gaps:
_add_box(faces, _at(axis, a, cursor), _at(axis, b, g[0]))
cursor = g[1]
if cursor < to:
_add_box(faces, _at(axis, a, cursor), _at(axis, b, to))


func _at(axis: String, v: Vector3, coord: float) -> Vector3:
if axis == "x":
return Vector3(coord, v.y, v.z)
return Vector3(v.x, v.y, coord)


func _add_box(faces: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	var p := [a, Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
		Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), b, Vector3(a.x, b.y, b.z)]
	var idx := [[0,1,2],[0,2,3],[4,6,5],[4,7,6],[0,4,5],[0,5,1],[3,2,6],[3,6,7],[0,3,7],[0,7,4],[1,5,6],[1,6,2]]
	for tri in idx:
		for k in 3:
			faces.append(p[tri[k]])


func _spawn_player() -> void:
	var player_scene := load("res://scenes/Player.tscn")
	var player: PlayerController = player_scene.instantiate()
	player.position = Vector3(0, 1.0, 2.0)
	get_parent().add_child.call_deferred(player)
	var hud_scene := load("res://scenes/HUD.tscn")
	get_parent().add_child.call_deferred(hud_scene.instantiate())
	var pause := load("res://scenes/PauseMenu.tscn")
	get_parent().add_child.call_deferred(pause.instantiate())
	# Bind HUD after both exist.
	await get_tree().process_frame
	for h in get_tree().get_nodes_in_group("hud"):
		h.bind_player(player)


func _spawn_props() -> void:
	var parent := get_parent()
	# Entrance door (seals behind the group).
	var edoor := _make_door("EntranceDoor", Vector3(0, 0, 0.0), LockType.NONE)
	edoor.auto_close_after = 0.0
	parent.add_child.call_deferred(edoor)
	# Locked servants' door at end of hallway.
	var sdoor := _make_door("ServantsDoor", Vector3(0, 0, hall_end_z()), LockType.KEY)
	sdoor.required_key_id = "iron_key"
	parent.add_child.call_deferred(sdoor)
	# Flashlight on a table in entrance hall.
	_add_interactable(load("res://scripts/items/FlashlightPickup.gd").new(),
		Vector3(-2.5, 0.9, 4.0), Vector3(0.3, 0.05, 0.12), _mat_item, "Flashlight")
	# Note about the family.
	var note := load("res://scripts/items/ClueNote.gd").new()
	note.clue_id = "voss_letter"
	note.clue_text = "\"He keeps them under the house. God forgive me, I hear them singing.\" - E. Voss"
	_add_interactable(note, Vector3(2.5, 0.9, 3.0), Vector3(0.25, 0.02, 0.18), _mat_item, "Crumpled letter")
	# Iron key in side room beyond... wait, key must be reachable BEFORE the
	# locked door it opens? No - design: hallway loop gives access to side room
	# first; the door leads onward to Level 2. Key sits in the side room.
	var key := load("res://scripts/items/KeyPickup.gd").new()
	key.door_id = "iron_key"
	key.key_name = "Iron Key"
	_add_interactable(key, Vector3(6.0, 0.8, hall_end_z() - 4.0), Vector3(0.15, 0.05, 0.06), _mat_item, "Iron Key")
	# Holy water + medkit supplies in side room (Phase 2 taste).
	var hw := load("res://scripts/items/SupplyPickup.gd").new()
	hw.item_type = "holy_water"; hw.item_display = "Holy Water Vial"
	_add_interactable(hw, Vector3(7.0, 0.8, hall_end_z() - 5.0), Vector3(0.1, 0.2, 0.1), _mat_item, "Holy Water")
	var mk := load("res://scripts/items/SupplyPickup.gd").new()
	mk.item_type = "medkit"; mk.item_display = "First-Aid Kit"; mk.stackable = false
	_add_interactable(mk, Vector3(7.5, 0.8, hall_end_z() - 5.0), Vector3(0.2, 0.1, 0.15), _mat_item, "First-Aid Kit")


func hall_end_z() -> float:
	return 8.0 + HALL_LEN


enum LockType { NONE, KEY, PUZZLE, SEAL }


func _make_door(id: String, pos: Vector3, lock: int) -> Door:
	var door := Door.new()
	door.name = id
	door.door_id = id.to_lower()
	door.lock_type = lock as Door.LockType
	door.prompt_text = "Open door"
	door.one_shot = false
	# Geometry: Pivot holds offset panel so rotation swings around hinge.
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.position = Vector3(-0.75, 1.2, 0)
	door.add_child(pivot)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 2.4, 0.12)
	mi.mesh = box
	mi.position = Vector3(0.75, 0, 0)
	mi.material_override = _mat_door
	pivot.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.5, 2.4, 0.12)
	cs.shape = bs
	cs.position = Vector3(0.75, 0, 0)
	body.add_child(cs)
	body.position = Vector3(-0.75, 1.2, 0)
	pivot.add_child(body)
	door.position = pos + Vector3(0, -1.2, 0)
	return door


func _add_interactable(node: Node, pos: Vector3, size: Vector3, mat: Material, label: String) -> void:
	node.position = pos
	if node.has_signal("used"):
		pass
	node.set_meta("label", label)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	node.add_child(mi)
	var body := Area3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size + Vector3(0.2, 0.2, 0.2)
	cs.shape = bs
	body.add_child(cs)
	node.add_child(body)
	get_parent().add_child.call_deferred(node)
