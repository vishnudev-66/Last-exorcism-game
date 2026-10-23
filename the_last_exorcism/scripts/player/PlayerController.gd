extends CharacterBody3D
class_name PlayerController
## First-person player controller (Phase 1 core). Modular responsibilities:
##   - movement (walk/sprint/crouch/jump) + stamina
##   - mouse look with sensitivity setting
##   - flashlight with battery drain/recovery
##   - interaction raycast against Interactable nodes
##   - item use (holy water, medkit...) via Inventory selection
##   - health / downed / death -> ghost transformation hook
## Multiplayer note: all state-changing entry points are wrapped so Phase 8 can
## route them through RPCs without rewriting logic.

signal damage_taken(amount: float)
signal died
signal downed
signal revived

# ---- Tuning ------------------------------------------------------------------
@export var walk_speed := 3.2
@export var sprint_speed := 5.6
@export var crouch_speed := 1.6
@export var jump_velocity := 4.5
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var stamina_drain := 18.0     # per second sprinting
@export var stamina_regen := 12.0
@export var battery_drain := 2.0      # % per second, flashlight on
@export var player_slot := 0          # index into GameState.players

var health := max_health
var stamina := max_stamina
var is_downed := false
var is_ghost := false
var inventory := Inventory.new()
var flashlight_on := false
var battery := 100.0
var _crouching := false
var _last_noise_step := 0.0
var _bob_t := 0.0

# ---- Nodes -------------------------------------------------------------------
@onready var camera: Camera3D = $Head/Camera
@onready var flashlight: SpotLight3D = $Head/Camera/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera/InteractRay

const GRAVITY := 18.0


func _ready() -> void:
	add_to_group("players")
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.set_player_state(player_slot, "alive")
	_apply_settings_look()
	GameSettings.settings_changed.connect(_apply_settings_look)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens: float = 0.0022 * GameSettings.mouse_sensitivity
		rotate_y(-event.relative.x * sens)
		camera.rotate_x(-event.relative.y * sens)
		camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(80), deg_to_rad(70))
	elif event.is_action_pressed("pause"):
		_toggle_pause_menu()
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("use_item"):
		use_selected_item()
	elif event.is_action_pressed("inventory"):
		get_tree().call_group("hud", "toggle_inventory")
	elif event.is_action_pressed("journal"):
		get_tree().call_group("hud", "toggle_journal")
	elif event.is_action_pressed("map"):
		get_tree().call_group("hud", "toggle_map")


func _physics_process(delta: float) -> void:
	if is_ghost:
		_ghost_physics(delta)
		return
	if not is_downed:
		_live_physics(delta)
	else:
		velocity = Vector3.ZERO
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
	_update_status_effects(delta)


func _live_physics(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	_crouching = Input.is_key_pressed(KEY_CTRL)
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and not _crouching \
		and stamina > 0 and input_dir.length_squared() > 0.01

	var speed := crouch_speed if _crouching else (sprint_speed if sprinting else walk_speed)
	if velocity.y < -12.0 and is_on_floor():
		take_damage((-velocity.y - 12.0) * 4.0)  # fall injury

	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not _crouching:
			velocity.y = jump_velocity
			_emit_noise(0.6)
	elif velocity.y > 0:
		velocity.y -= GRAVITY * 0.6 * delta  # softer apex control

	var target := wish * speed
	velocity.x = lerpf(velocity.x, target.x, 12.0 * delta)
	velocity.z = lerpf(velocity.z, target.z, 12.0 * delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()

	# Stamina + footstep noise (running is LOUD - the Butcher hears you).
	if sprinting:
		stamina = maxf(stamina - stamina_drain * delta, 0.0)
	else:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
	if is_on_floor() and wish.length_squared() > 0.1:
		_bob_t += delta * (speed / walk_speed)
		_footstep_audio(speed, sprinting)
		# Crouching halves noise; sprint doubles it.
		if _bob_t - _last_noise_step > (0.75 if not sprinting else 0.45):
			_last_noise_step = _bob_t
			_emit_noise(0.35 if _crouching else (1.0 if sprinting else 0.6))

	# Head bob + crouch height (camera lives in Head node).
	var head := $Head
	var target_h := 0.9 if _crouching else 1.6
	head.position.y = lerpf(head.position.y, target_h + sin(_bob_t * 10.0) * 0.03 * minf(speed / walk_speed, 1.4), 10.0 * delta)


func _ghost_physics(delta: float) -> void:
	# Ghosts float: no gravity, wall pass allowed only through designated
	# "ghost_passable" geometry handled by collision layers (mask excludes walls).
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity = wish * 4.0
	velocity.y = Input.get_axis("crouch", "jump") * 2.0
	move_and_slide()


func _update_status_effects(delta: float) -> void:
	if flashlight_on:
		battery = maxf(battery - battery_drain * delta, 0.0)
		if battery <= 0.0:
			set_flashlight(false)
			show_message("The flashlight dies.")
	else:
		battery = minf(battery + 0.5 * delta, 100.0)  # slow recovery when off
	if flash_light_flicker(battery):
		flashlight.light_energy = randf_range(0.4, 1.2) * GameSettings.flicker_amount()
	else:
		flashlight.light_energy = 1.0
	# Downed bleed-out: die after 60s unless revived.
	if is_downed:
		health -= 100.0 / 60.0 * delta
		if health <= 0.0:
			become_ghost()


static func flash_light_flicker(b: float) -> bool:
	return b < 25.0 and randf() < 0.02 * GameSettings.flicker_amount()


func toggle_flashlight() -> void:
	set_flashlight(not flashlight_on)


func set_flashlight(on: bool) -> void:
	if on and battery <= 1.0:
		show_message("Battery dead.")
		return
	flashlight_on = on
	flashlight.visible = on


func _emit_noise(loudness: float) -> void:
	NoiseSource.emit_noise(global_position, loudness)


func _footstep_audio(speed: float, sprinting: bool) -> void:
	if is_on_floor() and fmod(_bob_t, 1.0) < 0.02:
		AudioDirector.footstep(sprinting)


# ---- Interaction -------------------------------------------------------------
func _try_interact() -> void:
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
	var node: Node = collider
	while node != null and not (node is Interactable):
		node = node.get_parent()
	if node == null:
		return
	var ok: bool = node.interact(self)
	if ok:
		AudioDirector.interact_ok()


func get_hovered_interactable() -> Interactable:
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return null
	var node: Node = interact_ray.get_collider()
	while node != null and not (node is Interactable):
		node = node.get_parent()
	return node as Interactable


# ---- Combat / states ---------------------------------------------------------
func take_damage(amount: float) -> void:
	if is_ghost or is_downed:
		return
	health -= amount
	damage_taken.emit(amount)
	if health <= 0.0:
		down()


func down() -> void:
	is_downed = true
	health = max_health  # bleed-out timer reuses health bar
	GameState.set_player_state(player_slot, "downed")
	downed.emit()
	show_message("You are down! A friend can revive you.")


func revive_by(by_player: PlayerController) -> void:
	if not is_downed:
		return
	is_downed = false
	health = max_health * 0.5
	GameState.set_player_state(player_slot, "alive")
	revived.emit()


func become_ghost() -> void:
	is_ghost = true
	is_downed = false
	GameState.set_player_state(player_slot, "ghost")
	died.emit()
	# Collision: ghosts ignore world walls but still collide with triggers.
	collision_mask = 0b100
	var cam_fx := camera.get_node_or_null("GhostFX")
	if cam_fx:
		cam_fx.visible = true


func use_selected_item() -> void:
	var item = inventory.selected_item()
	if item == null:
		return
	match item.get("type", ""):
		"holy_water":
			throw_holy_water(item)
		"medkit":
			if health < max_health:
				health = minf(health + 40.0, max_health)
				inventory.remove_one(inventory.selected_index)
				show_message("You patch your wounds.")
		"book":
			get_tree().call_group("hud", "toggle_journal")
		_:
			show_message("Not usable here.")


func throw_holy_water(item: Dictionary) -> void:
	# Simplified projectile-free application: damages nearby supernatural enemies.
	inventory.remove_one(inventory.selected_index)
	var origin := global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("on_holy_water_hit"):
			if origin.distance_to(e.global_position) < 6.0:
				e.on_holy_water_hit()
	show_message("The vial bursts in a spray of salt and light.")


func _toggle_pause_menu() -> void:
	for m in get_tree().get_nodes_in_group("pause_menu"):
		m._toggle_impl()


func show_message(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)


func _apply_settings_look() -> void:
	pass  # sensitivity read live in _unhandled_input


func current_objective_text() -> String:
	for id in GameState.objectives:
		if not GameState.objectives[id]["done"]:
			return GameState.objectives[id]["text"]
	return "Explore. Survive."
