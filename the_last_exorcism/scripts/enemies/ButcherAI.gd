extends EnemyBase
class_name ButcherAI
## ENTITY A - THE BUTCHER (physical hunter). Adds on top of EnemyBase:
##   - chases visible players, attacks isolated ones
##   - flashlight exposure angers it (design §5 "reacts to flashlight use")
##   - breaks selected barricades while hunting
## Weakness: holy water + recovered ritual clue removes protection; the exorcism
## script (ExorcismStation) performs the banishment once steps are complete.

@export var isolation_bonus := 6.0     # extra range when target has no friends near
@export var target_barricades: Array[Node] = []

var _barricade_strike_t := 0.0


func transition_logic(delta: float) -> void:
	# Perception tick: find a visible victim.
	var seen := find_visible_player()
	if seen != null:
		# Isolation check - prefer picking off lone players.
		var friends_near := _friends_around(seen)
		var eff_range := sight_range + (isolation_bonus if friends_near == 0 else 0.0)
		if global_position.distance_to(seen.global_position) <= eff_range:
			_target = seen
			_last_known_pos = seen.global_position
			_has_target = true
			if state in [State.IDLE, State.PATROL, State.INVESTIGATE, State.SEARCHING]:
				match_state(State.CHASE)
	elif state == State.CHASE:
		# Lost sight: pursue last noise position, then search hiding spots.
		if _state_t > lose_interest_time:
			_has_target = false
			match_state(State.SEARCHING)
		if _state_t > lose_interest_time + search_duration:
			match_state(State.PATROL)

	match state:
		State.CHASE:
			_chase_step(delta)
		State.SEARCHING:
			if _state_t > search_duration:
				match_state(State.PATROL)
			_generic_navigation_step()
		State.VULNERABLE:
			# Stunned twitching while exposed - window for the ritual.
			velocity = Vector3.ZERO
		_:
			_generic_navigation_step()


func _chase_step(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		match_state(State.SEARCHING)
		return
	_generic_navigation_step()
	if global_position.distance_to(_target.global_position) <= attack_range:
		try_attack(_target)
	# Blocked by a destructible barricade between us? Break it.
	for b in target_barricades:
		if b.has_method("take_impact") and global_position.distance_to(b.global_position) < 2.5 \
				and _barricade_strike_t <= 0.0:
			_barricade_strike_t = 1.0
			b.take_impact(self)


func _friends_around(p: PlayerController) -> int:
	var n := 0
	for other in get_tree().get_nodes_in_group("players"):
		if other != p and not other.is_ghost and \
				other.global_position.distance_to(p.global_position) < 7.0:
			n += 1
	return n


## Flashlight beam hitting the Butcher enrages it temporarily (speed up, louder).
func on_flashlight_exposed(player: PlayerController) -> void:
	if protected:
		_last_known_pos = player.global_position
		if state != State.CHASE:
			match_state(State.INVESTIGATE)


func on_holy_water_hit() -> void:
	super.on_holy_water_hit()
	if state == State.VULNERABLE:
		AudioDirector.whisper()
