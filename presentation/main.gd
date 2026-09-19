extends Control

## Boot. Starts or resumes the run, then hands over to the desk.
##
## **Ironman**: there is one save per run and no loading of earlier states
## (SPEC §16.2), so there is no menu of saves here and no "load" — either a run
## is in progress and it resumes, or a new one begins.
##
## Run setup and the main menu are M3 and M7. Until then this opens the desk.

## The seed a development run starts from. Run setup (#M3) chooses it properly.
const DEVELOPMENT_SEED: int = 20_260_918

const PORTRAIT_SIZE: Vector2i = Vector2i(540, 960)

## The loaded content of `data/`.
##
## Looked up through the tree rather than by the `Content` autoload's global
## name. That global only exists when the project boots normally, so naming it
## here would stop this file compiling under `--script` — which is how the
## screenshot tool and any harness load the desk.
var content: ContentDatabase = null

var run: RunState = null
var machine: TurnMachine = null


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().size = PORTRAIT_SIZE

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	content = get_node_or_null(^"/root/Content") as ContentDatabase
	if content == null:
		content = ContentDatabase.new()
		add_child(content)
	# The autoload loads itself when the game boots normally, but a harness that
	# replaces the main loop may get here first. Loading is idempotent.
	content.ensure_loaded()

	if not content.ok():
		_show_failure()
		return

	# **Before the run is made, not after.** Generating the map needs the terrain
	# table, and creating the colony needs the buildings and the needs — so
	# registering afterwards produced a world built against empty tables. It
	# looked harmless because the desk never showed the map; the first thing the
	# map view drew was an empty sea.
	M1Registrations.register_all()
	M1Registrations.load_resources(content)

	_start()


func _start() -> void:
	var resumed := SaveGame.load_run()
	match int(resumed["result"]):
		SaveGame.Result.OK:
			run = resumed["run"]
			print("Resumed a run in progress: turn %d." % run.turn)
		SaveGame.Result.WRONG_VERSION:
			# Refused rather than migrated, and said so rather than silently
			# starting over on top of somebody's run.
			_show_failure(resumed["message"])
			return
		_:
			run = RunState.new_run(DEVELOPMENT_SEED)
			ContactRoster.load_into(run, content)
			print("Began a new run.")

	machine = TurnMachine.new(run)
	machine.use_content(content)

	var desk := DeskScreen.new()
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk)
	desk.begin(run, machine, content)

	# Resuming lands back where the player left off; a new run opens the desk.
	if run.inbox.is_empty() and run.phase != TurnMachine.DESK:
		machine.begin_turn()
	desk.refresh()


func _show_failure(message: String = "") -> void:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = message if not message.is_empty() else "CONTENT FAILED TO LOAD\n\n%s" % content.error_report()
	add_child(label)
	print(label.text)
