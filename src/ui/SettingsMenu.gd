extends Control

# Settings are saved to user://settings.cfg and read by CameraController + AudioManager.

const CFG_PATH := "user://settings.cfg"

var cfg := ConfigFile.new()

@onready var sens_slider   : HSlider = $Panel/VBox/SensRow/SensSlider
@onready var sens_label    : Label   = $Panel/VBox/SensRow/SensValue
@onready var volume_slider : HSlider = $Panel/VBox/VolRow/VolSlider
@onready var volume_label  : Label   = $Panel/VBox/VolRow/VolValue


func _ready() -> void:
	cfg.load(CFG_PATH)
	var sens   : float = cfg.get_value("controls", "mouse_sensitivity", 0.003)
	var volume : float = cfg.get_value("audio",    "master_volume",     1.0)

	sens_slider.min_value   = 0.0005
	sens_slider.max_value   = 0.008
	sens_slider.step        = 0.0001
	sens_slider.value       = sens
	_update_sens_label(sens)

	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step      = 0.01
	volume_slider.value     = volume
	_update_vol_label(volume)

	sens_slider.value_changed.connect(_on_sens_changed)
	volume_slider.value_changed.connect(_on_vol_changed)


func _on_sens_changed(v: float) -> void:
	_update_sens_label(v)
	cfg.set_value("controls", "mouse_sensitivity", v)
	cfg.save(CFG_PATH)


func _on_vol_changed(v: float) -> void:
	_update_vol_label(v)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
		linear_to_db(v))
	cfg.set_value("audio", "master_volume", v)
	cfg.save(CFG_PATH)


func _on_back_pressed() -> void:
	queue_free()


func _update_sens_label(v: float) -> void:
	sens_label.text = "%d%%" % [roundi(v / 0.008 * 100.0)]


func _update_vol_label(v: float) -> void:
	volume_label.text = "%d%%" % [roundi(v * 100.0)]
