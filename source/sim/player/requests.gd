extends RefCounted
## Requests and favours: people ask for what they really lack. Each morning a town may raise a few
## requests from real needs: a family with an empty pantry wants bread (they pay half again over
## the market price from the family purse); a sheriff's office short of bandages wants some (the
## town pays). Ask "Can I help with anything?" to hear it, agree, bring it, and hand it over; you're
## paid, they remember it kindly, and word gets round. Miss the deadline (two days) and they're
## let down. At most MAX_OPEN open requests per town.
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Society = preload("res://sim/factions/society.gd")
const DAY := 14400
const MAX_OPEN := 3
const DEADLINE_DAYS := 2

static func all(s: Dictionary) -> Dictionary:
	if not s.has("requests"): s.requests = {}
	return s.requests

static func _purse_of(s: Dictionary, npc: Dictionary) -> String:
	var key: String = "household:" + str(npc.get("household", ""))
	return key if s.get("accounts", {}).has(key) else str(npc.id)

## Once a day per town: new requests from real shortages.
static func daily(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	var Market = load("res://sim/economy/market.gd")
	var Households = load("res://sim/entities/households.gd")
	for id in all(s).keys():
		var request: Dictionary = s.requests[id]
		if str(request.state) in ["open", "accepted"] and int(s.tick) > int(request.deadline):
			if str(request.state) == "accepted":
				Society.remember(s, int(request.giver), "insulted", int(s.player), "The stranger promised to help and didn't.")
			request.state = "failed"
		if str(request.state) in ["done", "failed"] and int(s.tick) - int(request.deadline) > DAY * 3: s.requests.erase(id)
	var towns: Array = s.get("settlements", {}).keys()
	towns.sort()
	for key in towns:
		var town: Dictionary = s.settlements[key]
		var open := 0
		for request in s.requests.values():
			if int(request.town) == int(town.id) and str(request.state) in ["open", "accepted"]: open += 1
		# A family whose pantry is bare.
		var households: Array = s.get("households", {}).keys()
		households.sort()
		for hkey in households:
			if open >= MAX_OPEN: break
			var household: Dictionary = s.households[hkey]
			if int(household.settlement) != int(town.id) or household.members.is_empty() or str(hkey) == "player": continue
			var store: int = Households.pantry(s, household)   # the id of the home's pantry
			if Inventory.amount(s, store, "food") + Inventory.amount(s, store, "rye") / 2 >= 2 or _asked(s, "deliver", int(household.home)): continue
			var giver: Dictionary = s.residents.get(str(household.members[0]), {})
			if giver.is_empty() or int(giver.health) <= 0: continue
			var price: int = maxi(1, Market.quote(s, int(town.id), "food", true))
			_add(s, {"giver": int(giver.id), "kind": "deliver", "item": "food", "qty": 5, "to": int(household.home), "reward": price * 5 * 3 / 2, "town": int(town.id), "purse": _purse_of(s, giver)})
			open += 1
		# The sheriff's office short of bandages.
		var office: int = int(load("res://sim/law/law.gd").office_of(s, int(town.id)).get("id", 0))
		var sheriffs: Array = load("res://sim/law/law.gd").sheriffs(s, int(town.id))
		if open < MAX_OPEN and office != 0 and not sheriffs.is_empty() and Inventory.amount(s, office, "bandage") < 4 and not _asked(s, "supply", office):
			var each: int = maxi(1, Market.quote(s, int(town.id), "bandage", true))
			_add(s, {"giver": int(sheriffs[0].id), "kind": "supply", "item": "bandage", "qty": 4, "to": office, "reward": each * 4 * 3 / 2, "town": int(town.id), "purse": str(town.warehouse)})

static func _asked(s: Dictionary, kind: String, to: int) -> bool:
	for request in s.get("requests", {}).values():
		if str(request.kind) == kind and int(request.to) == to and str(request.state) in ["open", "accepted"]: return true
	return false

static func _add(s: Dictionary, fields: Dictionary) -> void:
	var id: int = int(s.get("requests_next", 1))
	s.requests_next = id + 1
	fields.id = id
	fields.state = "open"
	fields.since = int(s.tick)
	fields.deadline = int(s.tick) + DEADLINE_DAYS * DAY
	all(s)[str(id)] = fields

## The open or accepted request `npc` has of the player, or {}.
static func of(s: Dictionary, npc_id: int) -> Dictionary:
	for request in s.get("requests", {}).values():
		if int(request.giver) == npc_id and str(request.state) in ["open", "accepted"]: return request
	return {}

static func describe(s: Dictionary, request: Dictionary) -> String:
	var what: String = {"food": "bread", "bandage": "bandages"}.get(str(request.item), str(request.item))
	match str(request.kind):
		"deliver": return "Our pantry's bare. Could you bring us %d %s? I'll pay %d coins." % [request.qty, what, request.reward]
		"supply": return "The office is out of bandages. Bring %d and the town pays %d coins." % [request.qty, request.reward]
	return "I could use a hand."

## Talk-tab lines for a person with a request.
static func talk_options(s: Dictionary, npc: Dictionary) -> Array:
	var request: Dictionary = of(s, int(npc.id))
	if request.is_empty(): return [{"id": "ask_help", "label": "Can I help with anything?", "enabled": true, "reason": ""}]
	if str(request.state) == "open":
		return [{"id": "accept_request", "label": "I'll do it. %d %s, you said?" % [request.qty, {"food": "bread", "bandage": "bandages"}.get(str(request.item), request.item)], "enabled": true, "reason": ""}]
	var have: bool = Inventory.amount(s, int(s.player), str(request.item)) >= int(request.qty)
	return [{"id": "hand_over", "label": "Here's what you asked for.", "enabled": have, "reason": "" if have else "You need %d" % request.qty}]

static func perform(sim: RefCounted, npc: Dictionary, action: String) -> String:
	var s: Dictionary = sim.state
	var first: String = String(s.entities[str(npc.id)].name).split(" ")[0]
	var request: Dictionary = of(s, int(npc.id))
	match action:
		"ask_help":
			if request.is_empty(): return "%s: Kind of you, but we're managing." % first
			return "%s: %s" % [first, describe(s, request)]
		"accept_request":
			if request.is_empty(): return ""
			request.state = "accepted"
			return "%s: Thank you! Within two days, if you can." % first
		"hand_over":
			if request.is_empty() or str(request.state) != "accepted": return ""
			if Inventory.amount(s, int(s.player), str(request.item)) < int(request.qty): return "You haven't got enough yet."
			var moved: Dictionary = Inventory.transfer(s, int(s.player), int(request.to), str(request.item), int(request.qty))
			if not moved.ok: return "There's no room for it."
			var purse: String = str(request.purse)
			var paid: int = mini(int(request.reward), int(s.accounts.get(purse, 0)))
			s.accounts[purse] = int(s.accounts.get(purse, 0)) - paid
			s.accounts[str(s.player)] = int(s.accounts.get(str(s.player), 0)) + paid
			request.state = "done"
			var entry: Dictionary = load("res://sim/world/chronicle.gd").record(s, "favour", int(request.town), int(s.player), int(npc.id), s.entities[str(npc.id)].cell)
			Society.witnessed(s, int(npc.id), "helped", int(s.player), "The stranger did us a good turn.", entry.witnesses, "helped")
			return "%s: Bless you! Here's %d coins." % [first, paid]
	return ""
