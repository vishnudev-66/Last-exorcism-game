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
# Props + butcher wait one frame so the World StaticBody exists in the
# physics server (doors/pickups raycast against it immediately after).
await get_tree().physics_frame
_spawn_props()
_spawn_butcher()


func _make_materials() -> void:
_mat_floor = StandardMaterial3D.new()
_mat_floor.albedo_color = Color(0.16, 0.12, 0.1)
_mat_floor.roughness = 0.9
_mat_wall = StandardMaterial3D.new()
_mat_wall.albedo_color = Color(0.22, 0.17, 0.15)
_mat_wall.roughness = 0.85
_mat_wall.shadow_to_opaque = BaseMaterial3D.SHADOW_TO_OPACITY_2
_mat_door = StandardMaterial3D.new()
_mat_door.albedo_color = Color(0.3, 0.12, 0.1)
_mat_door.roughness = 0.7
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
# --- Main hallway (x:-1.7..1.7, z:8..hall_end); east wall opens into the
# side room between z = hall_end-6 .. hall_end-4
_add_hallway(faces, hall_end)
# --- Side room (x:1.7..9, z:hall_end-8..hall_end)
_add_side_room(faces, hall_end)

shape.set_faces(faces)

# Visual mesh from the same triangle soup (single draw call - cheap §16).
# Normals are computed per-triangle so walls read as walls under the
# flashlight even though everything is flat-shaded boxes.
var mesh_inst := MeshInstance3D.new()
mesh_inst.name = "WorldVisual"
var am := ArrayMesh.new()
var arrays := []
arrays[Mesh.ARRAY_VERTEX] = faces
arrays[Mesh.ARRAY_NORMAL] = _face_normals(faces)
var uvs := PackedVector2Array()
for i in faces.size():
uvs.append(Vector2(faces[i].x + faces[i].z * 0.5, faces[i].y))
arrays[Mesh.ARRAY_TEX_UV] = uvs
am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
mesh_inst.mesh = am
mesh_inst.material_override = _mat_wall
world.add_child(mesh_inst)

# Navigation region covering all walkable floors so the Butcher can path.
var nav := NavigationRegion3D.new()
nav.name = "NavRegion"
var nav_mesh := NavigationMesh.new()
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
var fl := FlickerLightScript.new()
l.add_child(fl)
parent.add_child(l)


func _face_normals(faces: PackedVector3Array) -> PackedVector3Array:
var out := PackedVector3Array()
var i := 0
while i + 2 < faces.size():
var n := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
if n.length_squared() < 0.0001:
n = Vector3.UP
out.append(n.normalized())
out.append(n.normalized())
out.append(n.normalized())
i += 3
return out


class FlickerLightScript:
extends Node
## Dim ambient flicker; honours the "reduce flashing" accessibility setting.
func _process(t: float) -> void:
var f := GameSettings.flicker_amount()
var base := 0.25
get_parent().light_energy = base * (1.0 - 0.5 * f * (sin(t * 13.0) > 0.92 or randf() < 0.01 * f))


# ---- Geometry helpers ----------------------------------------------------------
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


func _wall_seg(faces: PackedVector3Array, a: Vector3, b: Vector3, axis: String,
from: float, to: float, gaps: Array, _t: float) -> void:
# `gaps` is an array of [from, to] coordinates where NO wall is built
# (a doorway sits there instead). Lintels above gaps are omitted for
# simplicity - dark trim reads as a doorway in low light.
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
if b.x <= a.x or b.y <= a.y or b.z <= a.z:
return  # zero/negative-size segment (gap spans whole wall)
var p := [a, Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), b, Vector3(a.x, b.y, b.z)]
var idx := [[0,1,2],[0,2,3],[4,6,5],[4,7,6],[0,4,5],[0,5,1],[3,2,6],[3,6,7],[0,3,7],[0,7,4],[1,5,6],[1,6,2]]
for tri in idx:
for k in 3:
faces.append(p[tri[k]])


func _build_nav(nm: NavigationMesh, hall_end: float) -> void:
# Nav polygons are authored directly from the room footprints instead of
# voxel-baking the collision soup: deterministic, instant, and guarantees
# the Butcher's patrol loop stays connected through every doorway gap.
nm.cell_size = 0.25
nm.agent_radius = 0.4
nm.agent_height = 2.2
# Entrance hall
nm.add_polygon([Vector3(-4.6, 0.05, 0.4), Vector3(4.6, 0.05, 0.4),
Vector3(4.6, 0.05, 7.6), Vector3(-4.6, 0.05, 7.6)])
# Hallway strip continues through the hall's north doorway (x:-1..1 @ z=8)
nm.add_polygon([Vector3(-0.9, 0.05, 7.6), Vector3(0.9, 0.05, 7.6),
Vector3(1.4, 0.05, 9.0), Vector3(-1.4, 0.05, 9.0)])
nm.add_polygon([Vector3(-1.4, 0.05, 9.0), Vector3(1.4, 0.05, 9.0),
Vector3(1.4, 0.05, hall_end - 0.4), Vector3(-1.4, 0.05, hall_end - 0.4)])
# Corridor -> side room link through the east-wall gap (z: he-6 .. he-4)
nm.add_polygon([Vector3(1.4, 0.05, hall_end - 5.9), Vector3(1.4, 0.05, hall_end - 4.1),
Vector3(3.0, 0.05, hall_end - 4.6), Vector3(3.0, 0.05, hall_end - 5.4)])
# Side room
nm.add_polygon([Vector3(2.2, 0.05, hall_end - 7.6), Vector3(8.6, 0.05, hall_end - 7.6),
Vector3(8.6, 0.05, hall_end - 0.4), Vector3(2.2, 0.05, hall_end - 0.4)])


# ---- Spawns ---------------------------------------------------------------------
func _spawn_player() -> void:
# In multiplayer each machine spawns ONLY its own local player; remote
# peers spawn theirs and positions sync via MultiplayerSynchronizer.
# Single-player: exactly one player at slot 0.
var slot := 0
var nh := get_tree().root.get_node_or_null("NetHost")
if nh != null and nh.status != 0:  # Status.OFFLINE == 0
slot = int(nh.get_meta("local_slot")) if nh.has_meta("local_slot") else 0
var player_scene := load("res://scenes/Player.tscn")
var player: PlayerController = player_scene.instantiate()
player.player_slot = slot
player.name = "Player%d" % (slot + 1)
player.position = Vector3(-0.8 + 0.4 * slot, 1.0, 2.0)
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
# Entrance door (the story director slams this shut behind the group).
var edoor := _make_door("EntranceDoor", Vector3(0, 0, 0.0), Door.LockType.NONE)
edoor.auto_close_after = 0.0
parent.add_child(edoor)
# Locked servants' door at end of hallway.
var sdoor := _make_door("ServantsDoor", Vector3(0, 0, hall_end_z()), Door.LockType.KEY)
sdoor.required_key_id = "iron_key"
sdoor.opened.connect(func(_p): GameState.set_objective("l1_door", true))
parent.add_child(sdoor)
# Flashlight on a table in the entrance hall.
var fl := FlashlightPickup.new()
fl.prompt_text = "Take the flashlight"
fl.one_shot = true
_add_interactable(fl, Vector3(-2.5, 0.9, 4.0), Vector3(0.3, 0.05, 0.12), "Flashlight")
# Note about the family.
var note := ClueNote.new()
note.clue_id = "voss_letter"
note.clue_text = "\"He keeps them under the house. God forgive me, I hear them singing.\" - E. Voss"
note.prompt_text = "Read the crumpled letter"
_add_interactable(note, Vector3(2.5, 0.9, 3.0), Vector3(0.25, 0.02, 0.18), "Crumpled letter")
# Iron key in the side room (reachable BEFORE the locked door; that door
# leads onward to Level 2 - the servants' quarters).
var key := KeyPickup.new()
key.door_id = "iron_key"
key.key_name = "Iron Key"
key.one_shot = true
key.prompt_text = "Take the iron key"
_add_interactable(key, Vector3(6.0, 0.8, hall_end_z() - 4.0), Vector3(0.15, 0.05, 0.06), "Iron Key")
# Holy water + medkit supplies in side room (Phase 2 taste).
var hw := SupplyPickup.new()
hw.item_type = "holy_water"
hw.item_display = "Holy Water Vial"
hw.one_shot = true
_add_interactable(hw, Vector3(7.0, 0.8, hall_end_z() - 5.0), Vector3(0.1, 0.2, 0.1), "Holy Water")
var mk := SupplyPickup.new()
mk.item_type = "medkit"
mk.item_display = "First-Aid Kit"
mk.stackable = false
mk.one_shot = true
_add_interactable(mk, Vector3(7.5, 0.8, hall_end_z() - 5.0), Vector3(0.2, 0.1, 0.15), "First-Aid Kit")


func hall_end_z() -> float:
return 8.0 + HALL_LEN


func _make_door(id: String, pos: Vector3, lock: Door.LockType) -> Door:
var door := Door.new()
door.add_to_group("interactable")
door.name = id
door.door_id = id.to_lower()
door.lock_type = lock
door.prompt_text = "Open door"
door.one_shot = false
# Geometry: Pivot holds offset panel so rotation swings around the hinge.
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
# Proximity trigger so doors can auto-open/slam (Door._physics_process
# scans "interactable" areas near the player).
var trig := Area3D.new()
trig.collision_layer = 8
trig.collision_mask = 0
var tcs := CollisionShape3D.new()
var tbs := BoxShape3D.new()
tbs.size = Vector3(2.2, 2.6, 1.6)
tcs.shape = tbs
tcs.position = Vector3(0.75, 0, 0)
trig.add_child(tcs)
pivot.add_child(trig)
return door


func _add_interactable(node: Node, pos: Vector3, size: Vector3, label: String) -> void:
node.position = pos
node.add_to_group("interactable")
node.set_meta("label", label)
var mi := MeshInstance3D.new()
var box := BoxMesh.new()
box.size = size
mi.mesh = box
mi.material_override = _mat_item
node.add_child(mi)
# Interaction volume (layer 8): the player raycasts into this Area3D.
var body := Area3D.new()
body.collision_layer = 8
body.collision_mask = 0
var cs := CollisionShape3D.new()
var bs := BoxShape3D.new()
bs.size = size + Vector3(0.4, 0.4, 0.4)
cs.shape = bs
body.add_child(cs)
node.add_child(body)
get_parent().add_child(node)


# ---- ENTITY A: THE BUTCHER -----------------------------------------------------
func _spawn_butcher() -> void:
var parent := get_parent()
var butcher := ButcherAI.new()
butcher.name = "Butcher"
butcher.position = Vector3(0, 1.2, hall_end_z() - 3.0)
butcher.collision_layer = 4
butcher.collision_mask = 1 | 2
butcher.enemy_name = "Butcher"
butcher.sight_range = 12.0
butcher.hearing_range = 14.0
butcher.move_speed_chase = 3.4
butcher.attack_damage = 45.0
butcher.protected = true   # holy water alone won't do it - ritual needed (§7)

var nav := NavigationAgent3D.new()
nav.name = "NavAgent"
nav.radius = 0.45
nav.height = 2.2
nav.pathfinding_algorithm_type = NavigationAgent3D.PATHFINDING_ASTAR_NEXT_TO_NAVIGATION
butcher.add_child(nav)

var model := Node3D.new()
model.name = "Model"
butcher.add_child(model)
var mat := StandardMaterial3D.new()
mat.albedo_color = Color(0.08, 0.05, 0.05)
mat.emission = Color(0.35, 0.03, 0.03)
mat.emission_enabled = true
var torso := MeshInstance3D.new()
var tm := BoxMesh.new()
tm.size = Vector3(0.9, 1.5, 0.6)
torso.mesh = tm
torso.position = Vector3(0, 0.2, 0)
torso.material_override = mat
model.add_child(torso)
var head := MeshInstance3D.new()
var hm := BoxMesh.new()
hm.size = Vector3(0.4, 0.4, 0.4)
head.mesh = hm
head.position = Vector3(0, 1.15, 0)
head.material_override = mat
model.add_child(head)
var apron := MeshInstance3D.new()
var apm := BoxMesh.new()
apm.size = Vector3(0.95, 0.7, 0.65)
apron.mesh = apm
apron.position = Vector3(0, -0.2, 0.05)
var amat := StandardMaterial3D.new()
amat.albedo_color = Color(0.1 + 0.35 * GameSettings.gore_intensity, 0.04, 0.04)
apron.material_override = amat
model.add_child(apron)

var los := RayCast3D.new()
los.name = "LineOfSight"
los.target_position = Vector3(0, 0, -butcher.sight_range)
los.position = Vector3(0, 1.2, 0)
los.collision_mask = 1 | 2   # world blocks sight; players are seen
los.collide_with_areas = false
butcher.add_child(los)

var col := CollisionShape3D.new()
col.name = "Collision"
var cap := CapsuleShape3D.new()
cap.radius = 0.5
cap.height = 2.2
col.shape = cap
col.position = Vector3(0, 0.3, 0)
butcher.add_child(col)

# Patrol loop: hallway <-> side room through the doorway gap.
var path := Path3D.new()
path.name = "PatrolPath"
var curve := Curve3D.new()
for p in [Vector3(0, 0, 10.0), Vector3(0, 0, hall_end_z() - 3.0),
Vector3(5.0, 0, hall_end_z() - 5.0), Vector3(0, 0, hall_end_z() - 3.0)]:
curve.add_point(p)
path.curve = curve
parent.add_child(path)
butcher.patrol_path = path

parent.add_child(butcher)
