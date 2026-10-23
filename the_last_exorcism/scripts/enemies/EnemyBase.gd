extends CharacterBody3D
class_name EnemyBase
## Base supernatural enemy with an explicit state machine, navigation, detection,
## attack cooldowns, vulnerability states and difficulty configuration (§5).
## Rules enforced here:
##   - No wall-hacks: LOS is raycast against the real collision world.
##   - No arbitrary teleport (subclasses may use scripted shadow moves only).
##   - Holy water WEAKENS (vulnerable window), it never one-shots a boss.

enum State { IDLE, PATROL, INVESTIGATE, CHASE, ATTACK, SEARCHING, STUNNED, VULNERABLE, BANISHED }

@export var enemy_name := "The Butcher"
@export var patrol_path: Path3D = null
@export var move_speed_patrol := 1.6
@export var move_speed_chase := 3.4          # < sprint speed so you CAN escape
@export var hearing_range := 14.0
@export var sight_range := 9.0
@export var attack_range := 1.8
@export var attack_damage := 34.0            # down in 3 hits on normal
@export var attack_cooldown := 1.6
@export var lose_interest_time := 6.0
@export var search_duration := 8.0
@export var holy_water_stun := 2.5           # seconds vulnerable after douse
@export var difficulty_scale := 1.0          # set from GameState difficulty

var state: State = State.IDLE
var _state_t := 0.0
var _attack_t := 0.0
var _last_known_pos := Vector3.ZERO
var _has_target := false
var _target: PlayerController = null
var _patrol_index := 0
var vulnerable_until := 0.0
var protected := true                        # supernatural protection until weakness found

@onready var nav_agent: NavigationAgent3D = $NavAgent
@onready var model: Node3D = $Model

signal state_changed(s: State)


func _ready() -> void:
	add_to_group("enemies")
	NoiseSource.listeners.append(_on_noise)
	match_state(State.PATROL if patrol_path else State.IDLE)


func _process(delta: float) -> void:
	_state_t += delta
	_attack_t -= delta
	var now := Time.get_ticks_msec() / 1000.0
	if state == State.VULNERABLE and now > vulnerable_until:
		match_state(State.SEARCHING)
	transition_logic(delta)


## Template method - subclasses implement per-state behaviour.
func transition_logic(_delta: float) -> void:
	_generic_navigation_step()


func match_state(s: State) -> void:
	if state == s:
		return
	state = s
	_state_t = 0.0
	state_changed.emit(s)


# ---- Detection ----------------------------------------------------------------
func _on_noise(pos: Vector3, loudness: float) -> void:
	# Noise investigation - louder noises (sprinting/jumping) carry farther.
	var effective := hearing_range * loudness * difficulty_scale
	if global_position.distance_to(pos) <= effective and state != State.CHASE:
		if state in [State.IDLE, State.PATROL, State.INVESTIGATE]:
			_last_known_pos = pos
			match_state(State.INVESTIGATE)


func find_visible_player() -> PlayerController:
	# Real raycast LOS - cannot see through walls. Ghosts are invisible to enemies.
	var best: PlayerController = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_ghost or p.is_downed:
			continue
		var d := global_position.distance_to(p.global_position)
		if d > sight_range * difficulty_scale:
			continue
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 1.4, p.global_position + Vector3.UP * 1.2,
			collision_mask, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.collider == p:
			if d < best_d:
				best_d = d
				best = p
	return best


# ---- Attack --------------------------------------------------------------------
func try_attack(target: PlayerController) -> void:
	if _attack_t > 0.0:
		return
	_attack_t = attack_cooldown / maxf(difficulty_scale, 0.5)
	target.take_damage(attack_damage)
	AudioDirector.scare_stinger()


# ---- Vulnerability -------------------------------------------------------------
func on_holy_water_hit() -> void:
	# Weakens appropriate supernatural enemies rather than killing them (§7).
	if protected:
		show_feedback("It hisses - but the light slides off. Something still protects it.")
		protected_flash()
		return
	vulnerable_until = Time.get_ticks_msec() / 1000.0 + holy_water_stun
	match_state(State.VULNERABLE)
	show_feedback("The %s recoils, its protection burning away!" % enemy_name)


func protected_flash() -> void:
	if model:
		var t := create_tween()
		t.tween_property(model, "scale", Vector3(1.15, 0.9, 1.15), 0.1)
		t.tween_property(model, "scale", Vector3.ONE, 0.25)


func show_feedback(msg: String) -> void:
	get_tree().call_group("hud", "show_message", msg)


# ---- Movement ------------------------------------------------------------------
func _generic_navigation_step() -> void:
	var goal := _current_goal()
	if goal == null:
		return
	nav_agent.target_position = goal
	var next := nav_agent.get_next_path_position()
	var dir := (next - global_position)
	dir.y = 0.0
	if dir.length_squared() < 0.04:
		velocity.x = velocity.z = 0.0
	else:
		dir = dir.normalized()
		var spd := move_speed_patrol
		if state == State.CHASE:
			spd = move_speed_chase
		elif state == State.INVESTIGATE or state == State.SEARCHING:
			spd = move_speed_patrol * 1.4
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		look_at(global_position + Vector3(dir.x, 0, dir.z) * 10.0 + Vector3.UP * global_position.y, Vector3.UP)
	if not nav_agent.is_on_navigation_floor():
		velocity.y -= 18.0
	move_and_slide()


func _current_goal() -> Variant:
	match state:
		State.PATROL:
			return _next_waypoint()
		State.INVESTIGATE:
			return _last_known_pos if _state_t < 5.0 else null
		State.CHASE:
			return _target.global_position if _target else null
		State.SEARCHING:
			return _search_point()
		_:
			return null


func _next_waypoint() -> Vector3:
	if patrol_path == null or patrol_path.curve.points.size() == 0:
		return global_position
	var pts := patrol_path.curve.points
	var p: Vector3 = pts[_patrol_index % pts.size()].position
	if global_position.distance_to(p) < 1.0:
		_patrol_index += 1
	return p


func _search_point() -> Vector3:
	# Rotate around last known position checking hiding spots - no cheating.
	var ang := _state_t * 1.2
	return _last_known_pos + Vector3(cos(ang), 0, sin(ang)) * 3.5


## Called by exorcism scripts when players complete the entity's ritual.
func begin_banishment() -> void:
	match_state(State.BANISHED)
	AudioDirector.exorcism_chime()
	if model:
		var t := create_tween()
		t.tween_property(model, "scale", Vector3.ZERO, 2.0)
		t.tween_callback(queue_free)
