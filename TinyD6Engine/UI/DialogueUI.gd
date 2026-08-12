extends Control

@onready var story_text_label: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/StoryTextLabel
@onready var choice_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ChoiceContainer
@onready var stats_hud_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/StatsHUDLabel

var _handling_loss_state: bool = false
var _typewriter_tween: Tween
var _is_typing: bool = false

func _ready() -> void:
	# Enable scroll following on RichTextLabel
	story_text_label.scroll_following = true
	
	# Connect to StoryManager section_changed signal
	StoryManager.section_changed.connect(_on_section_changed)
	
	# Connect to PlayerStats critical loss signals
	PlayerStats.patience_depleted.connect(_on_patience_depleted)
	PlayerStats.stamina_depleted.connect(_on_stamina_depleted)
	PlayerStats.stats_changed.connect(_update_stats_hud)
	
	# Display current section or default to Section 1
	var current_data: Dictionary = StoryManager.get_current_section_data()
	if current_data.is_empty():
		current_data = StoryManager.go_to_section("1")
	else:
		_display_section(current_data)
		
	_update_stats_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _is_typing and event.is_action_pressed("ui_accept"):
		_skip_typewriter_effect()
		get_viewport().set_input_as_handled()

func _start_typewriter_effect() -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
		
	story_text_label.visible_ratio = 0.0
	_is_typing = true
	
	var total_len: int = story_text_label.text.length()
	var duration: float = min(0.8, total_len * 0.006)
	
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(story_text_label, "visible_ratio", 1.0, duration)
	_typewriter_tween.finished.connect(func():
		_is_typing = false
		_scroll_to_bottom()
	)

func _skip_typewriter_effect() -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	story_text_label.visible_ratio = 1.0
	_is_typing = false
	_scroll_to_bottom()

## Automatic Scrolling Fix (CRITICAL)
## Pins vertical scrollbar directly to maximum value so appended text is immediately visible
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if story_text_label:
		story_text_label.scroll_to_line(max(0, story_text_label.get_line_count() - 1))
		var v_scroll = story_text_label.get_v_scroll_bar()
		if v_scroll:
			v_scroll.value = v_scroll.max_value

func _update_stats_hud() -> void:
	if stats_hud_label:
		stats_hud_label.text = "SKILL: %d  |  STAMINA: %d/%d  |  LUCK: %d  |  HEROIC PATIENCE: %d" % [
			PlayerStats.skill,
			PlayerStats.current_stamina,
			PlayerStats.stamina,
			PlayerStats.current_luck,
			PlayerStats.current_patience
		]

func _on_patience_depleted() -> void:
	if _handling_loss_state:
		return
	if StoryManager.current_section_id == "10":
		return
		
	_handling_loss_state = true
	print("[DialogueUI] Sanity Loss triggered: Heroic Patience reached 0! Redirecting to Section 10 (Bed & Breakfast).")
	CombatEngine.in_combat = false
	story_text_label.append_text("\n\n[color=yellow][b]SANITY LOSS: Your Heroic Patience has reached 0! You abandon the quest and open a B&B.[/b][/color]")
	_scroll_to_bottom()
	_clear_choice_container()
	StoryManager.go_to_section("10")
	_handling_loss_state = false

func _on_stamina_depleted() -> void:
	if _handling_loss_state:
		return
	if StoryManager.current_section_id == "6":
		return
		
	_handling_loss_state = true
	print("[DialogueUI] Physical Defeat triggered: Stamina reached 0! Redirecting to Section 6 (Defeat Waiver).")
	CombatEngine.in_combat = false
	story_text_label.append_text("\n\n[color=red][b]PHYSICAL DEFEAT: Your Stamina has been depleted![/b][/color]")
	_scroll_to_bottom()
	_clear_choice_container()
	StoryManager.go_to_section("6")
	_handling_loss_state = false

func _on_section_changed(section_data: Dictionary) -> void:
	_display_section(section_data)
	_update_stats_hud()

func _display_section(section_data: Dictionary) -> void:
	# Set base story text with BBCode parsing
	story_text_label.text = section_data.get("text", "")
	_start_typewriter_effect()
	_scroll_to_bottom()
	
	if section_data.has("combat"):
		var combat_info: Dictionary = section_data["combat"]
		CombatEngine.start_combat(
			combat_info.get("enemy_name", "Ministry Wolf"),
			combat_info.get("enemy_skill", 7),
			combat_info.get("enemy_stamina", 6),
			combat_info.get("victory_target", "7"),
			combat_info.get("defeat_target", "6")
		)
		_render_fight_round_button()
	else:
		CombatEngine.in_combat = false
		_render_narrative_choices(section_data.get("choices", []))

## Renders standard branching narrative choice buttons
func _render_narrative_choices(choices: Array) -> void:
	_clear_choice_container()
	var instantiated_buttons: Array[Button] = []
	
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn: Button = Button.new()
		btn.text = "  [%d]  %s" % [i + 1, choice.get("text", "")]
		btn.custom_minimum_size = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		
		btn.pressed.connect(func(): _on_choice_pressed(choice))
		
		choice_container.add_child(btn)
		instantiated_buttons.append(btn)
	
	_setup_focus_loop_and_grab(instantiated_buttons)

func _on_choice_pressed(choice: Dictionary) -> void:
	_skip_typewriter_effect()
	
	# Apply inline patience_change if present
	if choice.has("patience_change"):
		var change: int = int(choice["patience_change"])
		if change < 0:
			PlayerStats.deduct_patience(abs(change))
			if PlayerStats.current_patience <= 0:
				return # patience_depleted signal automatically handles redirect to Section 10
				
	# Process stat tests (patience, skill, luck) if specified
	if choice.has("test_type"):
		_resolve_choice_stat_test(choice)
		return
		
	var target_sec: String = str(choice.get("target", "1"))
	var text_str: String = str(choice.get("text", ""))
	
	# Check if this choice restarts the run
	if target_sec == "1" and (text_str.contains("Restart") or text_str.contains("try again") or text_str.contains("try adventuring again")):
		_on_restart_pressed()
	else:
		StoryManager.go_to_section(target_sec)

func _resolve_choice_stat_test(choice: Dictionary) -> void:
	var test_type: String = str(choice.get("test_type", ""))
	var target_win: String = str(choice.get("target", "1"))
	var target_fail: String = str(choice.get("target_fail", "1"))
	
	var is_success: bool = false
	var roll_val: int = 0
	var target_val: int = 0
	
	if test_type == "patience":
		target_val = PlayerStats.current_patience
		roll_val = randi_range(1, 6)
		is_success = roll_val <= target_val
		story_text_label.append_text("\n\n[color=yellow]Patience Test! Rolled %d vs Heroic Patience %d -> %s[/color]" % [roll_val, target_val, "SUCCESS!" if is_success else "FAILED!"])
	elif test_type == "skill":
		target_val = PlayerStats.skill
		var d1 = randi_range(1, 6)
		var d2 = randi_range(1, 6)
		roll_val = d1 + d2
		is_success = roll_val <= target_val
		story_text_label.append_text("\n\n[color=yellow]Skill Test! Rolled %d vs Skill %d -> %s[/color]" % [roll_val, target_val, "SUCCESS!" if is_success else "FAILED!"])
	elif test_type == "luck":
		target_val = PlayerStats.current_luck
		PlayerStats.deduct_luck(1)
		var d1 = randi_range(1, 6)
		var d2 = randi_range(1, 6)
		roll_val = d1 + d2
		is_success = roll_val <= target_val
		story_text_label.append_text("\n\n[color=yellow]Luck Test! Rolled %d vs Luck %d -> %s[/color]" % [roll_val, target_val, "LUCKY!" if is_success else "UNLUCKY!"])
		
	_scroll_to_bottom()
	await get_tree().create_timer(0.3).timeout
	
	if is_success:
		StoryManager.go_to_section(target_win)
	else:
		StoryManager.go_to_section(target_fail)

## Restarts the game clean: resets stats and transitions back to CharacterCreation.tscn
func _on_restart_pressed() -> void:
	print("[DialogueUI] Resetting PlayerStats and returning to CharacterCreation screen...")
	CombatEngine.in_combat = false
	PlayerStats.reset_stats()
	get_tree().change_scene_to_file("res://TinyD6Engine/UI/CharacterCreation.tscn")

## Renders the "Fight Round ⚔️" button at start of combat step
func _render_fight_round_button() -> void:
	_clear_choice_container()
	
	var fight_btn: Button = Button.new()
	fight_btn.text = "  ⚔️  Fight Round %d vs %s (Skill: %d, Stamina: %d)" % [
		CombatEngine.round_count + 1,
		CombatEngine.enemy_name,
		CombatEngine.enemy_skill,
		CombatEngine.enemy_stamina
	]
	fight_btn.custom_minimum_size = Vector2(0, 50)
	fight_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fight_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fight_btn.add_theme_font_size_override("font_size", 16)
	fight_btn.pressed.connect(_on_fight_round_pressed)
	
	choice_container.add_child(fight_btn)
	_setup_focus_loop_and_grab([fight_btn])

## Executes combat round calculation and presents Luck options or outcome
func _on_fight_round_pressed() -> void:
	_skip_typewriter_effect()
	var round_data: Dictionary = CombatEngine.roll_round()
	if round_data.is_empty():
		return
		
	var log_entry = "\n\n[color=yellow]Round %d: Player (%d) vs %s (%d)[/color]" % [
		round_data["round"],
		round_data["player_as"],
		CombatEngine.enemy_name,
		round_data["enemy_as"]
	]
	story_text_label.append_text(log_entry)
	_scroll_to_bottom()
	
	var winner: String = round_data["winner"]
	if winner == "draw":
		story_text_label.append_text("\n[color=yellow] -> Standoff! Both attacks match. No damage inflicts.[/color]")
		_scroll_to_bottom()
		_render_fight_round_button()
	elif winner == "player":
		story_text_label.append_text("\n[color=green] -> Hit! You wound the %s![/color]" % CombatEngine.enemy_name)
		_scroll_to_bottom()
		_render_player_hit_luck_choices()
	elif winner == "enemy":
		story_text_label.append_text("\n[color=red] -> Wounded! The %s hits you![/color]" % CombatEngine.enemy_name)
		_scroll_to_bottom()
		_render_enemy_hit_luck_choices()

## Player hit enemy: present "Test Luck to Increase Damage" vs "Accept Standard Damage"
func _render_player_hit_luck_choices() -> void:
	_clear_choice_container()
	var buttons: Array[Button] = []
	
	var luck_btn: Button = Button.new()
	luck_btn.text = "  🎲  Test Luck to Increase Damage! (Current Luck: %d)" % PlayerStats.current_luck
	luck_btn.custom_minimum_size = Vector2(0, 46)
	luck_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	luck_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	luck_btn.add_theme_font_size_override("font_size", 16)
	luck_btn.pressed.connect(func(): _resolve_luck_test(true))
	choice_container.add_child(luck_btn)
	buttons.append(luck_btn)
	
	var standard_btn: Button = Button.new()
	standard_btn.text = "  ⚔️  Accept Standard Damage (Deal 2 Stamina Damage)"
	standard_btn.custom_minimum_size = Vector2(0, 46)
	standard_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	standard_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	standard_btn.add_theme_font_size_override("font_size", 16)
	standard_btn.pressed.connect(func(): _resolve_base_wounding(true))
	choice_container.add_child(standard_btn)
	buttons.append(standard_btn)
	
	_setup_focus_loop_and_grab(buttons)

## Enemy hit player: present "Test Luck to Mitigate Damage" vs "Accept Standard Damage"
func _render_enemy_hit_luck_choices() -> void:
	_clear_choice_container()
	var buttons: Array[Button] = []
	
	var luck_btn: Button = Button.new()
	luck_btn.text = "  🛡️  Test Luck to Mitigate Damage! (Current Luck: %d)" % PlayerStats.current_luck
	luck_btn.custom_minimum_size = Vector2(0, 46)
	luck_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	luck_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	luck_btn.add_theme_font_size_override("font_size", 16)
	luck_btn.pressed.connect(func(): _resolve_luck_test(false))
	choice_container.add_child(luck_btn)
	buttons.append(luck_btn)
	
	var standard_btn: Button = Button.new()
	standard_btn.text = "  💔  Accept Standard Damage (Suffer 2 Stamina Damage)"
	standard_btn.custom_minimum_size = Vector2(0, 46)
	standard_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	standard_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	standard_btn.add_theme_font_size_override("font_size", 16)
	standard_btn.pressed.connect(func(): _resolve_base_wounding(false))
	choice_container.add_child(standard_btn)
	buttons.append(standard_btn)
	
	_setup_focus_loop_and_grab(buttons)

func _resolve_base_wounding(player_wounded_enemy: bool) -> void:
	var res: Dictionary = CombatEngine.apply_base_wounding()
	if player_wounded_enemy:
		story_text_label.append_text("\n[color=green]Dealt 2 Stamina damage to %s. (Enemy Stamina: %d)[/color]" % [CombatEngine.enemy_name, CombatEngine.enemy_stamina])
	else:
		story_text_label.append_text("\n[color=red]Took 2 Stamina damage. (Your Stamina: %d/%d)[/color]" % [PlayerStats.current_stamina, PlayerStats.stamina])
		
	_scroll_to_bottom()
	_update_stats_hud()
	_check_combat_status_or_continue()

func _resolve_luck_test(player_wounded_enemy: bool) -> void:
	var res: Dictionary = CombatEngine.test_luck_on_wounding()
	var luck_str = "LUCKY!" if res["is_lucky"] else "UNLUCKY!"
	
	story_text_label.append_text("\n[color=yellow]Luck Test! Rolled %d vs Luck %d -> %s[/color]" % [res["luck_roll"], res["luck_target"], luck_str])
	
	if player_wounded_enemy:
		if res["is_lucky"]:
			story_text_label.append_text("\n[color=green]CRITICAL! Dealt 4 Stamina damage to %s! (Enemy Stamina: %d)[/color]" % [CombatEngine.enemy_name, CombatEngine.enemy_stamina])
		else:
			story_text_label.append_text("\n[color=yellow]GLANCING BLOW! Dealt only 1 Stamina damage to %s. (Enemy Stamina: %d)[/color]" % [CombatEngine.enemy_name, CombatEngine.enemy_stamina])
	else:
		if res["is_lucky"]:
			story_text_label.append_text("\n[color=green]MITIGATED! Took only 1 Stamina damage! (Your Stamina: %d/%d)[/color]" % [PlayerStats.current_stamina, PlayerStats.stamina])
		else:
			story_text_label.append_text("\n[color=red]SEVERE WOUND! Took 3 Stamina damage! (Your Stamina: %d/%d)[/color]" % [PlayerStats.current_stamina, PlayerStats.stamina])
			
	_scroll_to_bottom()
	_update_stats_hud()
	_check_combat_status_or_continue()

func _check_combat_status_or_continue() -> void:
	if PlayerStats.current_stamina <= 0:
		story_text_label.append_text("\n\n[color=red][b]DEFEAT! Your Stamina has been depleted![/b][/color]")
		_scroll_to_bottom()
		StoryManager.go_to_section(str(CombatEngine.defeat_target_section))
	elif CombatEngine.enemy_stamina <= 0:
		story_text_label.append_text("\n\n[color=green][b]VICTORY! You defeated the %s![/b][/color]" % CombatEngine.enemy_name)
		_scroll_to_bottom()
		StoryManager.go_to_section(str(CombatEngine.victory_target_section))
	else:
		_render_fight_round_button()

func _clear_choice_container() -> void:
	for child in choice_container.get_children():
		choice_container.remove_child(child)
		child.queue_free()

func _setup_focus_loop_and_grab(buttons: Array[Button]) -> void:
	var count: int = buttons.size()
	for i in range(count):
		var btn: Button = buttons[i]
		var prev_btn: Button = buttons[(i - 1 + count) % count]
		var next_btn: Button = buttons[(i + 1) % count]
		btn.focus_neighbor_top = prev_btn.get_path()
		btn.focus_neighbor_bottom = next_btn.get_path()
		
	if count > 0:
		buttons[0].call_deferred("grab_focus")
