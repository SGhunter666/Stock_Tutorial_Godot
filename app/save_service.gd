## Staged JSON writes with one recoverable previous save.
class_name SmaSaveService
extends RefCounted

const SAVE_PATH := "user://saves/career.json"
const SLOT_COUNT := 4


static func slot_path(slot: int) -> String:
	var clamped := clampi(slot, 1, SLOT_COUNT)
	if clamped == 1:
		return SAVE_PATH
	return "user://saves/career_slot_%d.json" % clamped


static func slot_summary(slot: int) -> Dictionary:
	var clamped := clampi(slot, 1, SLOT_COUNT)
	var path := slot_path(clamped)
	var summary := {
		"slot": clamped, "path": path, "exists": false, "playerName": "",
		"day": 0, "equity": 0.0, "rank": 1, "storiesSeen": 0,
		"savedAt": 0, "graduated": false,
	}
	var data := read(path)
	if data.is_empty():
		data = read(path + ".bak")
	if data.is_empty():
		return summary
	summary["exists"] = true
	summary["savedAt"] = int(data.get("savedAt", 0))
	var cfg: Variant = data.get("settings", {})
	if cfg is Dictionary:
		summary["playerName"] = String(cfg.get("playerName", ""))
	var ex: Variant = data.get("exchange", {})
	if ex is Dictionary:
		summary["day"] = int(ex.get("dayIndex", 0))
		var account: Variant = ex.get("account", {})
		if account is Dictionary:
			var history: Variant = account.get("equityHistory", [])
			if history is Array and not history.is_empty() and history.back() is Dictionary:
				summary["equity"] = float(history.back().get("equity", account.get("cash", 0.0)))
			else:
				summary["equity"] = float(account.get("cash", 0.0))
	var cr: Variant = data.get("career", {})
	if cr is Dictionary:
		summary["rank"] = int(cr.get("rank", 1))
	var story: Variant = data.get("narrative", {})
	if story is Dictionary:
		var seen: Variant = story.get("seen", {})
		if seen is Dictionary:
			summary["storiesSeen"] = seen.size()
			summary["graduated"] = bool(seen.get("epilogue", false)) \
				or bool(seen.get("graduation", false)) \
				or bool(seen.get("graduation_unfunded", false))
	return summary


static func list_slots() -> Array:
	var rows: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		rows.append(slot_summary(slot))
	return rows


static func _ensure_dir(dir_path: String) -> bool:
	var global := ProjectSettings.globalize_path(dir_path)
	if DirAccess.dir_exists_absolute(global):
		return true
	return DirAccess.make_dir_recursive_absolute(global) == OK


static func exists(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


static func write(payload: Dictionary, path: String = SAVE_PATH,
		keep_backup: bool = false) -> bool:
	var dir_path := path.get_base_dir()
	if not _ensure_dir(dir_path):
		push_error("SmaSaveService: cannot create save directory %s" % dir_path)
		return false
	var temporary_suffix := ".%d.%d.tmp" % [OS.get_process_id(), Time.get_ticks_usec()]
	var tmp_path := path + temporary_suffix
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SmaSaveService: cannot open temp save %s" % tmp_path)
		return false
	var stored := file.store_string(JSON.stringify(payload))
	file.flush()
	stored = stored and file.get_error() == OK
	file.close()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	var file_name := path.get_file()
	var backup := file_name + ".bak"
	var tmp_name := tmp_path.get_file()
	if stored and not keep_backup and dir.file_exists(file_name):
		var backup_stage := backup + temporary_suffix
		var backup_stage_path := dir_path.path_join(backup_stage)
		stored = dir.copy(path, backup_stage_path) == OK \
			and FileAccess.get_size(backup_stage_path) == FileAccess.get_size(path) \
			and dir.rename(backup_stage, backup) == OK
		if not stored and dir.file_exists(backup_stage):
			dir.remove(backup_stage)
	if stored and dir.rename(tmp_name, file_name) == OK:
		return true
	if dir.file_exists(tmp_name):
		dir.remove(tmp_name)
	# On Windows, Godot may remove the destination before completing a rename.
	# The backup remains readable even when restoring the primary file fails.
	if not dir.file_exists(file_name) and dir.file_exists(backup):
		dir.copy(dir_path.path_join(backup), path)
	return false


static func read(path: String = SAVE_PATH) -> Dictionary:
	if not exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func clear(path: String = SAVE_PATH) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir != null:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			var name := path.get_file() + suffix
			if dir.file_exists(name):
				dir.remove(name)


static func export_to(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var ok := file.store_string(JSON.stringify(payload))
	file.flush()
	ok = ok and file.get_error() == OK
	file.close()
	return ok


static func import_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
