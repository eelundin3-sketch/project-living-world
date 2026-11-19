extends RefCounted
## Deterministic, map-wide unique American/British personal names.
## Uniqueness is tracked in state.names_used so every settlement shares one pool.
const FIRST: Array[String] = ["Adam", "Alice", "Amelia", "Arthur", "Beatrice", "Benjamin", "Charlotte", "Charles", "Clara", "Daniel", "Daisy", "Edward", "Eleanor", "Emily", "Ethan", "Eliza", "Frances", "Frederick", "George", "Grace", "Hannah", "Harold", "Henry", "Hazel", "Isaac", "Iris", "Jack", "James", "Jane", "Joseph", "Josephine", "Katherine", "Lily", "Louis", "Lucy", "Margaret", "Martha", "Matthew", "Nathaniel", "Nora", "Oliver", "Olivia", "Oscar", "Penelope", "Philip", "Rose", "Rupert", "Samuel", "Sarah", "Sophia", "Stanley", "Thomas", "Victoria", "Violet", "Walter", "William", "Winifred", "Wesley", "Ruth", "Ezra"]
const LAST: Array[String] = ["Ashford", "Baker", "Barrett", "Bennett", "Brooks", "Carter", "Chapman", "Clarke", "Cooper", "Davies", "Dawson", "Ellis", "Fletcher", "Foster", "Gibson", "Graham", "Harper", "Hayes", "Holland", "Hughes", "Jenkins", "Kemp", "Lambert", "Marshall", "Mason", "Miller", "Mitchell", "Morgan", "Nash", "Osborne", "Palmer", "Parker", "Pearson", "Powell", "Reed", "Roberts", "Russell", "Sanders", "Shaw", "Stewart", "Talbot", "Taylor", "Thornton", "Turner", "Walker", "Warren", "Watson", "Webb", "Whitaker", "Wilkins", "Wood", "Wright", "Young", "Abbott", "Bishop", "Cole", "Dixon", "Garner", "Hale", "Pritchard"]

static func used(s: Dictionary) -> Dictionary:
	if not s.has("names_used"):
		s.names_used = {}
	return s.names_used

## Draws from the "names" RNG stream; never calls global random functions.
static func generate(sim: RefCounted) -> String:
	var taken: Dictionary = used(sim.state)
	for attempt in range(400):
		var candidate: String = FIRST[sim.random_int("names", 0, FIRST.size() - 1)] + " " + LAST[sim.random_int("names", 0, LAST.size() - 1)]
		if not taken.has(candidate):
			taken[candidate] = true
			return candidate
	# Pool nearly exhausted: a middle initial keeps the name unique and deterministic.
	for initial in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		for first in FIRST:
			for last in LAST:
				var candidate: String = "%s %s. %s" % [first, initial, last]
				if not taken.has(candidate):
					taken[candidate] = true
					return candidate
	return "Unnamed %d" % taken.size()

static func release(s: Dictionary, name_value: String) -> void:
	used(s).erase(name_value)

## Registers names already stored on older saves so new characters never repeat them.
static func upgrade(s: Dictionary) -> void:
	var taken: Dictionary = used(s)
	for entity in s.entities.values():
		if entity.get("kind", "") in ["resident", "player"]:
			taken[entity.name] = true
