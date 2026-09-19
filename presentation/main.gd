extends Control

## Boot scene. **A placeholder, and deliberately almost empty.**
##
## The desk is the game (SPEC §2, §15) and it arrives with #21. This exists so
## the project runs and exports now, and so a content mistake is visible the
## moment someone presses play rather than at the first letter.
##
## Portrait-first (SPEC §15): the window opens at a phone's proportions, because
## a layout checked in landscape and ported to portrait afterwards is a layout
## that has to be built twice.

const PORTRAIT_SIZE: Vector2i = Vector2i(540, 960)


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().size = PORTRAIT_SIZE

	# Also to stdout, so a headless boot is a usable smoke test in CI.
	print(_status())

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = _status()
	add_child(label)


func _status() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(ProjectSettings.get_setting("application/config/name", "The Crown Sends Its Best"))
	lines.append("")
	if Content.ok():
		var counts: PackedStringArray = PackedStringArray()
		for name in Content.collection_names():
			counts.append("%s: %d" % [name, Content.collection(name).size()])
		lines.append("Content loaded — %s" % ", ".join(counts))
	else:
		lines.append("CONTENT FAILED TO LOAD")
		lines.append(Content.error_report())
	lines.append("")
	lines.append("The desk arrives with #21.")
	return "\n".join(lines)
