extends CanvasLayer

@onready var gold_label:    Label       = $GoldLabel
@onready var timber_label:  Label       = $TimberLabel
@onready var tool_label:    Label       = $ToolLabel
@onready var prompt_label:  Label       = $PromptLabel
@onready var pan_bar:       ProgressBar = $PanBar
@onready var message_label: Label       = $MessageLabel
@onready var notify_label:  Label       = $NotifyLabel

func _ready() -> void:
	pan_bar.visible       = false
	message_label.visible = false
	notify_label.visible  = false
	set_prompt("")
	# Hook into SaveManager
	SaveManager.gold_changed.connect(_on_gold_changed)
	SaveManager.timber_changed.connect(_on_timber_changed)
	SaveManager.tool_unlocked.connect(_on_tool_unlocked)
	_on_gold_changed(SaveManager.get_gold())
	_on_timber_changed(SaveManager.get_timber())

func _on_gold_changed(amount: float) -> void:
	gold_label.text = "⚙  %.2fg" % amount

func _on_timber_changed(amount: int) -> void:
	timber_label.text = "🪵  %d timber" % amount

func _on_tool_unlocked(tool_id: String) -> void:
	if tool_id.ends_with("_available"):
		var tid: String   = tool_id.replace("_available", "")
		var tname: String = str(ToolSystem.TOOLS.get(tid, {}).get("name", tid))
		show_notify("🔓 %s now available at the store!" % tname)
	else:
		var tname: String = str(ToolSystem.TOOLS.get(tool_id, {}).get("name", tool_id))
		show_notify("✅ %s purchased!" % tname)

func set_tool(tool_id: String) -> void:
	tool_label.text = ToolSystem.get_display(tool_id)

func set_prompt(text: String) -> void:
	prompt_label.text    = text
	prompt_label.visible = text != ""

func show_mining(tool_id: String, action_time: float) -> void:
	pan_bar.visible = true
	pan_bar.value   = 0
	var tween := create_tween()
	tween.tween_property(pan_bar, "value", 100.0, action_time)

func hide_mining() -> void:
	pan_bar.visible = false

func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text    = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	message_label.visible = false

func show_notify(text: String, duration: float = 4.0) -> void:
	notify_label.text    = text
	notify_label.visible = true
	await get_tree().create_timer(duration).timeout
	notify_label.visible = false
