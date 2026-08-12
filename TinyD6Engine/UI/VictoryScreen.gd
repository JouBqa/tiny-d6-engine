extends Control

@onready var exit_menu_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ExitMenuButton
@onready var exit_game_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ExitGameButton

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	exit_menu_button.pressed.connect(_on_exit_menu_pressed)

func _on_viewport_size_changed() -> void:
	var win_size: Vector2i = DisplayServer.window_get_size()
	if win_size.y <= 0:
		return
	var aspect: float = float(win_size.x) / float(win_size.y)
	if aspect < 1.0:
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	if OS.has_feature("web"):
		exit_game_button.visible = false
		exit_menu_button.focus_neighbor_top = exit_menu_button.get_path()
		exit_menu_button.focus_neighbor_bottom = exit_menu_button.get_path()
	else:
		exit_game_button.pressed.connect(_on_exit_game_pressed)
		exit_menu_button.focus_neighbor_top = exit_game_button.get_path()
		exit_menu_button.focus_neighbor_bottom = exit_game_button.get_path()
		exit_game_button.focus_neighbor_top = exit_menu_button.get_path()
		exit_game_button.focus_neighbor_bottom = exit_menu_button.get_path()
		
	# Focus Grab Rule: Automatically grab focus on "Exit to Main Menu" button immediately
	exit_menu_button.call_deferred("grab_focus")

func _on_exit_menu_pressed() -> void:
	print("[VictoryScreen] Returning to Main Menu...")
	CombatEngine.in_combat = false
	PlayerStats.reset_stats()
	get_tree().change_scene_to_file("res://TinyD6Engine/UI/MainMenu.tscn")

func _on_exit_game_pressed() -> void:
	print("[VictoryScreen] Exiting game. Farewell, Hero!")
	get_tree().quit()
