extends RefCounted
const Art = preload("res://view/world/fixture_art.gd")
var phases: Dictionary = {}
var running: Dictionary = {}
var flights: Array[Dictionary] = []
var last_serial: int = -1
var previous_tick: int = -1
func reset() -> void:
	phases.clear(); running.clear(); flights.clear(); last_serial=-1; previous_tick=-1
func update(s: Dictionary, dt: float, paused: bool, speed: int) -> void:
	if s.tick < previous_tick: reset()
	previous_tick=s.tick
	var delta: float = 0.0 if paused else minf(dt,0.1)*speed
	for flight in flights: flight.age+=delta
	flights=flights.filter(func(f: Dictionary) -> bool: return f.age<0.45)
	for workshop in s.get("workshops",{}).values():
		var npc: Dictionary = s.get("residents",{}).get(str(workshop.worker),{})
		var entity: Dictionary = s.entities[str(workshop.id)]
		var at_station: bool = not entity.get("fixtures",[]).is_empty() and s.entities.get(str(workshop.worker),{}).get("cell",[]) == entity.fixtures[0].stance
		var active: bool = at_station and workshop.enabled and workshop.active and npc.get("status","")=="Sawing logs into planks" and npc.get("goal","").is_empty() and npc.get("work_pause_until",0)<=s.tick and npc.get("hunger",100)<60 and npc.get("fatigue",100)<75
		if workshop.get("player_operator",0)==s.get("player",-1):
			active=workshop.active and workshop.enabled and s.get("player_control",{}).get("work",{}).get("target",0)==workshop.id and s.entities[str(s.player)].cell==entity.fixtures[0].stance
		running[str(workshop.id)]=active
		phases[str(workshop.id)]=float(phases.get(str(workshop.id),0))+delta*18.0 if active else float(phases.get(str(workshop.id),0))
	if last_serial<0: last_serial=int(s.get("transfer_serial",0)); return
	if paused: return
	for event in s.get("transfer_observations",[]):
		if event.serial<=last_serial: continue
		last_serial=event.serial
		var source: Dictionary = s.entities.get(str(event.source),{})
		var destination: Dictionary = s.entities.get(str(event.destination),{})
		if source.is_empty() or destination.is_empty(): continue
		var source_fixture: bool = not source.get("fixtures",[]).is_empty()
		var dest_fixture: bool = not destination.get("fixtures",[]).is_empty()
		if not (source_fixture or dest_fixture): continue
		# Only physical worker handling, not abstract market/caravan transactions.
		if source.kind not in ["resident","player"] and destination.kind not in ["resident","player"]: continue
		var a: Vector2 = Art.slot(source,event.item) if source_fixture else Vector2(source.cell[0],source.cell[1])*24-Vector2(0,29)
		var b: Vector2 = Art.slot(destination,event.item) if dest_fixture else Vector2(destination.cell[0],destination.cell[1])*24-Vector2(0,29)
		if a.distance_to(b)>120: continue
		flights.append({"from":a,"to":b,"item":event.item,"age":0.0})
		if flights.size()>24: flights.pop_front()
func draw_transfers(c: Node2D) -> void:
	for flight in flights:
		var t: float = clampf(flight.age/0.45,0,1)
		var p: Vector2 = flight.from.lerp(flight.to,smoothstep(0,1,t))-Vector2(0,sin(t*PI)*12)
		Art.item(c,p,flight.item)
