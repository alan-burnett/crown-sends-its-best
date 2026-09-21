class_name Geography
extends RefCounted

## Two continuous fields, and the country falls out of them (#271,
## SPEC §11.1, §16.1; `docs/mechanics/map.md` §2).
##
## ## 🔒 Nothing is placed
##
## What shipped was a **per-tile weighted draw**, every tile rolled independently
## of its neighbours. That does not make country, it makes **confetti**: a
## mountain beside a desert beside a forest, no ranges, no regions, and a desert
## that is five per cent of everywhere rather than a place.
##
## | Field | Reads as |
## | :--- | :--- |
## | **elevation** | high ground is mountains; the sea floor is ocean |
## | **moisture** | dry is desert, open country is grassland and plains, wet is forest |
##
## **A ridge of mountains is a ridge because elevation runs in ridges.** The
## seven terrains are read off two numbers and their arrangement is a consequence
## rather than an authoring job.
##
## ## 🔒 Rain shadow, which is why a desert is where it is
##
## **Moisture falls away behind high ground.** That one rule gives the driest
## country a reason to sit where it does — inland, in the lee of the weather —
## instead of appearing as scattered tiles nobody can explain, and it hands the
## map its shape for nothing: **wet coasts, a spine, dry country behind.**
##
## ## 🔒 And regions are not uniform
##
## Where the moisture field dips inside a wet region the terrain dips with it, so
## **a forest has grassland dotted through it** without anybody authoring
## clearings. A little noise on both fields is the whole of it — homogeneous
## patches read as a map editor and mixed ones read as country.
##
## ## The value-noise, and why it is hand-rolled
##
## Godot's `FastNoiseLite` is a Node-free `Resource` and would work, but its
## output is not guaranteed stable across engine versions, and §16.1 locks that
## the same seed produces the same world. So the lattice is drawn from the
## `mapgen` stream and interpolated here, where the arithmetic is ours and a
## Godot upgrade cannot quietly reshape every map in the game.

## How far a feature runs, in tiles, before the field turns over.
##
## 🔒 **Tuned to make a 34 by 26 grid read as a continent** — how far a ridge
## runs, how wide a desert gets. **Not tuned to a town's influence area**: where
## a town lands and what it can reach are consequences of the map, never a target
## the map aims at.
const ELEVATION_SCALE: float = 9.0
const MOISTURE_SCALE: float = 11.0

## The finer lattice laid over each, at a fraction of the weight. What keeps a
## region from being a blob.
const DETAIL_SCALE: float = 3.5
const DETAIL_WEIGHT: float = 0.3

## Where each terrain begins, as a share of the field. Tuning.
const MOUNTAIN_ABOVE: float = 0.72
const DESERT_BELOW: float = 0.3
const FOREST_ABOVE: float = 0.62
const GRASSLAND_ABOVE: float = 0.46

## How far the lee of high ground reaches, and how hard it dries.
##
## 🔒 **Westward**, because the weather has to come from somewhere and a
## direction chosen once is a direction the whole map agrees about. Tuning.
const SHADOW_REACH: int = 6
const SHADOW_STRENGTH: float = 0.85

## Where ground is high enough to take the rain out of the air.
##
## **Below the mountain threshold on purpose.** Tying it to `MOUNTAIN_ABOVE`
## meant only painted mountains shaded anything, and a range is not a wall that
## begins abruptly — the foothills climbing to it are already in the way. With
## the shade starting at the peaks the lee bias measured eleven per cent across
## two hundred seeds, which is not a rain shadow, it is a rounding error.
const SHADOW_FROM: float = 0.5

var width: int = 0
var height: int = 0

var elevation: PackedFloat32Array = PackedFloat32Array()
var moisture: PackedFloat32Array = PackedFloat32Array()


## Draw both fields for a grid. `rng` must be the `mapgen` stream.
static func of(rng: RandomNumberGenerator, width: int, height: int) -> Geography:
	var country := Geography.new()
	country.width = width
	country.height = height

	# **Elevation first**, because moisture is read in its lee.
	country.elevation = _field(rng, width, height, ELEVATION_SCALE)
	country.moisture = _field(rng, width, height, MOISTURE_SCALE)
	country._dry_the_lee()
	return country


func at(x: int, y: int) -> int:
	return y * width + x


func elevation_at(x: int, y: int) -> float:
	return elevation[at(x, y)] if _inside(x, y) else 0.0


func moisture_at(x: int, y: int) -> float:
	return moisture[at(x, y)] if _inside(x, y) else 0.0


func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## What terrain these two numbers make, on land.
##
## 🔒 **Read, never rolled.** There is no `rng` in this signature and there must
## not be: a tile whose terrain depended on a die would be a tile that could
## differ from its neighbours for no reason anybody could see, which is the
## confetti this ticket exists to remove.
func terrain_at(x: int, y: int) -> StringName:
	var high := elevation_at(x, y)
	if high >= MOUNTAIN_ABOVE:
		return &"mountains"

	var wet := moisture_at(x, y)
	if wet <= DESERT_BELOW:
		return &"desert"
	if wet >= FOREST_ABOVE:
		return &"forest"
	if wet >= GRASSLAND_ABOVE:
		return &"grassland"
	return &"plains"


## Moisture falls away behind high ground.
##
## Each tile is dried by the highest ground within reach to windward of it, so a
## range casts a shadow the length of the range rather than one tile of dryness
## per mountain. Walked west to east in one pass, which is why the direction has
## to be fixed rather than drawn.
func _dry_the_lee() -> void:
	for y in height:
		for x in width:
			var upwind := 0.0
			for back in range(1, SHADOW_REACH + 1):
				var from := x - back
				if from < 0:
					break
				# Further upwind is weaker, so a distant range shades less than
				# the one you are standing behind.
				var falls := 1.0 - float(back - 1) / float(SHADOW_REACH)
				upwind = maxf(upwind, elevation_at(from, y) * falls)

			var shade := maxf(0.0, upwind - SHADOW_FROM) / maxf(0.0001, 1.0 - SHADOW_FROM)
			moisture[at(x, y)] = clampf(
				moisture[at(x, y)] * (1.0 - SHADOW_STRENGTH * clampf(shade, 0.0, 1.0)),
				0.0, 1.0)


## One field: a coarse lattice for the shape, a finer one for the grain.
static func _field(
	rng: RandomNumberGenerator,
	width: int,
	height: int,
	scale: float,
) -> PackedFloat32Array:
	var coarse := _lattice(rng, width, height, scale)
	var detail := _lattice(rng, width, height, DETAIL_SCALE)

	var out := PackedFloat32Array()
	out.resize(width * height)
	var lowest := 1.0e30
	var highest := -1.0e30
	for y in height:
		for x in width:
			var value := _sample(coarse, width, height, scale, x, y) * (1.0 - DETAIL_WEIGHT) \
				+ _sample(detail, width, height, DETAIL_SCALE, x, y) * DETAIL_WEIGHT
			out[y * width + x] = value
			lowest = minf(lowest, value)
			highest = maxf(highest, value)

	# **Stretched across the whole range**, so the thresholds above mean the same
	# thing on every seed. Without it a flat draw gives a map with no mountains
	# at all and a lively one gives a map of nothing else.
	var spread := maxf(0.0001, highest - lowest)
	for index in out.size():
		out[index] = (out[index] - lowest) / spread
	return out


## The random lattice a field is interpolated from.
static func _lattice(
	rng: RandomNumberGenerator,
	width: int,
	height: int,
	scale: float,
) -> PackedFloat32Array:
	var across := int(ceilf(float(width) / scale)) + 2
	var down := int(ceilf(float(height) / scale)) + 2
	var points := PackedFloat32Array()
	points.resize(across * down)
	# Row by row in a fixed order, so the same seed draws the same country
	# however the grid is sized.
	for index in points.size():
		points[index] = rng.randf()
	return points


## Smoothly interpolated between the four lattice points around a tile.
static func _sample(
	points: PackedFloat32Array,
	width: int,
	_height: int,
	scale: float,
	x: int,
	y: int,
) -> float:
	var across := int(ceilf(float(width) / scale)) + 2
	var gx := float(x) / scale
	var gy := float(y) / scale
	var x0 := int(floorf(gx))
	var y0 := int(floorf(gy))

	var fx := _smooth(gx - float(x0))
	var fy := _smooth(gy - float(y0))

	var top := lerpf(
		_point(points, across, x0, y0), _point(points, across, x0 + 1, y0), fx)
	var bottom := lerpf(
		_point(points, across, x0, y0 + 1), _point(points, across, x0 + 1, y0 + 1), fx)
	return lerpf(top, bottom, fy)


static func _point(points: PackedFloat32Array, across: int, x: int, y: int) -> float:
	var index := y * across + x
	return points[index] if index >= 0 and index < points.size() else 0.5


## Smoothstep, so the lattice does not show as a grid of creases.
static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
