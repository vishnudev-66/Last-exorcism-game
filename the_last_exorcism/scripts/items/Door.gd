extends Interactable
class_name Door
## Doors support four lock types (design doc §4):
##   none      - always openable
##   key       - needs matching KeyPickup door_id in inventory
##   puzzle    - opened by a puzzle script calling unlock()
##   seal      - supernatural; only an exorcism or ghost ability opens it
## Also supports scripted emergency closure via slam_shut().

enum LockType { NONE, KEY, PUZZLE, SEAL }

signal opened(player: PlayerController)
signal closed

@export var door_id := "door_default"
@export var lock_type: LockType = LockType.NONE
@export var required_key_id := ""          # for KEY locks
@export var reverse_open := false           # hinge direction fix per doorway
@export var auto_close_after := 0.0         # seconds; 0 = stay open (Level events use this)
@export var sealed_message := "A black frost spreads across the handle. Not yet."

var is_open := false
var locked := false
var _closing := false

@onready var _pivot: Node3D = get_node_or_null("Pivot")
@onready var _area: Area3D = get_node_or_null("Trigger")


func _ready() -> void:
	locked = lock_type != LockType.NONE
	if _area:
		_area.monitoring = false
		_area.monitorable = true


func can_interact(player: PlayerController) -> bool:
	return enabled  # doors are always inspectable; failure gives feedback


func interact(player: PlayerController) -> bool:
	if not enabled:
		return false
	if is_open:
		_toggle(false, player)
		return true
	if locked:
		match lock_type:
			LockType.KEY:
				if player.inventory.has_item("key", required_key_id):
					unlock()
					_toggle(true, player)
					player.show_message("The %s turns the lock." % required_key_id)
					return true
				else:
					player.show_message("Locked. You need the matching key.")
					AudioDirector.interact_fail()
					return false
			LockType.SEAL:
				player.show_message(sealed_message)
				AudioDirector.whisper()
				return false
			LockType.PUZZLE:
				player.show_message("Something holds this from the other side.")
				AudioDirector.interact_fail()
				return false
		return false
	_toggle(true, player)
	return true


func _toggle(open: bool, _player) -> void:
	is_open = open
	_closing = false
	animate(open)
	if open:
		AudioDirector.door_open()
		opened.emit(_player)
		if auto_close_after > 0.0:
			get_tree().create_timer(auto_close_after).timeout.connect(slam_shut)
	else:
		closed.emit()


func animate(open: bool) -> void:
	if _pivot == null:
		return
	var target := (PI / 2.0 if open else 0.0) * (-1.0 if reverse_open else 1.0)
	var t := create_tween()
	t.tween_property(_pivot, "rotation:y", target, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


## Scripted emergency closure used by story events (Level 1 sealing etc.).
func slam_shut() -> void:
	if not is_open:
		return
	is_open = false
	_closing = true
	animate(false)
	AudioDirector.scare_stinger()
	closed.emit()


func unlock() -> void:
	locked = false
	lock_type = LockType.NONE


func reseal() -> void:
	locked = true
	lock_type = LockType.SEAL
	if is_open:
		is_open = false
		animate(false)


func _enter_tree() -> void:
	if lock_type == LockType.SEAL:
		add_to_group("seals")
