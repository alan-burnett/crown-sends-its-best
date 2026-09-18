extends Node

## Asset references resolved through an indirection layer, as an autoload
## (`Assets`).
##
## SPEC §16.3: the Author supplies final art, music and sound later, development
## uses placeholders, and swapping them in must not require code changes. So
## nothing outside this file names a file path. Code asks for
## `portrait.marshal`; `data/assets/*.json` says what that currently is; the
## final art lands as a change to that data file.
##
## A missing asset is never fatal. It renders as an obvious placeholder and
## reports once, because losing a run to a typo in an art path would be a poor
## trade (SPEC §16.2 — ironman).

const COLLECTION: String = "assets"
const PATH_KEY: String = "path"

const PLACEHOLDER_SIZE: int = 64
const PLACEHOLDER_COLOUR_A: Color = Color(0.82, 0.16, 0.66)
const PLACEHOLDER_COLOUR_B: Color = Color(0.15, 0.15, 0.18)

var _cache: Dictionary = {}
var _reported_missing: Dictionary = {}
var _placeholder: Texture2D = null

## Where registrations are read from. Defaults to the `Content` autoload; tests
## set their own so they do not depend on autoloads being instantiated.
var content_source: Node = null


func _content() -> Node:
	return content_source if content_source != null else Content


## The resource path registered for `id`, or "" when there is none.
func resolve(id: String) -> String:
	var records: Dictionary = _content().collection(COLLECTION)
	if not records.has(id):
		return ""
	return String(records[id].get(PATH_KEY, ""))


func has(id: String) -> bool:
	return not resolve(id).is_empty()


## Ids currently registered, sorted.
func ids() -> PackedStringArray:
	return _content().ids(COLLECTION)


## A texture for `id`, falling back to the placeholder.
func texture(id: String) -> Texture2D:
	var cached: Variant = _cache.get(id)
	if cached != null:
		return cached
	var loaded: Texture2D = _load(id) as Texture2D
	if loaded == null:
		loaded = placeholder()
	_cache[id] = loaded
	return loaded


## Any resource for `id` — audio, scenes, whatever the reference points at.
func resource(id: String) -> Resource:
	return _load(id)


func _load(id: String) -> Resource:
	var path := resolve(id)
	if path.is_empty():
		_report_missing(id, "not registered in data/%s" % COLLECTION)
		return null
	if not ResourceLoader.exists(path):
		_report_missing(id, "registered path does not exist: %s" % path)
		return null
	return load(path)


func _report_missing(id: String, reason: String) -> void:
	if _reported_missing.has(id):
		return
	_reported_missing[id] = true
	push_warning("Asset '%s' %s. Using placeholder." % [id, reason])


## A generated checkerboard. Generated rather than shipped as a file so that a
## broken asset path cannot cascade into a second broken asset path.
func placeholder() -> Texture2D:
	if _placeholder != null:
		return _placeholder
	var image := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGBA8)
	var half: int = PLACEHOLDER_SIZE / 2
	for y in PLACEHOLDER_SIZE:
		for x in PLACEHOLDER_SIZE:
			var even: bool = ((x / half) + (y / half)) % 2 == 0
			image.set_pixel(x, y, PLACEHOLDER_COLOUR_A if even else PLACEHOLDER_COLOUR_B)
	_placeholder = ImageTexture.create_from_image(image)
	return _placeholder


## Drop cached resources. Used when content reloads during development.
func clear_cache() -> void:
	_cache.clear()
	_reported_missing.clear()
