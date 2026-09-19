class_name StableHash
extends RefCounted

## A hash we own, so determinism is our guarantee rather than the engine's.
##
## SPEC §16.1 locks seeded generation, and the game ships on desktop and mobile
## (§16.1), so "the same seed yields the same Marshal" has to hold across both.
## GDScript's built-in `hash()` is not documented as stable across engine
## versions or platforms, so nothing that affects a run may call it.
##
## FNV-1a, 32-bit. Every intermediate stays under 2^56, well inside int64, so
## there is no overflow and no reliance on wrapping behaviour. 32 bits is ample
## for stream derivation: with a few dozen contacts the collision probability is
## around 3e-7, and a collision would only mean two contacts share a stream.

const FNV_OFFSET_BASIS_32: int = 0x811C9DC5
const FNV_PRIME_32: int = 0x01000193
const MASK_32: int = 0xFFFFFFFF


## FNV-1a over the UTF-8 bytes of `text`. Returns 0 .. 2^32-1.
static func of_string(text: String) -> int:
	var hash_value: int = FNV_OFFSET_BASIS_32
	for byte in text.to_utf8_buffer():
		hash_value ^= byte
		hash_value = (hash_value * FNV_PRIME_32) & MASK_32
	return hash_value


## The seed for a named stream in a given run.
##
## Composing the key as text before hashing keeps this obviously deterministic
## and avoids any integer mixing step that could overflow.
static func stream_seed(run_seed: int, key: String) -> int:
	return of_string("%d:%s" % [run_seed, key])
