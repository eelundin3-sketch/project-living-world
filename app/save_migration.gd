extends RefCounted
## The game used to be called Project Living World and saved to living_world.save in a folder of that
## name. On first launch under the new name, saves (and key bindings) are copied across: never moved,
## never overwritten, so the old files stay where they were.
const RENAMED := {"living_world.save": "project_solo.save", "living_world.save.bak": "project_solo.save.bak", "controls.cfg": "controls.cfg"}

## Copies what is missing from `to_dir` out of `legacy_dir` (the old save folder) and, failing that,
## from `to_dir` itself under the old file names. Returns the number of files copied.
static func copy_old_saves(legacy_dir: String, to_dir: String) -> int:
	var copied := 0
	for old_name in RENAMED:
		var new_name: String = RENAMED[old_name]
		var destination := to_dir.path_join(new_name)
		if FileAccess.file_exists(destination): continue
		for source in [to_dir.path_join(old_name), legacy_dir.path_join(old_name)]:
			if source == destination or not FileAccess.file_exists(source): continue
			if DirAccess.copy_absolute(source, destination) == OK:
				copied += 1
				break
	return copied

## The old save folder is a sibling of this game's own folder (`.../app_userdata/Project Living World`).
static func migrate() -> int:
	var user_dir: String = OS.get_user_data_dir()
	return copy_old_saves(user_dir.get_base_dir().path_join("Project Living World"), user_dir)
