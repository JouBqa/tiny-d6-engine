extends Control

@onready var adventure_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/AdventureListContainer

func _ready() -> void:
	_populate_adventure_list()

func _populate_adventure_list() -> void:
	# Clear existing children
	for child in adventure_list_container.get_children():
		adventure_list_container.remove_child(child)
		child.queue_free()
		
	var adventure_files: Array[String] = StoryManager.scan_for_adventures()
	var instantiated_buttons: Array[Button] = []
	
	for file_path in adventure_files:
		var file_name: String = file_path.get_file().trim_suffix(".json")
		var display_title: String = file_name.capitalize()
		
		# If file is SpoonyAdventure, format nicely
		if file_name.to_lower().contains("spoony"):
			display_title = "The Spoony Adventure (Spoon Cave Quest)"
		elif file_name.to_lower().contains("prototype"):
			display_title = "The B&B Retirement Plan (Prototype)"
			
		var btn: Button = Button.new()
		btn.text = "  %s" % display_title
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 18)
		
		btn.pressed.connect(func(): _on_adventure_selected(file_path))
		
		adventure_list_container.add_child(btn)
		instantiated_buttons.append(btn)
		
	# Setup vertical D-Pad / Keyboard focus neighbors
	var count: int = instantiated_buttons.size()
	for i in range(count):
		var btn: Button = instantiated_buttons[i]
		var prev_btn: Button = instantiated_buttons[(i - 1 + count) % count]
		var next_btn: Button = instantiated_buttons[(i + 1) % count]
		btn.focus_neighbor_top = prev_btn.get_path()
		btn.focus_neighbor_bottom = next_btn.get_path()
		
	# Focus-Grab Rule: Grab focus on first adventure button immediately
	if count > 0:
		instantiated_buttons[0].call_deferred("grab_focus")

func _on_adventure_selected(file_path: String) -> void:
	print("[MainMenu] Adventure selected: %s" % file_path)
	var success: bool = StoryManager.load_adventure_from_file(file_path)
	if success:
		get_tree().change_scene_to_file("res://TinyD6Engine/UI/CharacterCreation.tscn")
	else:
		push_error("[MainMenu] Failed to load adventure file at path: %s" % file_path)
