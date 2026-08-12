extends Control

@onready var exit_menu_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ExitMenuButton
@onready var exit_game_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ExitGameButton

func _ready() -> void:
	exit_menu_button.pressed.connect(_on_exit_menu_pressed)
	
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
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_exit_game_pressed() -> void:
	print("[VictoryScreen] Exiting game. Farewell, Hero!")
	get_tree().quit()
