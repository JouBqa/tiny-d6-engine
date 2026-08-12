extends Control

@onready var adventure_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/AdventureListContainer

func _ready() -> void:
	_apply_safe_area_margins()
	_populate_adventure_list()

func _apply_safe_area_margins() -> void:
	var safe_area: Rect2 = DisplayServer.get_display_safe_area()
	if safe_area.size.y > 0 and safe_area.position.y > 0:
		var top_offset: int = int(safe_area.position.y)
		var margin_container = get_node_or_null("PanelContainer/MarginContainer")
		if margin_container:
			margin_container.add_theme_constant_override("margin_top", 28 + top_offset)

func _populate_adventure_list() -> void:
	# Clear existing children
	for child in adventure_list_container.get_children():
		adventure_list_container.remove_child(child)
		child.queue_free()
		
	var instantiated_buttons: Array[Button] = []
	
	# Check if an autosave file exists
	if StoryManager.has_save_file():
		var continue_btn: Button = Button.new()
		continue_btn.text = "  Continue Saved Game (Resume Quest)"
		continue_btn.custom_minimum_size = Vector2(0, 52)
		continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		continue_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		continue_btn.add_theme_font_size_override("font_size", 18)
		continue_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		
		continue_btn.pressed.connect(_on_continue_pressed)
		adventure_list_container.add_child(continue_btn)
		instantiated_buttons.append(continue_btn)
		
	var adventure_files: Array[String] = StoryManager.scan_for_adventures()
	
	for file_path in adventure_files:
		var file_name: String = file_path.get_file().trim_suffix(".json")
		var display_title: String = file_name.capitalize()
		
		var is_disabled: bool = false
		if file_name.to_lower().contains("knight"):
			display_title = "Sir Albert Bumblethwaite and the Pudding of Perpetual Wobble (Coming soon(ish)!)"
			is_disabled = true
		elif file_name.to_lower().contains("stirringham") or file_name.to_lower().contains("spoony"):
			display_title = "Stirringham (3 minutes)"
		elif file_name.to_lower().contains("prototype"):
			display_title = "The B&B Retirement Plan (Prototype)"
			
		var btn: Button = Button.new()
		btn.text = "  %s" % display_title
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 18)
		
		if is_disabled:
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 0.7))
		else:
			btn.pressed.connect(func(): _on_adventure_selected(file_path))
			instantiated_buttons.append(btn)
			
		adventure_list_container.add_child(btn)
		
	# Setup vertical D-Pad / Keyboard focus neighbors
	var count: int = instantiated_buttons.size()
	for i in range(count):
		var btn: Button = instantiated_buttons[i]
		var prev_btn: Button = instantiated_buttons[(i - 1 + count) % count]
		var next_btn: Button = instantiated_buttons[(i + 1) % count]
		btn.focus_neighbor_top = prev_btn.get_path()
		btn.focus_neighbor_bottom = next_btn.get_path()
		
	# Focus-Grab Rule: Grab focus on first button (Continue if present) immediately
	if count > 0:
		instantiated_buttons[0].call_deferred("grab_focus")

func _on_continue_pressed() -> void:
	print("[MainMenu] Continuing saved game...")
	var save_data: Dictionary = StoryManager.load_game()
	if not save_data.is_empty():
		var saved_title: String = str(save_data.get("active_adventure_title", ""))
		var available_files = StoryManager.scan_for_adventures()
		for path in available_files:
			if path.to_lower().contains("knight") and (saved_title.to_lower().contains("albert") or saved_title.to_lower().contains("pudding")):
				StoryManager.load_adventure_from_file(path)
				break
				
		# Re-apply save data (player stats and section)
		StoryManager.load_game()
		get_tree().change_scene_to_file("res://UI/DialogueUI.tscn")

func _on_adventure_selected(file_path: String) -> void:
	print("[MainMenu] Adventure selected: %s" % file_path)
	var success: bool = StoryManager.load_adventure_from_file(file_path)
	if success:
		get_tree().change_scene_to_file("res://UI/CharacterCreation.tscn")
	else:
		push_error("[MainMenu] Failed to load adventure file at path: %s" % file_path)
