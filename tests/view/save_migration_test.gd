extends SceneTree
## Saves from the old name are copied to the new name once, and never overwritten.
const SaveMigration = preload("res://app/save_migration.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(text); f.close()
func read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
func _initialize() -> void:
	var base := OS.get_temp_dir().path_join("solo-migration-%d" % Time.get_ticks_usec())
	var old_dir := base.path_join("Old Name")
	var new_dir := base.path_join("New Name")
	DirAccess.make_dir_recursive_absolute(old_dir); DirAccess.make_dir_recursive_absolute(new_dir)
	put(old_dir.path_join("project_solo.save"), "OLD SAVE"); put(old_dir.path_join("project_solo.save.bak"), "OLD BACKUP"); put(old_dir.path_join("controls.cfg"), "KEYS")
	var copied := SaveMigration.copy_old_saves(old_dir, new_dir)
	check(copied == 3, "Three files come across (%d)" % copied)
	check(read(new_dir.path_join("project_solo.save")) == "OLD SAVE" and read(new_dir.path_join("project_solo.save.bak")) == "OLD BACKUP" and read(new_dir.path_join("controls.cfg")) == "KEYS", "Their contents are intact")
	check(FileAccess.file_exists(old_dir.path_join("project_solo.save")), "The old files are left where they were")
	# A save made under the new name is never overwritten.
	put(new_dir.path_join("project_solo.save"), "NEW SAVE")
	check(SaveMigration.copy_old_saves(old_dir, new_dir) == 0 and read(new_dir.path_join("project_solo.save")) == "NEW SAVE", "An existing save is never overwritten")
	# Old file names inside the new folder (a game renamed in place) are picked up too.
	var same := base.path_join("Same Folder"); DirAccess.make_dir_recursive_absolute(same)
	put(same.path_join("project_solo.save"), "IN PLACE")
	check(SaveMigration.copy_old_saves(base.path_join("Nowhere"), same) == 1 and read(same.path_join("project_solo.save")) == "IN PLACE", "A save under the old file name in the same folder is picked up")
	print("Save migration: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
