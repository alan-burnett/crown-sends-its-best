extends Control

## Boot. Starts or resumes the run, then hands over to the desk.
##
## **Ironman**: there is one save per run and no loading of earlier states
## (SPEC §16.2), so there is no menu of saves here and no "load" — either a run
## is in progress and it resumes, or a new one begins.
##
## **A new run opens the commission first** (#79, SPEC §6.1): the PC's name, what
## the Crown says the colony is for, how the grant is taken, and which of three
## charts to sail for. A run already in progress skips it, because Ironman means
## those decisions were made once and are not revisited.
##
## The main menu is M7.

## What the commission opens on before the player asks for another chart.
const OPENING_SEED: int = 20_260_918

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
			_open_the_run()
			return

	_open_desk()


## 🔒 **A run opens with a cutscene** (SPEC §6.1, `cutscenes.md` §1).
##
## Shown before the commission, because it is the thing that says where the
## player is: the commission is already the PC sitting at a desk answering for a
## colony, and a run that opened on a form would never have established there was
## anywhere to sail to.
##
## **Skipped silently when there is none.** The opening's panels are a content
## file (#299) and the triggers that fire every other cutscene are #298 — so this
## looks for `cutscenes/opening` and gets out of the way if the Author has not
## written it yet. When the file lands the opening appears, with no change here.
func _open_the_run() -> void:
	var opening := _cutscene(Cutscene.OPENING)
	if opening == null or opening.is_empty():
		_ask_for_the_commission()
		return

	var screen := CutsceneScreen.new()
	add_child(screen)
	screen.finished.connect(func() -> void:
		screen.queue_free()
		_ask_for_the_commission())
	screen.assets = get_node_or_null(^"/root/Assets") as AssetRegistry
	screen.sound = get_node_or_null(SoundEngine.AUTOLOAD_PATH) as SoundEngine
	screen.begin(opening, screen.assets)


## A cutscene from the content database, or null.
func _cutscene(id: StringName) -> Cutscene:
	if content == null or not content.has_record(Cutscene.COLLECTION, String(id)):
		return null
	return Cutscene.from_data(content.record(Cutscene.COLLECTION, String(id)))


## The commission, before there is a run to open a desk on.
func _ask_for_the_commission() -> void:
	var opening := RunSetup.new()
	opening.seed_value = OPENING_SEED

	var screen := SetupScreen.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	screen.begun.connect(_on_commission_signed.bind(screen))
	screen.begin(opening)


func _on_commission_signed(setup: RunSetup, screen: SetupScreen) -> void:
	screen.queue_free()
	run = RunState.from_setup(setup)
	ContactRoster.load_into(run, content)
	print("Began a new run on chart %d." % setup.seed_value)
	_open_desk()


func _open_desk() -> void:
	machine = TurnMachine.new(run)
	machine.use_content(content)

	var desk := DeskScreen.new()
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk)
	desk.begin(run, machine, content)

	# **A finished run opens on its own ending** (#78). Ironman deletes the save
	# when a run ends, so this is only reachable if one somehow survived — and it
	# must not quietly hand the player a live desk.
	if machine.is_over():
		desk.refresh()
		desk._open_the_summary()
		return

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
