extends Node

## StoryManager Singleton
## Manages dynamic adventure loading, narrative database, section navigation, and story signals for Tiny D6 Engine.

signal section_changed(section_data: Dictionary)
signal story_started

var current_section_id: String = "1"
var active_adventure_title: String = "Tiny D6 Engine"

## Embedded Fallback Database matching SpoonyAdventure.json
var fallback_database: Dictionary = {
	"1": {
		"text": "You stand in the Village of Tinyville. The Mayor, weeping sincerely, begs you to find the missing sacred legendary soup spoon.",
		"choices": [
			{"text": "Accept the quest with dignity.", "target": "2"},
			{"text": "Tell him it's just a spoon.", "target": "11", "test_type": "patience", "target_fail": "3"}
		]
	},
	"2": {
		"text": "The Mayor is delighted. He hands you [color=yellow]Form 4-B (Intent to Retrieve Utensils)[/color] and tells you the spoon is in [color=yellow]Spoon Cave[/color]. You must head into the [color=green]Mostly Sacred Forest[/color].",
		"choices": [
			{"text": "Venture into the forest.", "target": "4"}
		]
	},
	"3": {
		"text": "The Mayor gasps. He spends forty minutes explaining the cultural, economic, and philosophical history of the soup spoon. You lose [color=red]2 Heroic Patience[/color].",
		"choices": [
			{"text": "Groan and accept Form 4-B.", "target": "2", "patience_change": -2}
		]
	},
	"4": {
		"text": "You enter the forest and find yourself blocked by a feral [color=red]Ministry Wolf[/color]. However, the wolf wears a small laminated badge from the Royal Ministry of Wolves. It growls but politely waits for you to check your paperwork.",
		"choices": [
			{"text": "Fight the wolf using traditional combat.", "target": "5"},
			{"text": "Claim you have a Wolf-Hunting Permit.", "target": "7", "test_type": "skill", "target_fail": "5"}
		]
	},
	"5": {
		"text": "A combat encounter begins with the [color=red]Ministry Wolf[/color]!",
		"combat": {
			"enemy_name": "Ministry Wolf",
			"enemy_skill": 7,
			"enemy_stamina": 6,
			"victory_target": "7"
		},
		"choices": []
	},
	"6": {
		"text": "Your Stamina has reached 0. You do not die in a bloodbath; instead, the Wolf hands you an [color=red]Official Heroic Defeat Waiver[/color] and politely asks you to go back to the village.",
		"choices": [
			{"text": "Sign the waiver and try again.", "target": "1"}
		]
	},
	"7": {
		"text": "You reach [color=yellow]Spoon Cave[/color] and confront the 'Dark Lord,' who is just a dramatic guy who borrowed the spoon and forgot to return it. He hands it over with an incredibly theatrical apology speech.",
		"choices": [
			{"text": "Listen to his entire 12-page monologue.", "target": "8", "patience_change": -1},
			{"text": "Grab the spoon and run.", "target": "8"},
			{"text": "Try to pickpocket his shiny pocket-watch while he isn't looking.", "target": "9", "test_type": "luck", "target_fail": "8"}
		]
	},
	"8": {
		"text": "You return the spoon to the Mayor. He rewards you with a [color=green]'Hero's Discount' Coupon[/color] at the local blacksmith, which expired three weeks ago. [color=green]The End![/color]",
		"choices": [
			{"text": "Restart Adventure", "target": "1"}
		]
	},
	"9": {
		"text": "Success! You successfully pinch his pocket-watch (which only tells the time in a different dimension). You proceed to return the spoon.",
		"choices": [
			{"text": "Head back to the Mayor.", "target": "8"}
		]
	},
	"10": {
		"text": "That is it. You let out a deep, existential sigh. The endless rules, 40-minute monologues, and tedious paperwork have broken your spirit. You abandon the quest for the spoon, move to the countryside, and [color=yellow]open a peaceful Bed & Breakfast[/color].",
		"choices": [
			{"text": "Give up on innkeeping and try adventuring again 🔄", "target": "1"}
		]
	},
	"11": {
		"text": "The Mayor blinks, utterly failing to comprehend your dry sarcasm. He assumes 'just a spoon' is a stoic, high-level philosophical statement on the impermanence of material forms. Nodding solemnly at your profound heroic wisdom, he happily hands you [color=yellow]Form 4-B[/color].",
		"choices": [
			{"text": "Sigh quietly and head into the forest.", "target": "4"}
		]
	}
}

var story_database: Dictionary = {}

func _ready() -> void:
	# Scan available adventure files and load Knight.json or SpoonyAdventure.json or fallback
	var available = scan_for_adventures()
	var loaded = false
	for path in available:
		if path.ends_with("Knight.json"):
			loaded = load_adventure_from_file(path)
			if loaded:
				break
	if not loaded:
		for path in available:
			if path.ends_with("SpoonyAdventure.json"):
				loaded = load_adventure_from_file(path)
				if loaded:
					break
	if not loaded and not available.is_empty():
		for path in available:
			loaded = load_adventure_from_file(path)
			if loaded:
				break
		
	if not loaded:
		print("[StoryManager] Using fallback built-in narrative database (%d sections)." % fallback_database.size())
		story_database = fallback_database.duplicate(true)
		current_section_id = "1"

## Scans workspace and project directories for adventure .json files with deduplication
func scan_for_adventures() -> Array[String]:
	var found_paths: Array[String] = []
	var seen_filenames: Dictionary = {}
	var dirs_to_search: Array[String] = [
		"/home/yoni/Projects/tiny-d6-engine/Adventures/",
		"res://Adventures/",
		"user://Adventures/"
	]
	
	for dir_path in dirs_to_search:
		if DirAccess.dir_exists_absolute(dir_path):
			var dir = DirAccess.open(dir_path)
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if not dir.current_is_dir() and file_name.ends_with(".json"):
						var base_name = file_name.to_lower()
						if not seen_filenames.has(base_name):
							var full_path = dir_path.path_join(file_name)
							seen_filenames[base_name] = true
							found_paths.append(full_path)
					file_name = dir.get_next()
				dir.list_dir_end()
				
	print("[StoryManager] Scanned directories, found %d unique adventure files." % found_paths.size())
	return found_paths

## Loads, parses, and validates an adventure JSON file with explicit error reporting
func load_adventure_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		print("[StoryManager] File not found at path: " + file_path)
		return false
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[StoryManager] Unable to open file: " + file_path)
		return false
		
	var json_string = file.get_as_text()
	var json_parser = JSON.new()
	var error = json_parser.parse(json_string)
	if error != OK:
		print("[StoryManager] Failed to parse JSON from " + file_path + ": " + json_parser.get_error_message() + " at line " + str(json_parser.get_error_line()))
		return false
		
	if not (json_parser.data is Dictionary) or json_parser.data.is_empty():
		print("[StoryManager] Invalid or empty adventure dictionary in: " + file_path)
		return false
		
	story_database = json_parser.data
	current_section_id = "1"
	
	if story_database.has("title"):
		active_adventure_title = str(story_database["title"])
	elif story_database.has("adventure_name"):
		active_adventure_title = str(story_database["adventure_name"])
	elif story_database.has("name"):
		active_adventure_title = str(story_database["name"])
	else:
		active_adventure_title = file_path.get_file().trim_suffix(".json").capitalize()
		
	print("[StoryManager] Successfully loaded adventure '%s' from '%s' (%d sections)." % [active_adventure_title, file_path, story_database.size()])
	return true

## Returns the title of the active adventure module without raw ampersands
func get_adventure_title() -> String:
	return active_adventure_title.replace("&", "and")

## Starts the adventure from Section "1"
func start_adventure() -> void:
	print("[StoryManager] Starting adventure...")
	story_started.emit()
	go_to_section("1")

const SAVE_PATH: String = "user://save_game.json"

## Checks if an active save file exists
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Saves game state to user://save_game.json
func save_game(current_page_idx: int = 0) -> void:
	if current_section_id.begins_with("ending_") or current_section_id == "10":
		clear_save_game()
		return
		
	var save_dict = {
		"current_section_id": current_section_id,
		"current_page_index": current_page_idx,
		"active_adventure_title": active_adventure_title,
		"player_stats": PlayerStats.get_save_data()
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "\t"))
		file.close()
		print("[StoryManager] Game autosaved at section '%s', page %d." % [current_section_id, current_page_idx])

## Loads game state from user://save_game.json
func load_game() -> Dictionary:
	if not has_save_file():
		push_error("[StoryManager] No save file found at: " + SAVE_PATH)
		return {}
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
		
	var json_parser = JSON.new()
	var error = json_parser.parse(file.get_as_text())
	file.close()
	
	if error != OK or not (json_parser.data is Dictionary):
		push_error("[StoryManager] Failed to parse save file.")
		return {}
		
	var save_data: Dictionary = json_parser.data
	if save_data.has("player_stats") and save_data["player_stats"] is Dictionary:
		PlayerStats.load_save_data(save_data["player_stats"])
		
	var saved_sec_id: String = str(save_data.get("current_section_id", "1"))
	current_section_id = saved_sec_id
	return save_data

## Deletes save game file
func clear_save_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("[StoryManager] Save game file cleared.")

## Updates active state and emits section_changed signal
func go_to_section(sec_id) -> Dictionary:
	var key_str: String = str(sec_id)
	if not story_database.has(key_str):
		push_error("[StoryManager] Error: Section ID '%s' not found in active database!" % key_str)
		return {}
		
	current_section_id = key_str
	var section_data: Dictionary = story_database[key_str]
	print("[StoryManager] Transitioning to Section '%s'" % key_str)
	section_changed.emit(section_data)
	return section_data

## Returns active section data
func get_current_section_data() -> Dictionary:
	return story_database.get(current_section_id, {})
