extends Control

@onready var exit_menu_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ExitMenuButton
@onready var exit_game_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ExitGameButton

func _ready() -> void:
	if OS.is_debug_build() or OS.get_name() in ["Windows", "macOS", "Linux"]:
		get_window().content_scale_factor = 2.0
	_apply_safe_area_margins()
	
	exit_menu_button.pressed.connect(_on_exit_menu_pressed)
	
	if OS.has_feature("web") or OS.has_feature("mobile"):
		exit_game_button.visible = false
		exit_menu_button.focus_neighbor_top = exit_menu_button.get_path()
		exit_menu_button.focus_neighbor_bottom = exit_menu_button.get_path()
	else:
		exit_game_button.pressed.connect(_on_exit_game_pressed)
		exit_menu_button.focus_neighbor_top = exit_game_button.get_path()
		exit_menu_button.focus_neighbor_bottom = exit_game_button.get_path()
		exit_game_button.focus_neighbor_top = exit_menu_button.get_path()
		exit_game_button.focus_neighbor_bottom = exit_menu_button.get_path()
		
	# Focus Grab Rule: Automatically grab focus on "Return to Main Menu" button immediately
	exit_menu_button.call_deferred("grab_focus")

func _apply_safe_area_margins() -> void:
	var safe_area: Rect2 = DisplayServer.get_display_safe_area()
	if safe_area.size.y > 0 and safe_area.position.y > 0:
		var top_offset: int = int(safe_area.position.y)
		var margin_container = get_node_or_null("PanelContainer/MarginContainer")
		if margin_container:
			margin_container.add_theme_constant_override("margin_top", 24 + top_offset)

func _on_exit_menu_pressed() -> void:
	print("[VictoryScreen] Returning to Main Menu...")
	CombatEngine.in_combat = false
	PlayerStats.reset_stats()
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_exit_game_pressed() -> void:
	print("[VictoryScreen] Exiting game. Farewell, Hero!")
	get_tree().quit()
