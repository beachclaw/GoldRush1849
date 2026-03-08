extends CanvasLayer

# Covers the screen with a fade-in/out transition so the jump from
# main menu → game doesn't look like a crash.

const FADE_IN_TIME  := 0.5   # seconds to fade from black to game
const HOLD_TIME     := 0.6   # how long to show the loading text
const FADE_OUT_TIME := 0.4   # seconds to fade back to game (after load)

var _timer := 0.0
var _phase := 0   # 0=hold black, 1=fade in, 2=done

@onready var overlay : ColorRect = $Overlay
@onready var label   : Label     = $Overlay/Label


func _ready() -> void:
	layer = 10  # above everything
	overlay.color = Color(0.06, 0.04, 0.02, 1.0)   # near-black warm
	label.text    = "California, 1849..."
	_phase = 0
	_timer = 0.0


func _process(delta: float) -> void:
	_timer += delta
	match _phase:
		0:  # hold black while scene loads
			if _timer >= HOLD_TIME:
				_phase = 1
				_timer = 0.0
		1:  # fade to transparent
			var t := clampf(_timer / FADE_IN_TIME, 0.0, 1.0)
			overlay.color.a = 1.0 - t
			label.modulate.a = 1.0 - t
			if t >= 1.0:
				_phase = 2
				set_process(false)
				queue_free()
