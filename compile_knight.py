#!/usr/bin/env python3
import json
import os
import re

def normalize_id(sec_id):
    if not sec_id:
        return "1"
    s = sec_id.strip()
    mapping = {
        "sec01quest_briefing": "sec01_quest_briefing",
        "sec02meadow_crossroads": "sec02_meadow_crossroads",
        "sec06tower_upper_mildred": "sec06_tower_upper_mildred",
        "sec07towerupper_bypass": "sec07_tower_upper_bypass",
        "sec09pudding_negotiation": "sec09_pudding_negotiation",
        "sec10return_triumph": "sec10_return_triumph"
    }
    return mapping.get(s, s)

def parse_knight_markdown(md_path):
    if not os.path.exists(md_path):
        print(f"[Compiler Error] File not found: {md_path}")
        return {}

    with open(md_path, "r", encoding="utf-8") as f:
        content = f.read()

    sections = re.findall(r'\[SECTION:\s*([\w_]+)\](.*?)\[/SECTION\]', content, re.DOTALL)
    if not sections:
        print(f"[Compiler Warning] No [SECTION] tags found in {md_path}")
        return {}

    database = {
        "title": "Sir Albert and the Pudding of Perpetual Wobble"
    }

    sec_map = {}

    for raw_id, sec_body in sections:
        sec_id = normalize_id(raw_id)
        
        # 1. Section Title
        title_match = re.search(r'SECTION_TITLE:\s*(.*)', sec_body)
        sec_title = title_match.group(1).strip() if title_match else sec_id

        # 2. Extract Full Narrative Prose (Every paragraph down to AUTOMATIC_ITEMS/CHOICES/COMBAT)
        narr_match = re.search(r'NARRATIVE:\s*(.*?)(?=\n(?:AUTOMATIC_ITEMS|CHOICES|COMBAT|---|\Z))', sec_body, re.DOTALL)
        narr_text = narr_match.group(1).strip() if narr_match else ""
        
        # Split prose by double linebreaks (paragraphs) into balanced pages (~600-900 chars per page)
        paragraphs = [p.strip() for p in narr_text.split('\n\n') if p.strip()]
        pages = []
        curr_page = []
        curr_len = 0
        
        for p in paragraphs:
            if curr_len + len(p) > 750 and curr_page:
                pages.append('\n\n'.join(curr_page))
                curr_page = [p]
                curr_len = len(p)
            else:
                curr_page.append(p)
                curr_len += len(p)
        if curr_page:
            pages.append('\n\n'.join(curr_page))

        # 3. Parse Automatic Items & Consequences
        automatic_items = []
        auto_match = re.search(r'AUTOMATIC_ITEMS:(.*?)(?=\n(?:CHOICES|COMBAT|---|\Z))', sec_body, re.DOTALL)
        if auto_match:
            item_lines = re.findall(r'ADD:\s*([\w_]+)', auto_match.group(1))
            for it in item_lines:
                automatic_items.append(it.strip())

        consequences = {}
        if automatic_items:
            consequences["items_added"] = automatic_items

        # 4. Parse Combat Encounters
        combat_data = None
        combat_match = re.search(r'COMBAT(?:_ENCOUNTER)?:\s*(.*?)(?=\n(?:CHOICES|AUTOMATIC_ITEMS|---|\Z))', sec_body, re.DOTALL)
        if combat_match:
            c_text = combat_match.group(1)
            name_m = re.search(r'ENEMY_NAME:\s*(.*)', c_text)
            skill_m = re.search(r'ENEMY_SKILL:\s*(\d+)', c_text)
            stam_m = re.search(r'ENEMY_STAMINA:\s*(\d+)', c_text)
            vic_m = re.search(r'VICTORY_TARGET:\s*([\w_]+)', c_text)
            def_m = re.search(r'DEFEAT_TARGET:\s*([\w_]+)', c_text)
            if name_m and skill_m and stam_m:
                combat_data = {
                    "enemy_name": name_m.group(1).strip(),
                    "enemy_skill": int(skill_m.group(1)),
                    "enemy_stamina": int(stam_m.group(1)),
                    "victory_target": normalize_id(vic_m.group(1)) if vic_m else "sec05_tower_lower",
                    "defeat_target": normalize_id(def_m.group(1)) if def_m else "ending_embarrassing_defeat"
                }

        # 5. Parse Choices
        parsed_choices = []
        choices_block = re.search(r'CHOICES:(.*)', sec_body, re.DOTALL)
        if choices_block:
            raw_choices = re.findall(r'CHOICE\s*\d+:(.*?)(?=\nCHOICE\s*\d+:|\Z)', choices_block.group(1), re.DOTALL)
            for rc in raw_choices:
                text_m = re.search(r'TEXT:\s*(.*)', rc)
                target_m = re.search(r'TARGET:\s*([\w_]+)', rc)
                req_m = re.search(r'REQUIREMENTS:\s*(.*)', rc)
                stat_m = re.search(r'STAT:\s*([\w_]+)', rc)
                fail_m = re.search(r'FAILURE_OUTCOME:\s*([\w_]+)', rc)
                
                if not text_m or not target_m:
                    continue
                    
                choice_obj = {
                    "text": text_m.group(1).strip(),
                    "target": normalize_id(target_m.group(1))
                }
                
                # Check for Stat Tests (PATIENCE, SKILL, LUCK)
                if stat_m and stat_m.group(1).strip().upper() != "NONE":
                    choice_obj["test_type"] = stat_m.group(1).strip().lower()
                    if fail_m and fail_m.group(1).strip().upper() != "N/A":
                        choice_obj["target_fail"] = normalize_id(fail_m.group(1))
                    else:
                        choice_obj["target_fail"] = choice_obj["target"]
                        
                # Check for Requirements
                if req_m:
                    req_str = req_m.group(1).strip()
                    if "ITEM:" in req_str:
                        item_req = re.search(r'ITEM:\s*([\w_]+)', req_str)
                        if item_req:
                            choice_obj["requirements"] = {"item": item_req.group(1).strip()}
                    elif "FLAG_TRUE:" in req_str:
                        flag_req = re.search(r'FLAG_TRUE:\s*([\w_]+)', req_str)
                        if flag_req:
                            choice_obj["requirements"] = {"flag_true": flag_req.group(1).strip()}

                # Check for Choice Consequences
                cons_block = re.search(r'CONSEQUENCES:(.*?)(?=\nTARGET:|\Z)', rc, re.DOTALL)
                if cons_block:
                    c_text = cons_block.group(1)
                    flag_set = re.search(r'SET_FLAG:\s*([\w_]+)\s*=\s*(true|false|\d+)', c_text, re.IGNORECASE)
                    item_add = re.search(r'ITEMS_ADDED:\s*([\w_]+)', c_text)
                    item_rem = re.search(r'ITEMS_REMOVED:\s*([\w_]+)', c_text)
                    stam_ch = re.search(r'STAMINA_CHANGE:\s*([+-]?\d+)', c_text)
                    
                    choice_cons = {}
                    if flag_set:
                        val_str = flag_set.group(2).lower()
                        val = True if val_str == "true" else (False if val_str == "false" else int(val_str))
                        choice_cons["set_flags"] = {flag_set.group(1): val}
                    if item_add and item_add.group(1).strip().upper() != "NONE":
                        choice_cons["items_added"] = [item_add.group(1).strip()]
                    if item_rem and item_rem.group(1).strip().upper() != "NONE":
                        choice_cons["items_removed"] = [item_rem.group(1).strip()]
                    if stam_ch:
                        choice_cons["stamina_change"] = int(stam_ch.group(1))
                        
                    if choice_cons:
                        choice_obj["consequences"] = choice_cons

                parsed_choices.append(choice_obj)

        sec_data = {
            "title": sec_title,
            "text": narr_text,
            "pages": pages,
            "choices": parsed_choices
        }
        if consequences:
            sec_data["consequences"] = consequences
        if combat_data:
            sec_data["combat"] = combat_data

        database[sec_id] = sec_data
        sec_map[sec_id] = sec_data

        print(f"Section [{sec_id}]: Compiled {len(narr_text)} characters across {len(pages)} pages.")

    # Create convenient shortcuts for section numeric IDs ("1", "2", etc.)
    num_shortcuts = {
        "1": "sec01_quest_briefing",
        "2": "sec02_meadow_crossroads",
        "3": "sec03_grumbleton_village",
        "4": "sec04_tower_entrance",
        "5": "sec05_tower_lower",
        "6": "sec06_tower_upper_mildred",
        "7": "sec07_tower_upper_bypass",
        "8": "sec08_pudding_chamber",
        "9": "sec09_pudding_negotiation",
        "10": "sec10_return_triumph"
    }

    for num_key, target_sec_id in num_shortcuts.items():
        if target_sec_id in database:
            database[num_key] = database[target_sec_id]

    # Include the 5 ending nodes explicitly
    endings = {
        "ending_glorious_wobble": {
            "title": "Victory: Glorious Wobble",
            "text": "[color=green][b]VICTORY: GLORIOUS WOBBLE![/b][/color]\n\nAs you recite the Calming Recipe with deep respect, the Pudding of Perpetual Wobble trembles in perfect, joyful harmony! It settles gently into your velvet container. Lord Gerald declares your mission a triumph of ministerial diplomacy! You are awarded the Gold Medal of Dessert Preservation.",
            "pages": [
                "[color=green][b]VICTORY: GLORIOUS WOBBLE![/b][/color]\n\nAs you recite the Calming Recipe with deep respect, the Pudding of Perpetual Wobble trembles in perfect, joyful harmony! It settles gently into your velvet container.",
                "Lord Gerald declares your mission a triumph of ministerial diplomacy! You are awarded the Gold Medal of Dessert Preservation."
            ],
            "choices": [{"text": "Claim Heroic Victory", "target": "victory_screen", "is_victory": True}]
        },
        "ending_adequate_dessert": {
            "title": "Victory: Adequate Dessert",
            "text": "[color=yellow][b]VICTORY: ADEQUATE DESSERT[/b][/color]\n\nYou secure the Pudding! Though slightly squished from the journey, Lord Gerald accepts it into the Royal Vaults with a nodding seal of approval. You receive your standard knightly stipend.",
            "pages": [
                "[color=yellow][b]VICTORY: ADEQUATE DESSERT[/b][/color]\n\nYou secure the Pudding! Though slightly squished from the journey, Lord Gerald accepts it into the Royal Vaults with a nodding seal of approval. You receive your standard knightly stipend."
            ],
            "choices": [{"text": "Claim Victory", "target": "victory_screen", "is_victory": True}]
        },
        "ending_embarrassing_defeat": {
            "title": "Defeat: Embarrassing Defeat",
            "text": "[color=red][b]PHYSICAL DEFEAT[/b][/color]\n\nYour Stamina has been depleted! The Animated Broom Guardian sweeps you out of the tower into a pile of dry leaves. Lord Gerald hands you an Official Heroic Defeat Waiver.",
            "pages": [
                "[color=red][b]PHYSICAL DEFEAT[/b][/color]\n\nYour Stamina has been depleted! The Animated Broom Guardian sweeps you out of the tower into a pile of dry leaves. Lord Gerald hands you an Official Heroic Defeat Waiver."
            ],
            "choices": [{"text": "Sign the waiver and try again.", "target": "1"}]
        },
        "ending_pudding_refusal": {
            "title": "Failure: Pudding Refusal",
            "text": "[color=red][b]MISSION FAILURE[/b][/color]\n\nYour clumsy grab offends the Pudding's delicate sensibilities! It emits a loud splat and wobbles aggressively out the tower window into the moat below. Lord Gerald is deeply disappointed.",
            "pages": [
                "[color=red][b]MISSION FAILURE[/b][/color]\n\nYour clumsy grab offends the Pudding's delicate sensibilities! It emits a loud splat and wobbles aggressively out the tower window into the moat below. Lord Gerald is deeply disappointed."
            ],
            "choices": [{"text": "Try again.", "target": "1"}]
        },
        "ending_tower_resident": {
            "title": "Unusual Ending: Tower Resident",
            "text": "[color=cyan][b]UNUSUAL ENDING: TOWER RESIDENT[/b][/color]\n\nYou realize that questing is overrated. You pull up a chair, share a snack with Mildred and Pocket, and spend the rest of your days admiring the soothing, perpetual wobble of the Pudding.",
            "pages": [
                "[color=cyan][b]UNUSUAL ENDING: TOWER RESIDENT[/b][/color]\n\nYou realize that questing is overrated. You pull up a chair, share a snack with Mildred and Pocket, and spend the rest of your days admiring the soothing, perpetual wobble of the Pudding."
            ],
            "choices": [{"text": "Restart Adventure", "target": "1"}]
        }
    }

    for end_id, end_data in endings.items():
        database[end_id] = end_data

    return database

def main():
    md_path = "Docs/Knight.md"
    out_path = "Adventures/Knight.json"
    
    print("[Compiler] Extracting full long-form narrative prose from Docs/Knight.md...")
    db = parse_knight_markdown(md_path)
    if not db:
        print("[Compiler] Failed to parse Markdown file.")
        return

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2)

    print(f"\n[Compiler Success] Wrote {out_path} with {len(db)} entries!")

if __name__ == "__main__":
    main()
