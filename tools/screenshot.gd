extends SceneTree

## Capture the desk to a PNG, for looking at.
##
##     godot --script res://tools/screenshot.gd -- <out.png> [width] [height]
##
## Not headless: headless renders nothing. Opens a window briefly and closes it.
## A development convenience, never part of the test run.

const SETTLE_FRAMES: int = 20


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var out_path: String = arguments[0] if arguments.size() > 0 else "user://desk.png"
	var width: int = int(arguments[1]) if arguments.size() > 1 else 540
	var height: int = int(arguments[2]) if arguments.size() > 2 else 960
	# "open" opens the first letter, "reply" also walks the wizard to the end,
	# "map" opens the map over the desk, "ledger" opens the Ledger, "ledger:N"
	# turns to its Nth page, "retire" opens the retirement confirmation and
	# "retired" goes through with it.
	var mode: String = arguments[3] if arguments.size() > 3 else ""

	var window := get_root()

	var scene: PackedScene = load("res://presentation/main.tscn")
	var instance := scene.instantiate()
	window.add_child(instance)
	await process_frame

	# **After** the scene is up, because the boot scene sets the window to a
	# phone size on ready and would undo a resize done before it. The project
	# also stretches a fixed viewport, so the stretch is turned off or every
	# landscape capture comes out portrait.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = Vector2i(width, height)
	DisplayServer.window_set_size(Vector2i(width, height))
	window.size = Vector2i(width, height)

	for i in SETTLE_FRAMES:
		await process_frame

	if mode == "retire" or mode == "retired":
		_retire(instance, mode == "retired")
		for i in SETTLE_FRAMES:
			await process_frame
	elif mode.begins_with("ledger"):
		_open_the_ledger(instance, mode)
		for i in SETTLE_FRAMES:
			await process_frame
	elif mode == "map":
		_open_the_map(instance)
		for i in SETTLE_FRAMES:
			await process_frame
	elif not mode.is_empty():
		_open_a_letter(instance, mode)
		for i in SETTLE_FRAMES:
			await process_frame

	var image := window.get_texture().get_image()
	var error := image.save_png(out_path)
	print("screenshot %s -> %s (asked %dx%d, got %dx%d)" % [
		"ok" if error == OK else "FAILED", out_path, width, height, image.get_width(), image.get_height(),
	])
	quit(0 if error == OK else 1)


## Open the retirement confirmation, or go through with it (#77).
##
## Both are worth looking at: the dialog is the last thing between the player and
## the end of his run, and the closed desk is the only screen M3 has for a
## finished one until #78 gives it a summary.
func _retire(instance: Node, through_with_it: bool) -> void:
	for child in instance.get_children():
		if not (child is DeskScreen):
			continue
		var desk := child as DeskScreen
		if through_with_it:
			desk._retire_from_the_desk()
		else:
			desk._ask_to_retire()
		return
	print("no desk to retire from")


## Open the Ledger, optionally turned to a page.
func _open_the_ledger(instance: Node, mode: String) -> void:
	for child in instance.get_children():
		if not (child is DeskScreen):
			continue
		var desk := child as DeskScreen
		desk._open_ledger()
		var turns: int = int(mode.split(":")[1]) if mode.contains(":") else 0
		for screen in desk.get_children():
			if screen is LedgerScreen:
				for i in turns:
					(screen as LedgerScreen)._turn(1)
		return
	print("no desk to open the ledger from")


## Open the map over the desk, so it can be looked at.
func _open_the_map(instance: Node) -> void:
	for child in instance.get_children():
		if child is DeskScreen:
			(child as DeskScreen)._open_map()
			return
	print("no desk to open the map from")


## Open the first letter on the desk, and optionally answer it, so the reply
## placement can be looked at.
func _open_a_letter(instance: Node, mode: String) -> void:
	var desk: DeskScreen = null
	for child in instance.get_children():
		if child is DeskScreen:
			desk = child
	if desk == null or desk.run.inbox.is_empty():
		print("nothing to open")
		return

	desk._open_letter(desk.run.inbox[0])
	if mode != "reply":
		return

	var view: LetterView = desk._letter_view
	if view == null or view.wizard == null:
		return
	if view.wizard.has_tone_step() and not view.wizard.tone_options().is_empty():
		view.wizard.choose_tone(view.wizard.tone_options()[0]["tone"])
	for step in view.wizard.steps():
		var options: Array = step.get(LetterSchema.KEY_OPTIONS, [])
		if not options.is_empty():
			view.wizard.choose(String(step.get("id", "")), String(options[0].get("id", "")))
	view._show_step()
