extends RefCounted
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Recipes = preload("res://sim/production/recipe_system.gd")
const Market = preload("res://sim/economy/market.gd")
const Health = preload("res://sim/player/body_health.gd")
static func initialize(s: Dictionary) -> void:
	if s.has("player_control") or not s.has("player"): return
	s.player_control={"held_item":"","held_quantity":0,"work":{},"notice":"WASD move · I inventory · F interact · H health","ui_target":0,"ui_nonce":0,"next_move":0,"running_tick":0}
	# Personal trade uses actual resident goods and a transfer from the town treasury.
	for npc in s.get("residents",{}).values():
		if s.get("accounts",{}).has(str(npc.id)): continue
		var town: Dictionary=s.get("settlements",{}).get(str(npc.settlement),{})
		if town.is_empty(): continue
		var store: String=str(town.warehouse)
		var funds: int=mini(100,int(s.accounts.get(store,0)))
		s.accounts[store]-=funds; s.accounts[str(npc.id)]=funds
static func distance(a: Array,b: Array) -> int: return absi(a[0]-b[0])+absi(a[1]-b[1])
static func near(s: Dictionary,e: Dictionary) -> bool:
	var p: Array=s.entities[str(s.player)].cell
	if e.kind == "market_stall":
		var stance := World.Fixtures.interaction_cell(s, e.id)
		return p[1] >= stance[1] and distance(p, stance) <= 1
	return distance(p,World.Fixtures.interaction_cell(s,e.id))<=1 or (e.kind in ["warehouse","market"] and distance(p,e.cell)<=2) or (e.kind in ["resident","tree","farm","stash"] and distance(p,e.cell)<=1)
static func target(s: Dictionary, preferred: int = 0) -> int:
	if preferred!=s.player and s.entities.has(str(preferred)) and near(s,s.entities[str(preferred)]): return preferred
	var found: int=0
	var score: int=10000
	for e in s.entities.values():
		if e.kind=="stash" and Inventory.used(s.inventories[str(e.id)])==0: continue
		if e.id==s.player or e.kind not in ["sawmill","warehouse","market","market_stall","construction","stash","resident","tree","farm"] or not near(s,e): continue
		var candidate: int=distance(s.entities[str(s.player)].cell,World.Fixtures.interaction_cell(s,e.id))*10
		candidate+=0 if e.kind in ["sawmill","warehouse","market","market_stall","stash"] else (3 if e.kind=="resident" else 5)
		if candidate<score: score=candidate; found=e.id
	return found
static func hold(s: Dictionary,item: String) -> void:
	var pc: Dictionary=s.player_control
	if not pc.work.is_empty(): pc.notice="Finish or cancel work before changing what you hold."; return
	pc.held_item=item if Inventory.amount(s,s.player,item)>0 else ""
	pc.held_quantity=mini(5,Inventory.amount(s,s.player,item)) if not pc.held_item.is_empty() else 0
	pc.notice="Holding %d %s. F puts it down." % [pc.held_quantity,item] if pc.held_quantity>0 else "Hands empty."
static func reconcile(s: Dictionary) -> void:
	var pc: Dictionary=s.player_control
	pc.held_quantity=mini(pc.held_quantity,Inventory.amount(s,s.player,pc.held_item))
	if pc.held_quantity<=0: pc.held_item=""; pc.held_quantity=0
static func stop(s: Dictionary) -> void:
	var pc: Dictionary=s.player_control
	if not pc.work.is_empty() and pc.work.kind=="saw":
		var ws: Dictionary=s.workshops.get(str(pc.work.target),{})
		if not ws.is_empty(): ws.player_operator=0; ws.status="Player stopped; batch retained"
	pc.work={}
static func interact(sim: RefCounted, preferred: int = 0) -> void:
	var s: Dictionary=sim.state
	var pc: Dictionary=s.player_control
	if not pc.work.is_empty(): stop(s); pc.notice="Stopped working."; return
	if not s.player_health.treatment.is_empty(): pc.notice="Finish treatment first, or move to cancel it."; return
	if Health.incapacitated(s): pc.notice="Too injured to work. Press H to treat your injuries."; return
	reconcile(s)
	var id: int=target(s,preferred)
	var e: Dictionary=s.entities.get(str(id),{})
	if e.get("kind", "") == "market_stall":
		pc.ui_target = id
		pc.ui_nonce += 1
		pc.notice = "Trading at the " + e.name.to_lower()
		return
	if pc.held_quantity>0:
		var destination: int=0
		if not e.is_empty() and e.kind in ["warehouse","market","sawmill","construction","stash"] and s.inventories.has(str(id)): destination=id
		if destination==0:
			var cell: Array=s.entities[str(s.player)].cell
			for existing in s.entities.values():
				if existing.kind=="stash" and existing.cell==cell: destination=existing.id; break
			if destination==0:
				destination=World.add_entity(sim,"stash","Dropped supplies",cell)
				Inventory.create(s,destination,1000)
		var moved := Inventory.transfer(s,s.player,destination,pc.held_item,pc.held_quantity)
		pc.notice="Put down %d %s." % [pc.held_quantity,pc.held_item] if moved.ok else "Cannot put down: "+moved.error_code
		if moved.ok: pc.held_item=""; pc.held_quantity=0
		return
	if e.is_empty(): pc.notice="Move next to an object or person, then press F."; return
	if e.kind in ["resident","warehouse","market"]:
		pc.ui_target=id; pc.ui_nonce+=1; pc.notice="Interacting with "+e.name
	elif e.kind=="stash": take(s,id,first_item(s,id))
	elif e.kind in ["tree","farm"]:
		var item: String="log" if e.kind=="tree" else "food"
		for job in s.jobs.values():
			if job.target==id and job.owner!=0: pc.notice="A villager is already working here."; return
		if Inventory.amount(s,id,item)==0: pc.notice="Nothing left to gather."; return
		pc.work={"kind":"chop" if item=="log" else "harvest","target":id,"item":item,"progress":0,"ticks":20,"cell":s.entities[str(s.player)].cell.duplicate()}
		pc.notice="Working. F stops; moving cancels."
	elif e.kind=="sawmill":
		var ws: Dictionary=s.workshops[str(id)]
		var recipe: Dictionary=ws.get("batch_recipe",s.recipes[ws.recipe])
		if ws.active and ws.get("player_operator",0)==0: pc.notice="The sawyer has an active batch. Try after it finishes."; return
		if Inventory.amount(s,id,recipe.output)>0: take(s,id,recipe.output); return
		if not ws.enabled: pc.notice="This machine is disabled."; return
		if Inventory.amount(s,id,recipe.input)<recipe.input_quantity: pc.notice="Bring %d %s, hold it in I, and press F here to load the machine." % [recipe.input_quantity,recipe.input]; return
		if s.entities[str(s.player)].cell!=World.Fixtures.interaction_cell(s,id): pc.notice="Stand at the operator position below the bench."; return
		for npc in s.residents.values():
			if s.entities[str(npc.id)].cell == s.entities[str(s.player)].cell:
				pc.notice="The sawyer is at the controls. Use the machine when the position is free."; return
		ws.batch_recipe=recipe.duplicate(true); ws.batch_local=true; ws.batch+=1; ws.progress=0; ws.active=true; ws.work_ticks=recipe.work_ticks; ws.player_operator=s.player
		pc.work={"kind":"saw","target":id,"progress":0,"ticks":recipe.work_ticks,"cell":s.entities[str(s.player)].cell.duplicate()}
		pc.notice="Operating the saw. F stops; moving cancels."
	else: pc.notice="No available interaction."
static func first_item(s: Dictionary,id: int) -> String:
	for item in ["log","plank","food","bandage","antiseptic"]:
		if Inventory.amount(s,id,item)>0: return item
	return ""
static func take(s: Dictionary,id: int,item: String) -> void:
	var pc: Dictionary=s.player_control
	if not s.entities.has(str(id)) or not near(s,s.entities[str(id)]) or s.entities[str(id)].kind not in ["stash","sawmill"]: pc.notice="Move closer to collect goods."; return
	if pc.held_quantity>0: pc.notice="Put down or stow what you are holding first."; return
	if s.entities[str(id)].kind=="sawmill":
		var ws: Dictionary=s.workshops[str(id)]
		if ws.active and item==ws.get("batch_recipe",s.recipes[ws.recipe]).input: pc.notice="These inputs belong to an active batch."; return
	var quantity: int=mini(5,mini(Inventory.amount(s,id,item),Inventory.available(s,s.player)))
	var result := Inventory.transfer(s,id,s.player,item,quantity)
	if result.ok: pc.held_item=item; pc.held_quantity=quantity; pc.notice="Picked up %d %s." % [quantity,item]
	else: pc.notice="Cannot pick up: "+result.error_code
static func trade(sim: RefCounted,payload: Dictionary) -> void:
	var s: Dictionary=sim.state
	var pc: Dictionary=s.player_control
	var id: int=int(payload.get("target",0))
	if not s.entities.has(str(id)) or not near(s,s.entities[str(id)]): pc.notice="Move closer to trade."; return
	var e: Dictionary=s.entities[str(id)]
	if e.kind not in ["resident","warehouse","market","market_stall"]: return
	if e.kind=="resident":
		var npc: Dictionary=s.residents[str(id)]
		if npc.job!=0 or npc.get("work_cargo",false) or npc.get("production_delivery",false): pc.notice="They are carrying work supplies and cannot trade right now."; return
	var item: String=payload.get("item","")
	if e.kind == "market_stall" and item not in e.sale_items:
		pc.notice = "This stall does not trade that item."
		return
	var buy: bool=payload.get("buy",true)
	var price: int=Market.quote(s,e.settlement,item,buy)
	var result := Market.transact(s,id if buy else s.player,s.player if buy else id,item,1,price,e.settlement)
	pc.notice="Trade complete." if result.ok else "Trade failed: "+result.error_code
	reconcile(s)
static func update(sim: RefCounted) -> void:
	var s: Dictionary=sim.state
	if not s.has("player_control"): return
	var pc: Dictionary=s.player_control
	reconcile(s)
	if pc.work.is_empty(): return
	var work: Dictionary=pc.work
	if s.entities[str(s.player)].cell!=work.cell or Health.incapacitated(s): stop(s); pc.notice="Work cancelled."; return
	var arms: int=0
	for part in ["left_hand","right_hand","left_forearm","right_forearm"]: arms+=s.player_health.parts[part].damage
	if arms>=40 and s.tick%2!=0: return
	if work.kind=="saw":
		var ws: Dictionary=s.workshops.get(str(work.target),{})
		if ws.is_empty() or not ws.enabled: stop(s); pc.notice="Machine unavailable."; return
		ws.progress+=1; work.progress=ws.progress; ws.status="Player operating saw"
		if Recipes.finish(s,ws):
			if sim.random_int("player:work_accident",0,7)==0:
				var part: String=["left_hand","right_hand","left_forearm","right_forearm"][sim.random_int("player:work_accident",0,3)]
				Health.injure(s,part,24,"cut")
			stop(s); pc.notice="Batch complete. F collects the output."
	else:
		work.progress+=1
		if work.progress>=work.ticks:
			var quantity: int=mini(5,mini(Inventory.amount(s,work.target,work.item),Inventory.available(s,s.player)))
			var result := Inventory.transfer(s,work.target,s.player,work.item,quantity)
			if result.ok: pc.held_item=work.item; pc.held_quantity=quantity
			if work.kind=="chop" and result.ok and sim.random_int("player:work_accident",0,11)==0:
				var part: String=["right_hand","left_hand","right_forearm","left_forearm"][sim.random_int("player:work_accident",0,3)]
				Health.injure(s,part,18,"cut")
			pc.work={}; pc.notice="Gathered supplies." if result.ok else "Could not gather: "+result.error_code

static func prompt(s: Dictionary,preferred: int = 0) -> String:
	if not s.has("player_control"): return ""
	var pc: Dictionary=s.player_control
	var warning: String=""
	for part in s.player_health.parts.values():
		if part.bleeding: warning="BLEEDING · Press H.  "; break
	if not pc.work.is_empty(): return warning+"F: stop %s · %d/%d" % [pc.work.kind,pc.work.progress,pc.work.ticks]
	if pc.held_quantity>0: return warning+"F: put down %d %s · I: stow" % [pc.held_quantity,pc.held_item]
	var id: int=target(s,preferred)
	return warning+("F: interact with "+s.entities[str(id)].name if id!=0 else pc.notice)

static func validate(s: Dictionary) -> String:
	if not s.has("player_control"): return ""
	var pc: Variant=s.player_control
	if not pc is Dictionary or not pc.get("held_item") is String or not pc.get("held_quantity") is int or not pc.get("work") is Dictionary or not pc.get("notice") is String: return "Invalid player controls"
	if pc.held_quantity<0 or pc.held_quantity>Inventory.amount(s,s.player,pc.held_item): return "Invalid held quantity"
	for field in ["ui_target","ui_nonce","next_move"]:
		if not pc.get(field) is int or pc[field]<0: return "Invalid player control value"
	var work: Dictionary=pc.work
	if not work.is_empty():
		if work.get("kind","") not in ["chop","harvest","saw"] or not work.get("target") is int or not s.entities.has(str(work.target)): return "Invalid player work target"
		if not work.get("progress") is int or not work.get("ticks") is int or work.progress<0 or work.ticks<1 or not work.get("cell") is Array or work.cell.size()!=2: return "Invalid player work progress"
	return ""
