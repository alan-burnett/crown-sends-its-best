class_name Figures
extends RefCounted

## Numbers as the player reads them. Shared by the letters, the cutscenes and
## the summary, so a head count reads the same wherever it is printed.


## `1234567` -> `1,234,567`.
static func with_thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## 🔒 **How many souls a population is** (`Config.PEOPLE_PER_POPULATION`).
static func headcount(population: float) -> int:
	return int(roundf(population * float(Config.PEOPLE_PER_POPULATION)))


## A population written as the people it stands for: `2.4` -> `2,400`.
static func people(population: float) -> String:
	return with_thousands(headcount(population))


# --- 🔒 How large figures read (#437, `population.md` §7, the Author's ruling) --

## Below this, a figure prints exact whoever writes (§7, ⚠ assumed there).
const EXACT_BELOW: int = 100

## Counted heads, rounded to the nearest ten: what a town's own governor and the
## Steward write. `3933` -> `3,930`.
static func counted(people: int) -> String:
	if absi(people) < EXACT_BELOW:
		return str(people)
	return with_thousands(int(roundf(float(people) / 10.0)) * 10)


## An estimate in words: what everybody else writes, and what a cutscene paints.
## One significant figure below ten thousand, two above, **hedged by which side
## of the truth it fell**: *nearly* when the true figure is below the rounded
## one, *some* when it is at or above it. `3933` -> `nearly four thousand`;
## `45200` -> `some forty-five thousand`.
static func estimated(people: int) -> String:
	var n := absi(people)
	if n < EXACT_BELOW:
		return str(people)
	var figures := 1 if n < 10_000 else 2
	# From the digit count, not a logarithm: a float log misjudges an exact power
	# of ten.
	var magnitude := 1
	for _digit in maxi(0, str(n).length() - figures):
		magnitude *= 10
	var rounded := int(roundf(float(n) / float(magnitude))) * magnitude
	var hedge := "nearly" if n < rounded else "some"
	return "%s %s" % [hedge, in_words(rounded)]


## A whole number in words, as a letter writes it: `45000` -> `forty-five
## thousand`, `1200000` -> `one million two hundred thousand`.
static func in_words(value: int) -> String:
	if value == 0:
		return "none"
	var parts: PackedStringArray = PackedStringArray()
	var millions := value / 1_000_000
	var thousands := (value / 1_000) % 1_000
	var rest := value % 1_000
	if millions > 0:
		parts.append(_under_a_thousand(millions) + " million")
	if thousands > 0:
		parts.append(_under_a_thousand(thousands) + " thousand")
	if rest > 0:
		parts.append(_under_a_thousand(rest))
	return " ".join(parts)


const _UNITS: PackedStringArray = [
	"", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
	"eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
]
const _TENS: PackedStringArray = [
	"", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
]


static func _under_a_thousand(value: int) -> String:
	var words: PackedStringArray = PackedStringArray()
	if value >= 100:
		words.append(_UNITS[value / 100] + " hundred")
		value %= 100
		if value > 0:
			words.append("and")
	if value >= 20:
		words.append(_TENS[value / 10] + ("-" + _UNITS[value % 10] if value % 10 > 0 else ""))
	elif value > 0:
		words.append(_UNITS[value])
	return " ".join(words)
