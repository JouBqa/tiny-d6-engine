extends Control

# Static preloads for Web export PCK bundling
const SCENE_MAIN_MENU = preload("res://UI/MainMenu.tscn")
const SCENE_VICTORY_SCREEN = preload("res://UI/VictoryScreen.tscn")
const SCENE_CHARACTER_CREATION = preload("res://UI/CharacterCreation.tscn")

const ICON_DICE = preload("res://Art/dice.png")
const ICON_SWORD = preload("res://Art/sword.png")
const ICON_HEART = preload("res://Art/heart.png")

@onready var story_text_label: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/StoryTextLabel
@onready var choice_scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/ChoiceScrollContainer
@onready var choice_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ChoiceScrollContainer/ChoiceContainer
@onready var title_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TopBarContainer/TitleLabel")
@onready var ribbon_button: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TopBarContainer/RibbonButton")
@onready var bookmark_modal: Control = get_node_or_null("BookmarkModal")
@onready var modal_slots_container: VBoxContainer = get_node_or_null("BookmarkModal/MarginContainer/VBoxContainer/SlotsContainer")
@onready var modal_close_button: Button = get_node_or_null("BookmarkModal/MarginContainer/VBoxContainer/CloseButton")

@onready var skl_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/StatsHUDContainer/SklLabel")
@onready var stam_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/StatsHUDContainer/StamLabel")
@onready var lck_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/StatsHUDContainer/LckLabel")
@onready var pat_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/StatsHUDContainer/PatLabel")

var _handling_loss_state: bool = false
var _typewriter_tween: Tween
var _is_typing: bool = false

var _touch_dragging: bool = false
var _touch_last_y: float = 0.0

func _ready() -> void:
	_apply_safe_area_margins()
	_setup_touch_controller()
	
	if ribbon_button:
		ribbon_button.pressed.connect(_open_bookmark_modal)
	if modal_close_button:
		modal_close_button.pressed.connect(_close_bookmark_modal)
		
	# Configure title label dynamically matching loaded adventure
	if title_label:
		title_label.text = StoryManager.get_adventure_title()
		
	# Disable scroll_following so text does not jump to bottom on page render
	story_text_label.scroll_following = false
	
	# Configure 24px wide touch scrollbar target & style
	_configure_touch_scrollbar()
	
	# Connect direct touch swipe-to-scroll on story text label
	story_text_label.gui_input.connect(_on_story_text_gui_input)
	
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
		if StoryManager.has_autosave_state():
			var save_data = StoryManager.load_autosave_state()
			if not save_data.is_empty():
				current_page_index = int(save_data.get("current_page_index", 0))
		_render_current_page(current_data)
		
	_update_stats_hud()

func _apply_safe_area_margins() -> void:
	var safe_area: Rect2 = DisplayServer.get_display_safe_area()
	if safe_area.size.y > 0 and safe_area.position.y > 0:
		var top_offset: int = int(safe_area.position.y)
		var margin_container = get_node_or_null("PanelContainer/MarginContainer")
		if margin_container:
			margin_container.add_theme_constant_override("margin_top", 24 + top_offset)

func _setup_touch_controller() -> void:
	var touch_ctrl = TouchController.new()
	add_child(touch_ctrl)
	touch_ctrl.swipe_left.connect(_on_touch_forward)
	touch_ctrl.tap_right_edge.connect(_on_touch_forward)
	touch_ctrl.swipe_right.connect(_on_touch_backward)
	touch_ctrl.tap_left_edge.connect(_on_touch_backward)

func _on_touch_forward() -> void:
	if _is_typing:
		_skip_typewriter_effect()
		return
	var current_data: Dictionary = StoryManager.get_current_section_data()
	var pages: Array = current_data.get("pages", [current_data.get("text", "")])
	if current_page_index < pages.size() - 1:
		current_page_index += 1
		_render_current_page(current_data)

func _on_touch_backward() -> void:
	if current_page_index > 0:
		current_page_index -= 1
		var current_data: Dictionary = StoryManager.get_current_section_data()
		_render_current_page(current_data)

func _open_bookmark_modal() -> void:
	if not bookmark_modal or not modal_slots_container:
		return
	_populate_bookmark_slots()
	bookmark_modal.visible = true

func _close_bookmark_modal() -> void:
	if bookmark_modal:
		bookmark_modal.visible = false

func _populate_bookmark_slots() -> void:
	for child in modal_slots_container.get_children():
		modal_slots_container.remove_child(child)
		child.queue_free()
		
	for i in range(1, 4):
		var slot_box = HBoxContainer.new()
		slot_box.custom_minimum_size = Vector2(0, 52)
		
		var info_label = Label.new()
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.add_theme_font_size_override("font_size", 16)
		
		var has_b = StoryManager.has_bookmark(i)
		if has_b:
			var b_data = StoryManager.get_bookmark_info_dict(i)
			var sec_t = b_data.get("section_title", "Section " + str(b_data.get("current_section_id", "1")))
			info_label.text = "Slot %d: %s (p. %d)" % [i, sec_t, int(b_data.get("current_page_index", 0)) + 1]
		else:
			info_label.text = "Slot %d: [Empty Bookmark]" % i
			
		slot_box.add_child(info_label)
		
		var save_btn = Button.new()
		save_btn.text = " Save "
		save_btn.custom_minimum_size = Vector2(75, 44)
		save_btn.add_theme_font_size_override("font_size", 16)
		var slot_idx_s = i
		save_btn.pressed.connect(func():
			StoryManager.save_bookmark(slot_idx_s, current_page_index)
			_populate_bookmark_slots()
		)
		slot_box.add_child(save_btn)
		
		var load_btn = Button.new()
		load_btn.text = " Load "
		load_btn.custom_minimum_size = Vector2(75, 44)
		load_btn.add_theme_font_size_override("font_size", 16)
		load_btn.disabled = not has_b
		var slot_idx_l = i
		load_btn.pressed.connect(func():
			var b_data = StoryManager.load_bookmark(slot_idx_l)
			if not b_data.is_empty():
				current_page_index = int(b_data.get("current_page_index", 0))
				var current_data = StoryManager.get_current_section_data()
				_render_current_page(current_data)
				_update_stats_hud()
				_close_bookmark_modal()
		)
		slot_box.add_child(load_btn)
		
		modal_slots_container.add_child(slot_box)

func _configure_touch_scrollbar() -> void:
	var scrollbar = story_text_label.get_v_scroll_bar()
	if scrollbar:
		scrollbar.custom_minimum_size = Vector2(24, 0)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.8, 0.6, 0.2, 0.8)
		sb.set_corner_radius_all(6)
		scrollbar.add_theme_stylebox_override("grabber", sb)
		scrollbar.add_theme_stylebox_override("grabber_highlight", sb)
		scrollbar.add_theme_stylebox_override("grabber_pressed", sb)

func _on_story_text_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_dragging = true
			_touch_last_y = event.position.y
		else:
			_touch_dragging = false
	elif event is InputEventScreenDrag and _touch_dragging:
		var delta_y: float = _touch_last_y - event.position.y
		_touch_last_y = event.position.y
		var scrollbar = story_text_label.get_v_scroll_bar()
		if scrollbar:
			scrollbar.value += delta_y
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch_dragging = true
				_touch_last_y = event.position.y
			else:
				_touch_dragging = false
	elif event is InputEventMouseMotion and _touch_dragging:
		var delta_y: float = _touch_last_y - event.position.y
		_touch_last_y = event.position.y
		var scrollbar = story_text_label.get_v_scroll_bar()
		if scrollbar:
			scrollbar.value += delta_y

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
		_scroll_to_top()
	)

func _skip_typewriter_effect() -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	story_text_label.visible_ratio = 1.0
	_is_typing = false
	_scroll_to_top()

## Scroll to Top Helper
func _scroll_to_top() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if story_text_label:
		story_text_label.scroll_to_line(0)
	var scrollbar = story_text_label.get_v_scroll_bar()
	if scrollbar:
		scrollbar.value = 0

## Automatic Scrolling Fix (CRITICAL)
## Yields a frame to recalculate text layout, then programmatically forces vertical scrollbar to max_value
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if story_text_label:
		story_text_label.scroll_to_line(max(0, story_text_label.get_line_count() - 1))
		var scrollbar = story_text_label.get_v_scroll_bar()
		if scrollbar:
			scrollbar.value = scrollbar.max_value

func _update_stats_hud() -> void:
	if skl_label:
		skl_label.text = "SKL: %d" % PlayerStats.skill
	if stam_label:
		stam_label.text = "STAM: %d/%d" % [PlayerStats.current_stamina, PlayerStats.stamina]
	if lck_label:
		lck_label.text = "LCK: %d" % PlayerStats.current_luck
	if pat_label:
		pat_label.text = "PAT: %d" % PlayerStats.current_patience

## Appends dynamic bonus epilogue text based on story flags
func _append_epilogue_bonus_text() -> void:
	var sec_id: String = StoryManager.current_section_id
	if not sec_id.begins_with("ending_") and sec_id != "8" and sec_id != "10":
		return
		
	var bonus_text: String = ""
	if PlayerStats.get_flag("flag_agnes_helped", false):
		bonus_text += "\n\n[color=yellow][b]Epilogue (Agnes):[/b] Sister Agnes sends you a warm loaf of herbal trail-bread and a note of gratitude for your assistance.[/color]"
	if PlayerStats.get_flag("flag_pocket_friendly", false):
		bonus_text += "\n\n[color=yellow][b]Epilogue (Pocket):[/b] Pocket the Goblin opens a small souvenir stand near the Custard Tower, selling shiny brass buttons and sturdy ropes.[/color]"
	if PlayerStats.get_flag("flag_mildred_helped", false):
		bonus_text += "\n\n[color=yellow][b]Epilogue (Mildred):[/b] Alchemist Mildred names her newest soothing potion 'Bumblethwaite's Calm' in honor of your respectful conduct.[/color]"
		
	if bonus_text != "":
		story_text_label.append_text(bonus_text)

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
	if StoryManager.current_section_id == "6" or StoryManager.current_section_id == "10" or StoryManager.current_section_id == "ending_embarrassing_defeat":
		return
		
	_handling_loss_state = true
	print("[DialogueUI] Physical Defeat triggered: Stamina reached 0!")
	CombatEngine.in_combat = false
	story_text_label.append_text("\n\n[color=red][b]PHYSICAL DEFEAT: Your Stamina has been depleted![/b][/color]")
	_scroll_to_bottom()
	_clear_choice_container()
	if StoryManager.story_database.has("ending_embarrassing_defeat"):
		StoryManager.go_to_section("ending_embarrassing_defeat")
	else:
		_render_continue_button("6")
	_handling_loss_state = false

var current_page_index: int = 0

func _on_section_changed(section_data: Dictionary) -> void:
	if title_label:
		title_label.text = StoryManager.get_adventure_title()
	_display_section(section_data)
	_update_stats_hud()

## Displays narrative section with Page-Turning support
func _display_section(section_data: Dictionary) -> void:
	current_page_index = 0
	
	# Apply section entry consequences if present (e.g. automatic items/flags on section load)
	if section_data.has("consequences"):
		_apply_choice_consequences({"consequences": section_data["consequences"]})
		
	_render_current_page(section_data)

## Renders the current page string and either page-turning button or final choices
func _render_current_page(section_data: Dictionary) -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	_is_typing = false
	
	story_text_label.clear()
	var pages: Array = section_data.get("pages", [section_data.get("text", "")])
	if pages.is_empty():
		pages = [section_data.get("text", "")]
		
	current_page_index = clamp(current_page_index, 0, max(0, pages.size() - 1))
	story_text_label.text = str(pages[current_page_index])
	
	# Autosave game state at active section and page index
	StoryManager.save_autosave_state(current_page_index)
	
	# Append epilogue bonus text on the final page of ending sections
	if current_page_index == pages.size() - 1:
		_append_epilogue_bonus_text()
		
	_start_typewriter_effect()
	_scroll_to_top()
	
	# Page-Turning Control:
	# If player has not reached the last page of the section, render "Turn Page ->" button
	if current_page_index < pages.size() - 1:
		_render_turn_page_button(section_data)
	else:
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

## Renders the single focus-grabbed "Turn Page" button for multi-page sections
func _render_turn_page_button(section_data: Dictionary) -> void:
	_clear_choice_container()
	
	var page_btn: Button = Button.new()
	page_btn.text = "  Turn Page  "
	page_btn.custom_minimum_size = Vector2(0, 48)
	page_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_btn.add_theme_font_size_override("font_size", 18)
	
	page_btn.pressed.connect(func():
		current_page_index += 1
		_render_current_page(section_data)
	)
	
	choice_container.add_child(page_btn)
	_setup_focus_loop_and_grab([page_btn])

## Helper to evaluate whether choice requirements are met
func _check_choice_requirements(choice: Dictionary) -> bool:
	if not choice.has("requirements"):
		return true
	var reqs: Dictionary = choice["requirements"]
	
	if reqs.has("item"):
		if not PlayerStats.has_item(str(reqs["item"])):
			return false
	if reqs.has("no_item"):
		if PlayerStats.has_item(str(reqs["no_item"])):
			return false
	if reqs.has("flag_true"):
		if not bool(PlayerStats.get_flag(str(reqs["flag_true"]), false)):
			return false
	if reqs.has("flag_false"):
		if bool(PlayerStats.get_flag(str(reqs["flag_false"]), false)):
			return false
			
	return true

## Helper to apply choice consequences (flags, inventory items, stamina change)
func _apply_choice_consequences(choice: Dictionary) -> void:
	if not choice.has("consequences"):
		return
	var cons: Dictionary = choice["consequences"]
	
	if cons.has("set_flags"):
		var flags_to_set: Dictionary = cons["set_flags"]
		for flag_id in flags_to_set:
			PlayerStats.set_flag(str(flag_id), flags_to_set[flag_id])
			
	if cons.has("items_added"):
		var items: Array = cons["items_added"]
		for item in items:
			PlayerStats.add_item(str(item))
			
	if cons.has("items_removed"):
		var items: Array = cons["items_removed"]
		for item in items:
			PlayerStats.remove_item(str(item))
			
	if cons.has("stamina_change"):
		var change: int = int(cons["stamina_change"])
		if change > 0:
			PlayerStats.current_stamina = min(PlayerStats.stamina, PlayerStats.current_stamina + change)
			PlayerStats.stats_changed.emit()
		elif change < 0:
			PlayerStats.deduct_stamina(abs(change))

## Renders standard branching narrative choice buttons
func _render_narrative_choices(choices: Array) -> void:
	_clear_choice_container()
	var instantiated_buttons: Array[Button] = []
	var choice_num: int = 1
	
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		if not _check_choice_requirements(choice):
			continue
			
		var btn: Button = Button.new()
		btn.text = "  [%d]  %s" % [choice_num, choice.get("text", "")]
		choice_num += 1
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 18)
		
		btn.pressed.connect(func(): _on_choice_pressed(choice))
		
		choice_container.add_child(btn)
		instantiated_buttons.append(btn)
	
	_setup_focus_loop_and_grab(instantiated_buttons)

## Manual "Page Forward" Transition Button ("Continue")
func _render_continue_button(next_section_id: String) -> void:
	_clear_choice_container()
	
	var continue_btn: Button = Button.new()
	continue_btn.text = "  Continue  "
	continue_btn.custom_minimum_size = Vector2(0, 48)
	continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_btn.add_theme_font_size_override("font_size", 18)
	
	continue_btn.pressed.connect(func():
		if next_section_id == "victory_screen":
			_on_victory_screen_transition()
		else:
			StoryManager.go_to_section(next_section_id)
	)
	
	choice_container.add_child(continue_btn)
	_setup_focus_loop_and_grab([continue_btn])

func _on_choice_pressed(choice: Dictionary) -> void:
	_skip_typewriter_effect()
	
	# Apply choice consequences (flags, items, stamina)
	_apply_choice_consequences(choice)
	
	var target_sec: String = str(choice.get("target", "1"))
	
	# Check if choice triggers Victory Screen transition
	if target_sec == "victory_screen" or choice.get("is_victory", false):
		_on_victory_screen_transition()
		return
	
	# Apply inline patience_change if present
	if choice.has("patience_change"):
		var change: int = int(choice["patience_change"])
		if change < 0:
			PlayerStats.deduct_patience(abs(change))
			if PlayerStats.current_patience <= 0:
				return # patience_depleted signal automatically handles redirect
				
	# Process stat tests (patience, skill, luck) if specified
	if choice.has("test_type"):
		_resolve_choice_stat_test(choice)
		return
		
	var text_str: String = str(choice.get("text", ""))
	
	# Check if this choice restarts the run back to MainMenu.tscn
	if target_sec == "1" and (text_str.contains("Restart") or text_str.contains("try again") or text_str.contains("try adventuring again") or text_str.contains("Sign the waiver")):
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
		var d1 = randi_range(1, 6)
		var d2 = randi_range(1, 6)
		roll_val = d1 + d2
		is_success = roll_val <= target_val
		var res_tag = "[color=green]SUCCESS![/color]" if is_success else "[color=red]FAILED![/color]"
		story_text_label.append_text("\n\nHeroic Patience Test! Rolled 2d6 [%d, %d] = %d vs Heroic Patience (%d) -> %s" % [
			d1, d2, roll_val, target_val, res_tag
		])
		_scroll_to_bottom()
		
		# Decay Rule: Immediately after any Patience test is rolled, deduct 1 point of current Patience
		PlayerStats.deduct_patience(1)
		
		# Sanity Loss Trigger: If current_patience reaches 0, transition to Bed & Breakfast ending (Section 10)
		if PlayerStats.current_patience <= 0:
			_clear_choice_container()
			_render_continue_button("10")
			return
	elif test_type == "skill":
		target_val = PlayerStats.skill
		var d1 = randi_range(1, 6)
		var d2 = randi_range(1, 6)
		roll_val = d1 + d2
		is_success = roll_val <= target_val
		var res_tag = "[color=green]SUCCESS![/color]" if is_success else "[color=red]FAILED![/color]"
		story_text_label.append_text("\n\nSkill Test! Rolled 2d6 [%d, %d] = %d vs Skill (%d) -> %s" % [
			d1, d2, roll_val, target_val, res_tag
		])
		_scroll_to_bottom()
	elif test_type == "luck":
		target_val = PlayerStats.current_luck
		PlayerStats.deduct_luck(1)
		var d1 = randi_range(1, 6)
		var d2 = randi_range(1, 6)
		roll_val = d1 + d2
		is_success = roll_val <= target_val
		var res_tag = "[color=green]LUCKY![/color]" if is_success else "[color=red]UNLUCKY![/color]"
		story_text_label.append_text("\n\nLuck Test! Rolled 2d6 [%d, %d] = %d vs Current Luck (%d) -> %s" % [
			d1, d2, roll_val, target_val, res_tag
		])
	var next_sec: String = target_win if is_success else target_fail
	_render_continue_button(next_sec)

## Transitions to dedicated VictoryScreen.tscn
func _on_victory_screen_transition() -> void:
	print("[DialogueUI] Victory condition achieved! Transitioning to VictoryScreen...")
	StoryManager.clear_autosave_state()
	CombatEngine.in_combat = false
	get_tree().change_scene_to_file("res://UI/VictoryScreen.tscn")

## Restarts the game clean: resets stats and transitions back to MainMenu.tscn
func _on_restart_pressed() -> void:
	print("[DialogueUI] Resetting PlayerStats and returning to MainMenu screen...")
	StoryManager.clear_autosave_state()
	CombatEngine.in_combat = false
	PlayerStats.reset_stats()
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

## Renders the "Fight Round" button at start of combat step
func _render_fight_round_button() -> void:
	_clear_choice_container()
	
	var fight_btn: Button = Button.new()
	fight_btn.icon = ICON_SWORD
	fight_btn.text = "  Fight Round %d vs %s (Skill: %d, Stamina: %d)" % [
		CombatEngine.round_count + 1,
		CombatEngine.enemy_name,
		CombatEngine.enemy_skill,
		CombatEngine.enemy_stamina
	]
	fight_btn.custom_minimum_size = Vector2(0, 48)
	fight_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fight_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fight_btn.add_theme_font_size_override("font_size", 16)
	fight_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fight_btn.pressed.connect(_on_fight_round_pressed)
	
	choice_container.add_child(fight_btn)
	_setup_focus_loop_and_grab([fight_btn])

## Executes combat round calculation with color-coded Player Total (green) & Enemy Total (red)
func _on_fight_round_pressed() -> void:
	_skip_typewriter_effect()
	var round_data: Dictionary = CombatEngine.roll_round()
	if round_data.is_empty():
		return
		
	var winner: String = round_data["winner"]
	var result_str: String = "Standoff!"
	if winner == "player":
		result_str = "[color=green]Hit![/color]"
	elif winner == "enemy":
		result_str = "[color=red]Wounded![/color]"
		
	var log_entry = "\n\nRound %d: Player rolls [%d, %d] + Skill (%d) = [color=green]Player Total: %d[/color] vs %s rolls [%d, %d] + Skill (%d) = [color=red]Enemy Total: %d[/color]. %s" % [
		round_data["round"],
		round_data["player_dice"][0],
		round_data["player_dice"][1],
		round_data["player_skill"],
		round_data["player_as"],
		CombatEngine.enemy_name,
		round_data["enemy_dice"][0],
		round_data["enemy_dice"][1],
		round_data["enemy_skill"],
		round_data["enemy_as"],
		result_str
	]
	story_text_label.append_text(log_entry)
	_scroll_to_bottom()
	
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
	luck_btn.icon = ICON_DICE
	luck_btn.text = "  Test Luck to Increase Damage! (Luck: %d)" % PlayerStats.current_luck
	luck_btn.custom_minimum_size = Vector2(0, 48)
	luck_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	luck_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	luck_btn.add_theme_font_size_override("font_size", 16)
	luck_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	luck_btn.pressed.connect(func(): _resolve_luck_test(true))
	choice_container.add_child(luck_btn)
	buttons.append(luck_btn)
	
	var standard_btn: Button = Button.new()
	standard_btn.icon = ICON_SWORD
	standard_btn.text = "  Accept Standard Damage (Deal 2 Damage)"
	standard_btn.custom_minimum_size = Vector2(0, 48)
	standard_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	standard_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	standard_btn.add_theme_font_size_override("font_size", 16)
	standard_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	standard_btn.pressed.connect(func(): _resolve_base_wounding(true))
	choice_container.add_child(standard_btn)
	buttons.append(standard_btn)
	
	_setup_focus_loop_and_grab(buttons)

## Enemy hit player: present "Test Luck to Mitigate Damage" vs "Accept Standard Damage"
func _render_enemy_hit_luck_choices() -> void:
	_clear_choice_container()
	var buttons: Array[Button] = []
	
	var luck_btn: Button = Button.new()
	luck_btn.icon = ICON_DICE
	luck_btn.text = "  Test Luck to Mitigate Damage! (Luck: %d)" % PlayerStats.current_luck
	luck_btn.custom_minimum_size = Vector2(0, 48)
	luck_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	luck_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	luck_btn.add_theme_font_size_override("font_size", 16)
	luck_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	luck_btn.pressed.connect(func(): _resolve_luck_test(false))
	choice_container.add_child(luck_btn)
	buttons.append(luck_btn)
	
	var standard_btn: Button = Button.new()
	standard_btn.icon = ICON_HEART
	standard_btn.text = "  Accept Standard Damage (Suffer 2 Damage)"
	standard_btn.custom_minimum_size = Vector2(0, 48)
	standard_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	standard_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	standard_btn.add_theme_font_size_override("font_size", 16)
	standard_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var luck_str = "[color=green]Success (Lucky)![/color]" if res["is_lucky"] else "[color=red]Failure (Unlucky)![/color]"
	
	var luck_log = "\nPlayer tests Luck! Rolls [%d, %d] = %d vs Current Luck (%d). %s" % [
		res["luck_dice"][0],
		res["luck_dice"][1],
		res["luck_roll"],
		res["luck_target"],
		luck_str
	]
	story_text_label.append_text(luck_log)
	
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
		_render_continue_button(str(CombatEngine.defeat_target_section))
	elif CombatEngine.enemy_stamina <= 0:
		story_text_label.append_text("\n\n[color=green][b]VICTORY! You defeated the %s![/b][/color]" % CombatEngine.enemy_name)
		_scroll_to_bottom()
		_render_continue_button(str(CombatEngine.victory_target_section))
	else:
		_render_fight_round_button()

func _clear_choice_container() -> void:
	for child in choice_container.get_children():
		choice_container.remove_child(child)
		child.queue_free()
	if choice_scroll_container:
		choice_scroll_container.scroll_vertical = 0

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
