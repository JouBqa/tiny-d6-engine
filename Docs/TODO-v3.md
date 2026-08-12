### Development TODO List: Tiny RPG (Gamebook Edition) - v3

This document outlines the cumulative implementation plan for the TinyD6 Gamebook Engine, updated to support **Sir Albert and the Pudding of Perpetual Wobble** (from `Knight.md`).

---

##### Milestone 0: Project Architecture & Autoload Setup (COMPLETED)
- [x] Configure input map actions for UI navigation, keyboard, and D-pad support.
- [x] Create empty GDScript singletons and register them as Autoloads:
    * PlayerStats ➔ res://PlayerStats.gd
    * StoryManager ➔ res://StoryManager.gd
    * CombatEngine ➔ res://CombatEngine.gd

##### Milestone 1: Interactive Character Creation Screen (COMPLETED)
- [x] Implement manual rolling logic in PlayerStats.gd (1d6+6 for Skill/Luck, 2d6+12 for Stamina).
- [x] Set up Heroic Patience rolled on a single 1d6 to represent thin tolerance for bureaucracy.
- [x] Design character creation UI with manual "Roll" buttons that grab focus automatically.
- [x] Enable the "Begin Adventure" button once all stats are finalized.

##### Milestone 2: Dialogue UI & Basic Story Manager (COMPLETED)
- [x] Build narrative parser in StoryManager.gd using a local JSON-style database.
- [x] Design DialogueUI.tscn with ColorRect and MarginContainer styling.
- [x] Support BBCode in narrative RichTextLabel for colored text.
- [x] Implement focus-grabbing loop on choice buttons for mouse-free navigation.

##### Milestone 3: Simultaneous Combat Resolver with Luck Tests (COMPLETED)
- [x] Wire up simultaneous combat rounds: Player Strength (Skill + 2d6) vs Enemy Strength (Skill + 2d6).
- [x] Implement combat Luck Test options on wounding (Lucky: +2 damage, Unlucky: -1 damage) and being wounded (Lucky: -1 damage, Unlucky: +1 damage).
- [x] Apply Decaying Luck Rule (permanently deduct 1 Luck after each test).
- [x] Connect defeat condition to trigger default failure state on Stamina depletion.

##### Milestone 4: Mobile Usability & Platform Scaling (COMPLETED)
- [x] Widen VScrollBar touch targets in DialogueUI to 24px with high-visibility grabbers.
- [x] Enable direct swipe-to-scroll gestures on text blocks for mobile convenience.
- [x] Set project window stretch settings to "canvas_items" and aspect to "keep" for automatic pillarboxing on widescreen PC browsers while filling mobile screens perfectly.

---

##### Milestone 5: State-Tracking & Inventory Upgrades (PENDING)
- [ ] Upgrade PlayerStats.gd to store active inventory items in an Array (e.g., `item_tower_map`, `item_sturdy_rope`, `item_wooden_spoon`, `item_dusty_tome`, `item_calming_recipe`, `item_tower_key`).
- [ ] Create helper methods to manage inventory state:
    * `add_item(item_id: String) -> void`
    * `remove_item(item_id: String) -> void`
    * `has_item(item_id: String) -> bool`
- [ ] Implement a `story_flags` Dictionary in PlayerStats.gd to store quest progress, boolean state changes, and counter variables.
- [ ] Implement counter tracking for **Time Pressure** (`flag_time_pressure`) and decaying **Heroic Patience** triggers.

##### Milestone 6: Conditional Dialogue & Choice Requirements (PENDING)
- [ ] Expand the choice processing logic in DialogueUI.gd to evaluate choice requirements before rendering:
    * Disable or hide choices if the player lacks a required item (e.g., `item_tower_map` for the secret entrance).
    * Restrict choices based on boolean flags (e.g., `flag_quest_understood` required to ask Gerald politely).
- [ ] Upgrade StoryManager.gd navigation to process string-based Section IDs (e.g., `sec01_quest_briefing`) instead of simple integer strings.
- [ ] Build a consequence processor that applies state changes when choices are selected:
    * Set flags (e.g., setting `flag_pocket_friendly = true` after a successful trade).
    * Deduct stats (e.g., subtracting Stamina on a failed physical test).
    * Add or remove items from the active inventory.

##### Milestone 7: JSON Compilation of Pudding Quest (PENDING)
- [ ] Compile the complete 10-section narrative script from `Knight.md` (featuring Sir Albert Bumblethwaite) into a structured JSON database (`Knight.json`).
- [ ] Map out all stat tests (SKILL, LUCK, PATIENCE) with explicit target numbers and consequence profiles.
- [ ] Embed the Animated Broom Guardian combat encounter (Skill 6, Stamina 4) directly inside the lower tower section data.

##### Milestone 8: Ending Evaluation & Faction Epilogues (PENDING)
- [ ] Implement conditional routing in the story manager to resolve the 5 distinct endings of the Pudding Quest:
    * `ending_glorious_wobble` (Triumph: Pudding respected, not grabbed)
    * `ending_adequate_dessert` (Standard: Pudding obtained by force or compromise)
    * `ending_embarrassing_defeat` (Defeat: Stamina depletion during combat or traps)
    * `ending_pudding_refusal` (Failure: Failed negotiation with the Pudding)
    * `ending_tower_resident` (Unusual: Abandoning the quest to keep the Pudding company)
- [ ] Dynamically append relationship bonus text during the epilogue sequence depending on whether the player helped Agnes, befriended Pocket, or assisted Mildred.
- [ ] Hook the completed module up to MainMenu.gd for clean loading on startup.
