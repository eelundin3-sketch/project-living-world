extends RefCounted
## What people wear: a hat, vest, shirt, trousers and boots, each a variant of its kind ("hat:1").
## A person with no stored outfit wears the default their id implies, so nothing needs migrating;
## the outfit is stored (copy on write) only once somebody changes it. Pieces are real inventory
## items when carried, so stealing clothes moves actual goods and conservation still holds.
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const SLOTS: Array[String] = ["hat", "vest", "shirt", "pants", "boots"]
const SLOT_NAMES := {"hat": "Hat", "vest": "Vest", "shirt": "Shirt", "pants": "Trousers", "boots": "Boots"}
const NAMES := {
	"hat": ["Sun hat", "Brown hat", "Dark hat"],
	"vest": ["Olive vest", "Drab vest", "Rust vest", "Moss vest"],
	"shirt": ["Cream shirt", "Tan shirt", "Sage shirt", "Sand shirt"],
	"pants": ["Tan trousers", "Grey trousers", "Dark trousers"],
	"boots": ["Brown boots", "Black boots"]}
const COLORS := {
	"hat": [Color("d3a35a"), Color("bf9558"), Color("4f453a")],
	"vest": [Color("968057"), Color("887b57"), Color("a07551"), Color("8c9371")],
	"shirt": [Color("d7d0ad"), Color("c8b086"), Color("a5ab8c"), Color("d5bc91")],
	"pants": [Color("b58c54"), Color("7d7f78"), Color("4a463d")],
	"boots": [Color("694722"), Color("2c2823")]}
## What shows when a piece is missing: pale long underwear for body and legs, bare feet, no hat.
const UNDERWEAR := Color("e4ddca")

static func key(slot: String, variant: int) -> String:
	return "%s:%d" % [slot, variant]

static func slot_of(item: String) -> String:
	var slot: String = item.get_slice(":", 0)
	return slot if item.contains(":") and SLOTS.has(slot) else ""

static func is_clothing(item: String) -> bool:
	return not slot_of(item).is_empty()

static func variant_of(item: String) -> int:
	return int(item.get_slice(":", 1)) if item.contains(":") else 0

static func label(item: String) -> String:
	var slot := slot_of(item)
	if slot.is_empty(): return item.capitalize()
	var names: Array = NAMES[slot]
	return names[variant_of(item) % names.size()]

static func color(item: String, fallback: Color = UNDERWEAR) -> Color:
	var slot := slot_of(item)
	if slot.is_empty(): return fallback
	var colors: Array = COLORS[slot]
	return colors[variant_of(item) % colors.size()]

## The outfit implied by an id: matches the look people had before outfits existed.
static func default_for(id: int, player: bool = false) -> Dictionary:
	var hatless: bool = not player and posmod(id, 4) == 1
	return {"hat": "" if hatless else key("hat", 0 if player else 1 + posmod(id, 2)),
		"vest": key("vest", 0 if player else posmod(id, 4)), "shirt": key("shirt", 0 if player else posmod(id, 4)),
		"pants": key("pants", 0), "boots": key("boots", 0)}

static func worn(s: Dictionary, id: int) -> Dictionary:
	var stored: Dictionary = s.get("outfits", {}).get(str(id), {})
	return stored if not stored.is_empty() else default_for(id, id == s.get("player", -1))

static func _store(s: Dictionary, id: int, outfit: Dictionary) -> void:
	if not s.has("outfits"): s.outfits = {}
	s.outfits[str(id)] = outfit

## Takes the piece off `id` into `taker`'s inventory. Returns the item, or "" if nothing was worn.
static func strip(s: Dictionary, id: int, slot: String, taker: int) -> String:
	var outfit: Dictionary = worn(s, id).duplicate()
	var item: String = str(outfit.get(slot, ""))
	if item.is_empty() or Inventory.available(s, taker) < 1: return ""
	outfit[slot] = ""
	_store(s, id, outfit)
	Inventory.produce(s, taker, item, 1)
	return item

## Puts a carried piece on `id`; whatever was in that slot goes back into their pack.
static func wear(s: Dictionary, id: int, item: String) -> String:
	var slot := slot_of(item)
	if slot.is_empty() or Inventory.amount(s, id, item) < 1: return ""
	var outfit: Dictionary = worn(s, id).duplicate()
	var previous: String = str(outfit.get(slot, ""))
	Inventory.consume(s, id, item, 1)
	if not previous.is_empty(): Inventory.produce(s, id, previous, 1)
	outfit[slot] = item
	_store(s, id, outfit)
	return item

static func take_off(s: Dictionary, id: int, slot: String) -> String:
	return strip(s, id, slot, id)

static func describe(s: Dictionary, id: int) -> String:
	var parts: Array = []
	var outfit: Dictionary = worn(s, id)
	for slot in SLOTS:
		if not str(outfit.get(slot, "")).is_empty(): parts.append(label(outfit[slot]).to_lower())
	return ", ".join(parts) if not parts.is_empty() else "only underclothes"
