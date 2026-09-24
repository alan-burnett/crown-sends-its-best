class_name DeskTheme
extends RefCounted

## The look of the desk, in one place.
##
## **Placeholders, through code rather than through .tres files**, so the Author
## can drop in real art and a real theme later without any of this being in the
## way (SPEC §16.3). Nothing outside this file picks a colour or a size.
##
## **🔒 Text is the main medium**, and letters must be comfortable to read at
## length on a phone. That is why the body size is generous and the measure is
## capped — a letter running the full width of a tablet is harder to read, not
## easier.

const INK: Color = Color(0.13, 0.11, 0.09)
const INK_FADED: Color = Color(0.13, 0.11, 0.09, 0.55)
const PAPER: Color = Color(0.93, 0.90, 0.82)
const PAPER_HANDLED: Color = Color(0.85, 0.82, 0.75)
const DESK_WOOD: Color = Color(0.22, 0.15, 0.11)
const SEAL: Color = Color(0.55, 0.13, 0.13)

## The map. Terrain colours are content (`data/terrain/`); these are the marks
## the map draws over them, which are not.
const MAP_DARK: Color = Color(0.07, 0.08, 0.10)
const MAP_UNKNOWN: Color = Color(0.16, 0.16, 0.18)
const MAP_BORDER: Color = Color(0.93, 0.85, 0.55, 0.85)
const MAP_WORKED: Color = Color(0.93, 0.90, 0.82, 0.55)
const MAP_IMPROVED: Color = Color(0.85, 0.62, 0.30, 0.9)
const MAP_TOWN: Color = Color(0.90, 0.24, 0.20)

## Ground a village works, the village itself, and ground both it and a town lay
## claim to (#205).
##
## **A village is not drawn as a smaller town.** Different colour, different
## shape — the player should never mistake one for a settlement he can write to,
## because there is nobody there to write to.
const MAP_NATIVE: Color = Color(0.42, 0.72, 0.55, 0.55)
const MAP_VILLAGE: Color = Color(0.36, 0.78, 0.58)
const MAP_CONTESTED: Color = Color(0.95, 0.58, 0.25, 0.9)

## Ground a rival has parked men on (#188). **Not a battle colour** — nothing is
## burning and nobody has died; the fields are simply not the colony's to work
## this month, and the map should read as a town diminished rather than attacked.
const MAP_DENIED: Color = Color(0.58, 0.55, 0.62, 0.75)
## Remembered ground is hatched, so it reads as stale even in one colour.
const MAP_STALE: Color = Color(0.0, 0.0, 0.0, 0.35)
## Where something happened this month (#296): the ring map playback leaves on
## a tile, and the brighter one on the beat being shown.
const MAP_BEAT: Color = Color(0.98, 0.93, 0.70, 0.55)
const MAP_BEAT_NOW: Color = Color(1.0, 0.97, 0.80, 0.95)

## The Ledger. In and out are separate colours rather than one net line,
## because a net line hides whether a bad month was a collapse in trade or a
## spree.
const LEDGER_IN: Color = Color(0.26, 0.45, 0.27)
const LEDGER_OUT: Color = Color(0.60, 0.20, 0.17)

## Type sizes, in the order they matter: the letter first.
const SIZE_BODY: int = 20
const SIZE_LABEL: int = 17
const SIZE_HEADING: int = 24
const SIZE_SMALL: int = 15

const GUTTER: int = 16
const GAP: int = 10

## Touch targets. Anything the player taps is at least this tall, which is also
## what makes the options reachable one-handed in portrait.
const TAP_HEIGHT: int = 48

## Below this width the layout is portrait: options overlay the bottom of the
## letter. Above it they sit beside the letter instead.
const PORTRAIT_MAX_WIDTH: int = 700

## The letter column never grows past this, however wide the window.
const LETTER_MEASURE: int = 560


static func is_portrait(size: Vector2) -> bool:
	return size.x < float(PORTRAIT_MAX_WIDTH)


## A filled panel in one of the desk's colours.
static func panel(colour: Color, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = GUTTER
	style.content_margin_right = GUTTER
	style.content_margin_top = GAP
	style.content_margin_bottom = GAP
	return style


## What a designed size actually draws at (#353, SPEC §15).
##
## 🔒 **One place, so every screen moves together.** Text is the main medium and
## must be comfortable to read at length on a phone (`CLAUDE.md`), so the text
## size in options is not a setting one screen honours — every label and every
## button in the game is built through the two helpers below, and both ask here.
##
## Rounded, and never below a size a phone can render: a scale that produced a
## fractional or a two-pixel font would be a setting that broke the game rather
## than one that made it easier to read.
static func scaled(size: int) -> int:
	return maxi(8, int(round(float(size) * Settings.text_scale())))


static func label(text: String, size: int = SIZE_LABEL, colour: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", scaled(size))
	node.add_theme_color_override("font_color", colour)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


## A button sized for a thumb and reachable by keyboard.
##
## **Every screen works with touch and with mouse and keyboard** (SPEC §15), so
## nothing here is mouse-only: focus is on, the target is tap-sized, and the
## label wraps rather than being clipped.
static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	# **The target grows with the text**, because a player who needs larger words
	# usually needs a larger thing to press as well.
	node.custom_minimum_size = Vector2(0, scaled(TAP_HEIGHT))
	node.focus_mode = Control.FOCUS_ALL
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", scaled(SIZE_LABEL))
	return node


static func spacer(height: int = GAP) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	return node
