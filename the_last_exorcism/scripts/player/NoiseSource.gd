extends Node
class_name NoiseSource
## Invisible emitter that reports player movement noise to the AI system.
## The Butcher (and later entities) subscribe via `Globals`-style static registry.
## Keeping noise as data (not sound) means enemies react without audio cheating.

static var listeners: Array[Callable] = []


static func emit_noise(pos: Vector3, loudness: float) -> void:
	for cb in listeners:
		cb.call(pos, loudness)


func report(pos: Vector3, loudness: float) -> void:
	NoiseSource.emit_noise(pos, loudness)
