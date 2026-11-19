extends RefCounted
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const PARTS: Array[String] = ["head","neck","upper_torso","lower_torso","groin","left_upper_arm","right_upper_arm","left_forearm","right_forearm","left_hand","right_hand","left_thigh","right_thigh","left_shin","right_shin","left_foot","right_foot"]
static func initialize(s: Dictionary) -> void:
	if s.has("player_health") or not s.has("player"): return
	var parts: Dictionary = {}
	for part in PARTS:
		parts[part]={"damage":0,"wound":"none","bleeding":false,"bandage":"none","bandage_until":0,"infection":0}
	s.player_health={"parts":parts,"treatment":{},"notice":"No injuries. Select a body part to examine it.","stamina":100,"stamina_max":100,"stamina_clock":0}
	Inventory.produce(s,s.player,"bandage",6)
	Inventory.produce(s,s.player,"antiseptic",2)
	for town in s.get("settlements",{}).values():
		if Inventory.available(s,town.warehouse)<42: s.inventories[str(town.warehouse)].capacity+=42-Inventory.available(s,town.warehouse)
		Inventory.produce(s,town.warehouse,"bandage",30)
		Inventory.produce(s,town.warehouse,"antiseptic",12)
## Stamina: at or below WINDED_AT (the orange part of the bar) the body is fatigued and breathing hard;
## the winded state lasts until stamina climbs back to RECOVER_AT (halfway).
const WINDED_AT := 20
const RECOVER_AT := 50
## Vital parts weigh more in the health bar, so a beating to the head and body shows quickly.
const WEIGHTS := {"head": 3.0, "neck": 2.0, "upper_torso": 2.0, "lower_torso": 1.5}
static func overall(s: Dictionary) -> int:
	var damage: float = 0.0
	for part in PARTS: damage+=float(s.player_health.parts[part].damage)*float(WEIGHTS.get(part,1.0))
	return clampi(100-roundi(damage/4.0),0,100)
## Someone who comes round after being knocked out is battered but not at death's door.
static func revive(s: Dictionary, floor_value: int = 25) -> void:
	if not s.has("player_health"): return
	var guard := 0
	while overall(s)<floor_value and guard<60:
		for part in s.player_health.parts.values(): part.damage=maxi(0,part.damage-3)
		guard+=1
static func is_winded(s: Dictionary) -> bool:
	return s.has("player_health") and bool(s.player_health.get("winded",false))
static func pain(s: Dictionary) -> int:
	var pain_value: int = 0
	for part in s.player_health.parts.values(): pain_value+=part.damage/3+part.infection/4
	return mini(100,pain_value)
static func incapacitated(s: Dictionary) -> bool:
	return s.has("player_health") and (overall(s)<15 or s.player_health.parts.head.damage>=95 or s.player_health.parts.upper_torso.damage>=95)
static func move_delay(s: Dictionary) -> int:
	if not s.has("player_health"): return 1
	var damage: int = 0
	for part in ["left_thigh","right_thigh","left_shin","right_shin","left_foot","right_foot"]: damage+=s.player_health.parts[part].damage
	return 3 if damage>=100 else (2 if damage>=35 else 1)
static func injure(s: Dictionary, part: String, amount: int, kind: String = "cut") -> bool:
	if not s.has("player_health") or not PARTS.has(part) or kind not in ["cut","bruise","sprain"]: return false
	var body: Dictionary=s.player_health.parts[part]
	body.damage=clampi(body.damage+clampi(amount,1,60),0,100)
	body.wound=kind
	body.bleeding=kind=="cut"
	if body.bandage!="none": body.bandage="dirty"
	s.player_health.notice="%s: %s. Press H to examine and treat." % [part.replace("_"," ").capitalize(),kind]
	# Hit while carrying something in your hands: you lose your grip (it stays in your pack).
	var control: Dictionary = s.get("player_control", {})
	if not str(control.get("held_item", "")).is_empty():
		control.held_item = ""
		control.held_quantity = 0
		control.notice = "The blow knocks what you were carrying out of your hands."
	return true
static func treatment_problem(s: Dictionary, part: String, action: String) -> String:
	if not PARTS.has(part) or action not in ["bandage", "disinfect", "remove"]: return "Unknown treatment."
	var health: Dictionary = s.player_health
	if not health.treatment.is_empty(): return "A treatment is already in progress."
	var body: Dictionary = health.parts[part]
	if action == "remove":
		return "There is no bandage to remove." if body.bandage == "none" else ""
	if body.damage == 0 and body.infection == 0: return "This body part does not need treatment."
	if action == "bandage" and body.bandage == "clean": return "The bandage is still clean."
	if action == "disinfect" and body.bandage != "none": return "Remove the bandage before cleaning the wound."
	var supply := "bandage" if action == "bandage" else "antiseptic"
	if Inventory.amount(s, s.player, supply) < 1: return "You need " + supply + " in your inventory."
	return ""

static func begin(s: Dictionary, part: String, action: String) -> bool:
	if not PARTS.has(part) or action not in ["bandage", "disinfect", "remove"]: return false
	var health: Dictionary = s.player_health
	var knock: Dictionary = s.get("player_control", {}).get("knock", {})
	if not knock.is_empty() and s.tick < int(knock.get("rise_until", 0)):
		health.notice = "You are unconscious and cannot treat your wounds."
		return false
	var problem := treatment_problem(s, part, action)
	if not problem.is_empty():
		health.notice = problem
		return false
	health.treatment={"part":part,"action":action,"start":s.tick,"finish":s.tick+(12 if action=="remove" else (36 if action=="bandage" else 24)),"cell":s.entities[str(s.player)].cell.duplicate()}
	health.notice="Treating %s. Stay still; moving cancels treatment." % part.replace("_"," ")
	return true
static func update(s: Dictionary) -> void:
	if not s.has("player_health"): return
	var health: Dictionary=s.player_health
	if not health.treatment.is_empty():
		var treatment: Dictionary=health.treatment
		if s.entities[str(s.player)].cell!=treatment.cell:
			health.treatment={}; health.notice="Treatment cancelled by movement. No supplies used."
		elif s.tick>=treatment.finish:
			var body: Dictionary=health.parts[treatment.part]
			var supply: String="bandage" if treatment.action=="bandage" else "antiseptic"
			if treatment.action=="remove" or Inventory.consume(s,s.player,supply,1):
				match treatment.action:
					"bandage": body.bandage="clean"; body.bandage_until=s.tick+1200; body.bleeding=false
					"disinfect": body.infection=maxi(0,body.infection-50); body.damage=maxi(0,body.damage-2)
					"remove": body.bandage="none"; body.bleeding=body.wound=="cut" and body.damage>10
				health.notice="Treatment complete."
			else: health.notice="Treatment cancelled: supply no longer available."
			health.treatment={}
	var running: bool=s.get("player_control",{}).get("running",false) and s.get("player_control",{}).get("running_tick",-1)==s.tick
	if running and s.player_health.stamina>0:
		s.player_health.stamina_clock=0
	else:
		s.player_control.running=false
		s.player_health.stamina_clock+=1
		if s.player_health.stamina_clock>=3:
			s.player_health.stamina_clock=0
			s.player_health.stamina=mini(s.player_health.stamina_max,s.player_health.stamina+1)
	if health.stamina<=WINDED_AT: health.winded=true
	elif health.stamina>=RECOVER_AT:
		health.winded=false
		health.exhausted=false
	if s.tick%100!=0: return
	for part in health.parts.values():
		if part.bandage=="clean" and s.tick>=part.bandage_until: part.bandage="dirty"
		if part.damage>0:
			if part.bandage=="dirty": part.infection=mini(100,part.infection+2)
			if part.bleeding: part.damage=mini(100,part.damage+1)
			elif part.infection>=30: part.damage=mini(100,part.damage+1)
			elif part.bandage=="clean" or (part.wound!="cut" and s.tick%200==0): part.damage=maxi(0,part.damage-1)
		if part.damage==0:
			part.wound="none"; part.bleeding=false
static func validate(s: Dictionary) -> String:
	if not s.has("player_health"): return ""
	if not s.player_health is Dictionary or not s.player_health.get("stamina") is int or not s.player_health.get("stamina_max") is int or not s.player_health.get("stamina_clock") is int or s.player_health.stamina<0 or s.player_health.stamina>s.player_health.stamina_max or s.player_health.stamina_max<1 or s.player_health.stamina_clock<0 or s.player_health.stamina_clock>2 or not s.player_health.get("parts") is Dictionary or not s.player_health.get("treatment") is Dictionary: return "Invalid player health"
	for key in PARTS:
		var part: Variant=s.player_health.parts.get(key)
		if not part is Dictionary: return "Missing body part"
		for field in ["damage","infection","bandage_until"]:
			if not part.get(field) is int or part[field]<0: return "Invalid body-part value"
		if part.damage>100 or part.infection>100 or part.get("wound") not in ["none","cut","bruise","sprain"] or part.get("bandage") not in ["none","clean","dirty"] or not part.get("bleeding") is bool: return "Invalid injury state"
	var t: Dictionary=s.player_health.treatment
	if not t.is_empty() and (not PARTS.has(t.get("part","")) or t.get("action","") not in ["bandage","disinfect","remove"] or not t.get("finish") is int or not t.get("cell") is Array or t.cell.size()!=2): return "Invalid treatment"
	return ""
