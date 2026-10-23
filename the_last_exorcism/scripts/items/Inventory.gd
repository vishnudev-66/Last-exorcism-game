extends RefCounted
class_name Inventory
## Shared inventory model used by every PlayerController. Kept as a plain
## RefCounted (not a Node) so the same class can be serialized/synced in
## multiplayer without scene-tree concerns. Capacity is limited on purpose:
## resource management and teamwork matter (design doc §7).

const DEFAULT_CAPACITY := 8

var capacity := DEFAULT_CAPACITY
var slots: Array = []              # array of item dictionaries or null
var selected_index := -1

signal changed


func _init(cap := DEFAULT_CAPACITY) -> void:
	capacity = cap
	slots.resize(capacity)


func add_item(item: Dictionary) -> bool:
	# Stack by id if possible (e.g. holy water vials).
	var id: String = item.get("id", "")
	for i in slots.size():
		if slots[i] != null and slots[i].get("id", "") == id and slots[i].has("count"):
			slots[i]["count"] += 1
			changed.emit()
			return true
	for i in slots.size():
		if slots[i] == null:
			var copy := item.duplicate(true)
			if not copy.has("count"):
				copy["count"] = 1
			slots[i] = copy
			if selected_index < 0:
				selected_index = i
			changed.emit()
			return true
	return false  # full - caller shows "hands full" message


func remove_one(index: int) -> void:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return
	slots[index]["count"] -= 1
	if slots[index]["count"] <= 0:
		slots[index] = null
		if selected_index == index:
			selected_index = _first_filled()
	changed.emit()


func has_item(type: String, id := "") -> bool:
	for s in slots:
		if s != null and s.get("type", "") == type and (id == "" or s.get("id", "") == id):
			return true
	return false


func count_of(type: String, id := "") -> int:
	var n := 0
	for s in slots:
		if s != null and s.get("type", "") == type and (id == "" or s.get("id", "") == id):
			n += int(s.get("count", 1))
	return n


func select_slot(i: int) -> void:
	if i >= 0 and i < capacity:
		selected_index = i
		changed.emit()


func selected_item():
	if selected_index >= 0 and selected_index < slots.size():
		return slots[selected_index]
	return null


func cycle(dir: int) -> void:
	if slots.is_empty():
		return
	var start := selected_index
	for _n in slots.size():
		selected_index = posmod(selected_index + dir, slots.size())
		if slots[selected_index] != null:
			changed.emit()
			return
	selected_index = start


func _first_filled() -> int:
	for i in slots.size():
		if slots[i] != null:
			return i
	return -1


## Serialization for save files and network sync.
func to_dict() -> Dictionary:
	return {"capacity": capacity, "slots": slots.duplicate(true), "selected": selected_index}


static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new(int(d.get("capacity", DEFAULT_CAPACITY)))
	inv.slots = d.get("slots", []).duplicate(true)
	inv.selected_index = int(d.get("selected", -1))
	return inv
