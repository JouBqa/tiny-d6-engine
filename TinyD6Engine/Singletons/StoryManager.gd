extends Node

## StoryManager Singleton
## Manages narrative database (SpoonyAdventure), section navigation, and story signals for Tiny D6 Engine.

signal section_changed(section_data: Dictionary)
signal story_started

var current_section_id: String = "1"

## Embedded Fallback Database matching SpoonyAdventure.json
var story_database: Dictionary = {
	"1": {
		"text": "You stand in the Village of Tinyville. The Mayor, weeping sincerely, begs you to find the missing sacred legendary soup spoon.",
		"choices": [
			{"text": "Accept the quest with dignity.", "target": "2"},
			{"text": "Tell him it's just a spoon.", "target": "2", "test_type": "patience", "target_fail": "3"}
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
	}
}

func _ready() -> void:
	_load_adventure_json()

func _load_adventure_json() -> void:
	var path: String = "res://Adventures/SpoonyAdventure.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			var json = JSON.new()
			var parse_res = json.parse(json_text)
			if parse_res == OK and json.data is Dictionary:
				story_database = json.data
				print("[StoryManager] Successfully loaded SpoonyAdventure.json dynamically (%d sections)." % story_database.size())
				return
	print("[StoryManager] Using embedded fallback narrative database (%d sections)." % story_database.size())

## Starts the adventure from Section 1
func start_adventure() -> void:
	print("[StoryManager] Starting 'SpoonyAdventure'...")
	story_started.emit()
	go_to_section("1")

## Updates active state and emits section_changed signal
func go_to_section(sec_id) -> Dictionary:
	var key_str: String = str(sec_id)
	if not story_database.has(key_str):
		push_error("[StoryManager] Error: Section ID '%s' not found in database!" % key_str)
		return {}
		
	current_section_id = key_str
	var section_data: Dictionary = story_database[key_str]
	print("[StoryManager] Transitioning to Section '%s'" % key_str)
	section_changed.emit(section_data)
	return section_data

## Returns active section data
func get_current_section_data() -> Dictionary:
	return story_database.get(current_section_id, {})
