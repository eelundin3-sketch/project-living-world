extends SceneTree
## Saves: the quick save and two rotating morning autosaves, each with a small info file; the
## newest one is what Continue and F9 load. Uses its own folder, never the player's saves.
const Sim = preload("res://sim/core/simulation.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
const SaveSlots = preload("res://app/save_slots.gd")
const DIR := "user://test_save_slots"
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _wipe() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR): DirAccess.remove_absolute(DIR.path_join(name))

func _stamp(path: String, saved: float) -> void:
	var data := SaveSlots.info(path); data.saved = saved
	var file := FileAccess.open(path + ".info", FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()

func _initialize() -> void:
	_wipe()
	check(SaveSlots.newest(DIR).is_empty(), "No saves yet: nothing to continue")
	var sim := Sim.new(); sim.start_game()
	for i in range(50): sim.step()
	var quick: String = DIR.path_join(SaveSlots.QUICK)
	var started := Time.get_ticks_usec()
	check(SaveSlots.save(sim, quick, "quick").ok, "Quick save writes")
	var save_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	print("save took %.1f ms" % save_ms)
	var info := SaveSlots.info(quick)
	check(int(info.day) == 1 and str(info.kind) == "quick" and not str(info.town).is_empty(), "The info file knows the day, kind and town (%s)" % str(info))
	check(SaveSlots.describe(info).begins_with("Day 1 · "), "It reads like a place in time (%s)" % SaveSlots.describe(info))
	check(SaveSlots.newest(DIR).path == quick, "The quick save is the newest")
	# Autosaves take turns: an empty file first, then whichever is older.
	var first: String = SaveSlots.next_autosave(DIR)
	check(SaveSlots.save(sim, first, "autosave").ok, "First autosave writes")
	var second: String = SaveSlots.next_autosave(DIR)
	check(second != first, "The second autosave goes to the other file")
	check(SaveSlots.save(sim, second, "autosave").ok, "Second autosave writes")
	_stamp(quick, 1000.0); _stamp(first, 2000.0); _stamp(second, 3000.0)
	check(SaveSlots.next_autosave(DIR) == first, "The third overwrites the older autosave, never the newer")
	check(SaveSlots.newest(DIR).path == second, "Continue picks the newest of all saves")
	# The newest save loads into a fresh world as the same world.
	var copy := Sim.new()
	var result := Save.load_into(copy, SaveSlots.newest(DIR).path)
	check(result.ok and copy.state_hash() == sim.state_hash(), "The newest save loads back exactly")
	# When the morning autosave is due.
	var s: Dictionary = {"tick": 14400 * 2 + 3700}   # day 3, 06:10
	check(SaveSlots.autosave_due(s, 1), "Due on a new morning after 06:00")
	check(not SaveSlots.autosave_due(s, 2), "...but only once that day")
	check(not SaveSlots.autosave_due({"tick": 14400 * 2 + 3000}, 1), "Not before 06:00")
	# In the game the slow part runs on a background thread; only the copy happens on the main thread.
	var threaded: String = DIR.path_join("threaded.save")
	var copied := Time.get_ticks_usec()
	var data: Dictionary = sim.snapshot()
	var save_info: Dictionary = SaveSlots.info_for(sim.state, "autosave")
	var main_ms: float = float(Time.get_ticks_usec() - copied) / 1000.0
	var thread := Thread.new()
	thread.start(SaveSlots.write.bind(data, save_info, threaded))
	var threaded_result: Dictionary = thread.wait_to_finish()
	check(threaded_result.ok, "A save written on a background thread succeeds")
	var reloaded := Sim.new()
	check(Save.load_into(reloaded, threaded).ok and reloaded.state_hash() == sim.state_hash(), "...and loads back exactly")
	print("main-thread part of a save: %.1f ms (whole save %.0f ms)" % [main_ms, save_ms])
	check(main_ms < 40.0, "The part of a save that pauses the game is short (%.1f ms)" % main_ms)
	# The title screen offers Continue, with where the save left off, only when there is a save.
	var MainMenu = load("res://view/ui/main_menu.gd")
	var with_save = MainMenu.new(); with_save.continue_text = "Day 3 · 07:40 · Reedbank"
	root.add_child(with_save)
	var fresh = MainMenu.new()
	root.add_child(fresh)
	await process_frame
	check(with_save.buttons.size() == 4 and with_save.buttons[0].text == "Continue", "With a save, Continue comes first (%d buttons)" % with_save.buttons.size())
	check(fresh.buttons.size() == 3 and fresh.buttons[0].text == "Start Game", "Without one, the menu is as before")
	with_save.queue_free(); fresh.queue_free()
	_wipe()
	DirAccess.remove_absolute(DIR)
	print("Save slots: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
