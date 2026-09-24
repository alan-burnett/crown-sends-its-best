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
