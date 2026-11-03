extends RefCounted
## Згенеровано tools/audio/slice_sfx.py — не редагувати вручну.

const SFX := {
	"revolver_shot": ["res://audio/sfx/revolver_shot_01.wav", "res://audio/sfx/revolver_shot_02.wav", "res://audio/sfx/revolver_shot_03.wav", "res://audio/sfx/revolver_shot_04.wav", "res://audio/sfx/revolver_shot_05.wav", "res://audio/sfx/revolver_shot_06.wav", "res://audio/sfx/revolver_shot_07.wav", "res://audio/sfx/revolver_shot_08.wav"],
	"rifle_shot": ["res://audio/sfx/rifle_shot_01.wav", "res://audio/sfx/rifle_shot_02.wav", "res://audio/sfx/rifle_shot_03.wav", "res://audio/sfx/rifle_shot_04.wav", "res://audio/sfx/rifle_shot_05.wav"],
	"reload_open": ["res://audio/sfx/reload_open_01.wav", "res://audio/sfx/reload_open_02.wav", "res://audio/sfx/reload_open_03.wav", "res://audio/sfx/reload_open_04.wav"],
	"reload_insert": ["res://audio/sfx/reload_insert_01.wav", "res://audio/sfx/reload_insert_02.wav", "res://audio/sfx/reload_insert_03.wav", "res://audio/sfx/reload_insert_04.wav", "res://audio/sfx/reload_insert_05.wav", "res://audio/sfx/reload_insert_06.wav", "res://audio/sfx/reload_insert_07.wav", "res://audio/sfx/reload_insert_08.wav"],
	"reload_close": ["res://audio/sfx/reload_close_01.wav", "res://audio/sfx/reload_close_02.wav", "res://audio/sfx/reload_close_03.wav", "res://audio/sfx/reload_close_04.wav"],
	"lever_cycle": ["res://audio/sfx/lever_cycle_01.wav", "res://audio/sfx/lever_cycle_02.wav", "res://audio/sfx/lever_cycle_03.wav", "res://audio/sfx/lever_cycle_04.wav", "res://audio/sfx/lever_cycle_05.wav", "res://audio/sfx/lever_cycle_06.wav", "res://audio/sfx/lever_cycle_07.wav", "res://audio/sfx/lever_cycle_08.wav"],
	"dry_click": ["res://audio/sfx/dry_click_01.wav", "res://audio/sfx/dry_click_02.wav", "res://audio/sfx/dry_click_03.wav", "res://audio/sfx/dry_click_04.wav", "res://audio/sfx/dry_click_05.wav", "res://audio/sfx/dry_click_06.wav", "res://audio/sfx/dry_click_07.wav", "res://audio/sfx/dry_click_08.wav"],
	"gun_twirl": ["res://audio/sfx/gun_twirl_01.wav", "res://audio/sfx/gun_twirl_02.wav", "res://audio/sfx/gun_twirl_03.wav", "res://audio/sfx/gun_twirl_04.wav"],
	"ricochet": ["res://audio/sfx/ricochet_01.wav", "res://audio/sfx/ricochet_02.wav", "res://audio/sfx/ricochet_03.wav", "res://audio/sfx/ricochet_04.wav", "res://audio/sfx/ricochet_05.wav", "res://audio/sfx/ricochet_06.wav", "res://audio/sfx/ricochet_07.wav"],
	"hit_coin": ["res://audio/sfx/hit_coin_01.wav", "res://audio/sfx/hit_coin_02.wav", "res://audio/sfx/hit_coin_03.wav", "res://audio/sfx/hit_coin_04.wav", "res://audio/sfx/hit_coin_05.wav", "res://audio/sfx/hit_coin_06.wav"],
	"hit_bone": ["res://audio/sfx/hit_bone_01.wav", "res://audio/sfx/hit_bone_02.wav", "res://audio/sfx/hit_bone_03.wav", "res://audio/sfx/hit_bone_04.wav", "res://audio/sfx/hit_bone_05.wav", "res://audio/sfx/hit_bone_06.wav", "res://audio/sfx/hit_bone_07.wav", "res://audio/sfx/hit_bone_08.wav"],
	"hit_wood": ["res://audio/sfx/hit_wood_01.wav", "res://audio/sfx/hit_wood_02.wav", "res://audio/sfx/hit_wood_03.wav", "res://audio/sfx/hit_wood_04.wav", "res://audio/sfx/hit_wood_05.wav", "res://audio/sfx/hit_wood_06.wav", "res://audio/sfx/hit_wood_07.wav", "res://audio/sfx/hit_wood_08.wav"],
	"hit_anvil": ["res://audio/sfx/hit_anvil_01.wav", "res://audio/sfx/hit_anvil_02.wav", "res://audio/sfx/hit_anvil_03.wav", "res://audio/sfx/hit_anvil_04.wav", "res://audio/sfx/hit_anvil_05.wav", "res://audio/sfx/hit_anvil_06.wav"],
	"hit_gong": ["res://audio/sfx/hit_gong_01.wav", "res://audio/sfx/hit_gong_02.wav", "res://audio/sfx/hit_gong_03.wav", "res://audio/sfx/hit_gong_04.wav"],
	"hit_rubber_chicken": ["res://audio/sfx/hit_rubber_chicken_01.wav", "res://audio/sfx/hit_rubber_chicken_02.wav", "res://audio/sfx/hit_rubber_chicken_03.wav", "res://audio/sfx/hit_rubber_chicken_04.wav", "res://audio/sfx/hit_rubber_chicken_05.wav", "res://audio/sfx/hit_rubber_chicken_06.wav", "res://audio/sfx/hit_rubber_chicken_07.wav", "res://audio/sfx/hit_rubber_chicken_08.wav"],
	"glass_bottle": ["res://audio/sfx/glass_bottle_01.wav", "res://audio/sfx/glass_bottle_02.wav", "res://audio/sfx/glass_bottle_03.wav", "res://audio/sfx/glass_bottle_04.wav", "res://audio/sfx/glass_bottle_05.wav", "res://audio/sfx/glass_bottle_06.wav", "res://audio/sfx/glass_bottle_07.wav", "res://audio/sfx/glass_bottle_08.wav"],
	"glass_window": ["res://audio/sfx/glass_window_01.wav", "res://audio/sfx/glass_window_02.wav", "res://audio/sfx/glass_window_03.wav", "res://audio/sfx/glass_window_04.wav"],
	"slowmo": ["res://audio/sfx/slowmo_01.wav", "res://audio/sfx/slowmo_02.wav"],
	"combo_break": ["res://audio/sfx/combo_break_01.wav", "res://audio/sfx/combo_break_02.wav", "res://audio/sfx/combo_break_03.wav", "res://audio/sfx/combo_break_04.wav"],
	"combo_up": ["res://audio/sfx/combo_up_01.wav", "res://audio/sfx/combo_up_02.wav", "res://audio/sfx/combo_up_03.wav", "res://audio/sfx/combo_up_04.wav"],
	"civilian_oops": ["res://audio/sfx/civilian_oops_01.wav", "res://audio/sfx/civilian_oops_02.wav", "res://audio/sfx/civilian_oops_03.wav", "res://audio/sfx/civilian_oops_04.wav", "res://audio/sfx/civilian_oops_05.wav", "res://audio/sfx/civilian_oops_06.wav"],
	"civilian_hic": ["res://audio/sfx/civilian_hic_01.wav", "res://audio/sfx/civilian_hic_02.wav", "res://audio/sfx/civilian_hic_03.wav", "res://audio/sfx/civilian_hic_04.wav", "res://audio/sfx/civilian_hic_05.wav", "res://audio/sfx/civilian_hic_06.wav", "res://audio/sfx/civilian_hic_07.wav", "res://audio/sfx/civilian_hic_08.wav"],
	"star": ["res://audio/sfx/star_01.wav", "res://audio/sfx/star_02.wav", "res://audio/sfx/star_03.wav", "res://audio/sfx/star_04.wav"],
	"cash": ["res://audio/sfx/cash_01.wav", "res://audio/sfx/cash_02.wav", "res://audio/sfx/cash_03.wav", "res://audio/sfx/cash_04.wav", "res://audio/sfx/cash_05.wav", "res://audio/sfx/cash_06.wav", "res://audio/sfx/cash_07.wav", "res://audio/sfx/cash_08.wav"],
	"crowd_ooh": ["res://audio/sfx/crowd_ooh_01.wav", "res://audio/sfx/crowd_ooh_02.wav", "res://audio/sfx/crowd_ooh_03.wav", "res://audio/sfx/crowd_ooh_04.wav"],
	"land_dirt": ["res://audio/sfx/land_dirt_01.wav", "res://audio/sfx/land_dirt_02.wav", "res://audio/sfx/land_dirt_03.wav", "res://audio/sfx/land_dirt_04.wav", "res://audio/sfx/land_dirt_05.wav", "res://audio/sfx/land_dirt_06.wav", "res://audio/sfx/land_dirt_07.wav", "res://audio/sfx/land_dirt_08.wav"],
	"level_complete": ["res://audio/sfx/level_complete_01.wav", "res://audio/sfx/level_complete_02.wav", "res://audio/sfx/level_complete_03.wav", "res://audio/sfx/level_complete_04.wav"],
	"saloon_doors": ["res://audio/sfx/saloon_doors_01.wav", "res://audio/sfx/saloon_doors_02.wav", "res://audio/sfx/saloon_doors_03.wav", "res://audio/sfx/saloon_doors_04.wav", "res://audio/sfx/saloon_doors_05.wav", "res://audio/sfx/saloon_doors_06.wav", "res://audio/sfx/saloon_doors_07.wav"],
	"shop_buy": ["res://audio/sfx/shop_buy_01.wav", "res://audio/sfx/shop_buy_02.wav", "res://audio/sfx/shop_buy_03.wav", "res://audio/sfx/shop_buy_04.wav", "res://audio/sfx/shop_buy_05.wav", "res://audio/sfx/shop_buy_06.wav", "res://audio/sfx/shop_buy_07.wav", "res://audio/sfx/shop_buy_08.wav"],
	"target_bullseye": ["res://audio/sfx/target_bullseye_01.wav", "res://audio/sfx/target_bullseye_02.wav", "res://audio/sfx/target_bullseye_03.wav", "res://audio/sfx/target_bullseye_04.wav"],
	"throw_whoosh": ["res://audio/sfx/throw_whoosh_01.wav", "res://audio/sfx/throw_whoosh_02.wav", "res://audio/sfx/throw_whoosh_03.wav", "res://audio/sfx/throw_whoosh_04.wav", "res://audio/sfx/throw_whoosh_05.wav", "res://audio/sfx/throw_whoosh_06.wav", "res://audio/sfx/throw_whoosh_07.wav", "res://audio/sfx/throw_whoosh_08.wav"],
	"ui_click": ["res://audio/sfx/ui_click_01.wav", "res://audio/sfx/ui_click_02.wav", "res://audio/sfx/ui_click_03.wav", "res://audio/sfx/ui_click_04.wav", "res://audio/sfx/ui_click_05.wav", "res://audio/sfx/ui_click_06.wav", "res://audio/sfx/ui_click_07.wav", "res://audio/sfx/ui_click_08.wav"],
}

const AMB := [
	"res://audio/amb/amb_wildwest_01.ogg",
	"res://audio/amb/amb_wildwest_02.ogg",
	"res://audio/amb/amb_wildwest_03.ogg",
	"res://audio/amb/amb_wildwest_04.ogg",
]

const MUSIC := {
	"gameplay": "res://audio/music/mus_wildwest_gameplay.ogg",
	"shop": "res://audio/music/mus_shop.ogg",
}
