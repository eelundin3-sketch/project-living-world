extends SceneTree
## The conversation window's rules: who has a Trade tab and a Talk tab, what Talk offers, that
## "Talk" opens the window on its Talk tab, and that the answers come back as their words.
const Sim = preload("res://sim/core/simulation.gd")
const Dialogue = preload("res://sim/player/dialogue.gd")
const Context = preload("res://sim/player/context_actions.gd")
const Law = preload("res://sim/law/law.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.tick = 14400 + 6000
	var farmer: Dictionary = {}
	var sheriff: Dictionary = {}
	for npc in s.residents.values():
		if farmer.is_empty() and npc.occupation not in ["Sheriff", "Child", "Trader"]: farmer = npc
		if sheriff.is_empty() and npc.occupation == "Sheriff": sheriff = npc
		npc.sleeping = {}
	check(Dialogue.tabs(s, int(farmer.id)) == ["trade", "talk"], "A villager can be traded and talked with")
	check(Dialogue.tabs(s, int(sheriff.id)) == ["talk"], "A sheriff only talks")
	var labels: Array = Dialogue.options(s, int(farmer.id)).map(func(o): return o.id)
	check("ask_work" in labels and "ask_family" in labels and "ask_news" in labels, "Talk offers work, family and news")
	var menu: Array = Context.options(s, int(sheriff.id)).map(func(o): return o.id)
	check("talk" in menu and not "trade" in menu, "The sheriff's menu has Talk and no Trade")
	# "Talk" walks up and opens the window on the Talk tab.
	s.entities[str(s.player)].cell = [s.entities[str(farmer.id)].cell[0] + 1, s.entities[str(farmer.id)].cell[1]]
	var nonce: int = int(s.player_control.ui_nonce)
	Context.perform(sim, int(farmer.id), "talk")
	check(int(s.player_control.ui_nonce) == nonce + 1 and s.player_control.ui_target == int(farmer.id) and s.player_control.ui_tab == "talk", "Talk opens the window on the Talk tab")
	Context.perform(sim, int(farmer.id), "ask_work")
	var first: String = String(s.entities[str(farmer.id)].name).split(" ")[0]
	check(str(s.player_control.notice).begins_with(first + ": I'm a " + String(farmer.occupation).to_lower()), "They tell you about their work: %s" % s.player_control.notice)
	# How they feel shows in the window, and follows what they remember.
	check(Dialogue.feeling(s, farmer)[0] == "Calm", "A stranger is calm")
	Law.crime(s, int(farmer.settlement), "theft", int(farmer.id))
	Law.crime(s, int(farmer.settlement), "theft", int(farmer.id))
	check(Dialogue.feeling(s, farmer)[0] == "Hostile", "After two thefts they are hostile (%s)" % Dialogue.feeling(s, farmer)[0])
	check(Dialogue.standing_line(s, farmer).begins_with("You are "), "The window shows your standing in their town: %s" % Dialogue.standing_line(s, farmer))
	print("Conversation: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
