extends CanvasLayer

@onready var gold_label: Label = $GoldLabel
@onready var prompt_label: Label = $PromptLabel
@onready var pan_bar: ProgressBar = $PanBar
@onready var message_label: Label = $MessageLabel

func _ready() -> void:
	update_gold(0.0)
	set_prompt("")
	pan_bar.visible = false
	message_label.visible = false

func update_gold(amount: float) -> void:
	gold_label.text = "Gold Dust: %.2fg" % amount

func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""

func show_panning() -> void:
	pan_bar.visible = true
	pan_bar.value = 0
	_animate_pan_bar()

func _animate_pan_bar() -> void:
	var tween = create_tween()
	tween.tween_property(pan_bar, "value", 100.0, 2.0)

func hide_panning() -> void:
	pan_bar.visible = false

func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	message_label.visible = false
