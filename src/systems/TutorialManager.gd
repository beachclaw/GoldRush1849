extends Node

# Contextual first-time hints. Shown once, then never again.

const SAVE_KEY := "tutorial_shown"

var _shown: Dictionary = {}
var _hud: Node = null

func init(hud: Node) -> void:
	_hud = hud
	# Load which steps already shown
	var raw: Variant = SaveManager.data.get(SAVE_KEY, {})
	if raw is Dictionary:
		_shown = raw

func show_step(step: String, text: String, delay: float = 0.5) -> void:
	if _shown.get(step, false):
		return
	_shown[step] = true
	SaveManager.data[SAVE_KEY] = _shown
	SaveManager.save()
	if _hud:
		_do_show.call_deferred(text, delay)

func _do_show(text: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_hud.show_notify(text, 5.0)
