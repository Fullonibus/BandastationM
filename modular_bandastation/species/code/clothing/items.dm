/obj/item
	var/list/worn_icon_species

/// Returns a fitted sprite only when it contains the requested worn state.
/obj/item/proc/get_species_worn_icon(species_id, state, slot_id = NONE)
	state ||= get_worn_icon_state(slot_id)
	var/species_icon = worn_icon_species?[species_id]
	if(slot_id == ITEM_SLOT_SUITSTORE)
		if(species_id != SPECIES_RESOMI)
			return null
		if(!worn_icon)
			species_icon = 'icons/bandastation/mob/species/resomi/clothing/belt_mirror.dmi'
		else if(worn_icon != 'icons/mob/clothing/back.dmi' && worn_icon != 'icons/mob/clothing/belt.dmi')
			species_icon = null
	if(!species_icon && species_id != SPECIES_RESOMI)
		return null
	if(species_id == SPECIES_DRASK && (greyscale_config_worn || worn_x_dimension != 32 || worn_y_dimension != 32))
		return null
	if(species_id == SPECIES_RESOMI)
		var/config_worn = greyscale_config_worn
		var/colors = greyscale_colors
		var/datum/action/item_action/chameleon/change/disguise = locate() in actions
		if(disguise?.active_type)
			config_worn = disguise.disguise_worn_config
			colors = disguise.disguise_worn_colors
			species_icon = disguise.disguise_species_icons?[SPECIES_RESOMI]
		if(worn_y_offset && !config_worn)
			species_icon = null
		var/native_icon = worn_icon || (slot_id == ITEM_SLOT_SUITSTORE ? 'icons/mob/clothing/belt_mirror.dmi' : get_default_icon_by_slot(slot_id))
		if(worn_x_dimension == 64 && worn_y_dimension == 64 && species_icon == 'icons/bandastation/mob/species/resomi/clothing/feet.dmi')
			species_icon = 'icons/bandastation/mob/species/resomi/clothing/feet_64.dmi'
		else if(worn_x_dimension != 32 || worn_y_dimension != 32)
			return get_generated_resomi_worn_icon(slot_id, native_icon, state, config_worn, colors)
		if(config_worn && colors)
			var/static/list/resomi_greyscale_configs = list(
				/datum/greyscale_config/jumpsuit/worn = /datum/greyscale_config/jumpsuit/worn/resomi,
				/datum/greyscale_config/sneakers/worn = /datum/greyscale_config/sneakers/worn/resomi,
				/datum/greyscale_config/jumpsuit/prison/worn = /datum/greyscale_config/jumpsuit/prison/worn/resomi,
				/datum/greyscale_config/sneakers_orange/worn = /datum/greyscale_config/sneakers_orange/worn/resomi,
				/datum/greyscale_config/sneakers_marisa/worn = /datum/greyscale_config/sneakers_marisa/worn/resomi,
				/datum/greyscale_config/beanie/worn = /datum/greyscale_config/beanie/worn/resomi,
				/datum/greyscale_config/beret/worn = /datum/greyscale_config/beret/worn/resomi,
				/datum/greyscale_config/beret_badge/worn = /datum/greyscale_config/beret_badge/worn/resomi,
				/datum/greyscale_config/bandana/worn = /datum/greyscale_config/bandana/worn/resomi,
				/datum/greyscale_config/bandana/striped/worn = /datum/greyscale_config/bandana/striped/worn/resomi,
				/datum/greyscale_config/bandana/skull/worn = /datum/greyscale_config/bandana/skull/worn/resomi,
				/datum/greyscale_config/winter_coats/worn = /datum/greyscale_config/winter_coats/worn/resomi,
				/datum/greyscale_config/hoodie_pullover/worn = /datum/greyscale_config/hoodie_pullover/worn/resomi,
				/datum/greyscale_config/hoodie_zipup/worn = /datum/greyscale_config/hoodie_zipup/worn/resomi,
				/datum/greyscale_config/labcoat/worn = /datum/greyscale_config/labcoat/worn/resomi,
				/datum/greyscale_config/winter_hoods/worn = /datum/greyscale_config/winter_hoods/worn/resomi,
				/datum/greyscale_config/hoodie_pullover_hood/worn = /datum/greyscale_config/hoodie_pullover_hood/worn/resomi,
				/datum/greyscale_config/hoodie_zipup_hood/worn = /datum/greyscale_config/hoodie_zipup_hood/worn/resomi,
				/datum/greyscale_config/ties/worn = /datum/greyscale_config/ties/worn/resomi,
				/datum/greyscale_config/scarf/worn = /datum/greyscale_config/scarf/worn/resomi,
				/datum/greyscale_config/infinity_scarf/worn = /datum/greyscale_config/infinity_scarf/worn/resomi,
				/datum/greyscale_config/buttondown_slacks/worn = /datum/greyscale_config/buttondown_slacks/worn/resomi,
				/datum/greyscale_config/seifuku/worn = /datum/greyscale_config/seifuku/worn/resomi,
			)
			var/resomi_config = resomi_greyscale_configs[config_worn]
			species_icon = resomi_config ? SSgreyscale.GetColoredIconByType(resomi_config, colors) : null
		if(icon_exists(species_icon, state))
			return species_icon
		return get_generated_resomi_worn_icon(slot_id, native_icon, state, config_worn, colors)
	if(species_id == SPECIES_VOX && species_icon == 'icons/bandastation/mob/species/vox/clothing/feet.dmi' && worn_x_dimension == 64 && worn_y_dimension == 64)
		species_icon = 'icons/bandastation/mob/species/vox/clothing/feet_64.dmi'
	if(species_id == SPECIES_VOX && greyscale_config_worn)
		var/static/list/vox_greyscale_configs = list(
			/datum/greyscale_config/jumpsuit/worn = /datum/greyscale_config/jumpsuit/worn/vox,
			/datum/greyscale_config/jumpsuit/prison/worn = /datum/greyscale_config/jumpsuit/prison/worn/vox,
			/datum/greyscale_config/beret/worn = /datum/greyscale_config/beret/worn/vox,
			/datum/greyscale_config/beret_badge/worn = /datum/greyscale_config/beret_badge/worn/vox,
			/datum/greyscale_config/sneakers/worn = /datum/greyscale_config/sneakers/worn/vox,
			/datum/greyscale_config/sneakers_orange/worn = /datum/greyscale_config/sneakers_orange/worn/vox,
			/datum/greyscale_config/bandana/worn = /datum/greyscale_config/bandana/worn/vox,
			/datum/greyscale_config/bandana/striped/worn = /datum/greyscale_config/bandana/striped/worn/vox,
			/datum/greyscale_config/bandana/skull/worn = /datum/greyscale_config/bandana/skull/worn/vox,
		)
		var/vox_config = vox_greyscale_configs[greyscale_config_worn]
		if(!vox_config)
			return null
		species_icon = SSgreyscale.GetColoredIconByType(vox_config, greyscale_colors)
	// Paradise overlays share the original items and their current worn states.
	// Precoloured 32px art must never replace GAGS colours or large shoe anchors.
	var/use_paradise = species_id == SPECIES_VOX && !greyscale_config_worn && worn_x_dimension == 32 && worn_y_dimension == 32
	if(use_paradise)
		var/static/list/reviewed_replacements = list(
			'icons/bandastation/mob/species/vox/clothing/uniform.dmi' = 'icons/bandastation/mob/species/vox/paradise/under_replacement.dmi',
			'icons/bandastation/mob/species/vox/clothing/feet.dmi' = 'icons/bandastation/mob/species/vox/paradise/shoes_replacement.dmi',
		)
		var/replacement = reviewed_replacements[species_icon]
		if(replacement && icon_exists(replacement, state))
			return replacement
	if(icon_exists(species_icon, state))
		return species_icon
	if(use_paradise)
		var/static/list/supplements = list(
			'icons/bandastation/mob/species/vox/clothing/head.dmi' = 'icons/bandastation/mob/species/vox/paradise/head.dmi',
			'icons/bandastation/mob/species/vox/clothing/helmet.dmi' = 'icons/bandastation/mob/species/vox/paradise/helmet.dmi',
			'icons/bandastation/mob/species/vox/clothing/uniform.dmi' = 'icons/bandastation/mob/species/vox/paradise/under.dmi',
			'icons/bandastation/mob/species/vox/clothing/feet.dmi' = 'icons/bandastation/mob/species/vox/paradise/shoes.dmi',
			'icons/bandastation/mob/species/vox/clothing/suit.dmi' = 'icons/bandastation/mob/species/vox/paradise/suit.dmi',
			'icons/bandastation/mob/species/vox/clothing/hands.dmi' = 'icons/bandastation/mob/species/vox/paradise/gloves.dmi',
			'icons/bandastation/mob/species/vox/clothing/back.dmi' = 'icons/bandastation/mob/species/vox/paradise/back.dmi',
			'icons/bandastation/mob/species/vox/clothing/neck.dmi' = 'icons/bandastation/mob/species/vox/paradise/neck.dmi',
		)
		var/supplement = supplements[species_icon]
		if(supplement && icon_exists(supplement, state))
			return supplement
	return null

/obj/item/clothing/head/mod
	worn_icon_species = list(
		SPECIES_VULPKANIN = 'icons/bandastation/mob/species/vulpkanin/clothing/modsuits.dmi',
		SPECIES_TAJARAN = 'icons/bandastation/mob/species/tajaran/clothing/modsuits.dmi',
		SPECIES_SKRELL = 'icons/bandastation/mob/species/skrell/clothing/modsuits.dmi',
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/modsuits.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/modsuits.dmi',
	)

/obj/item/clothing/suit/mod
	worn_icon_species = list(
		SPECIES_VULPKANIN = 'icons/bandastation/mob/species/vulpkanin/clothing/modsuits.dmi',
		SPECIES_TAJARAN = 'icons/bandastation/mob/species/tajaran/clothing/modsuits.dmi',
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/modsuits.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/modsuits.dmi',
	)

/obj/item/mod/module
	worn_icon_species = list(
		SPECIES_VULPKANIN = 'icons/bandastation/mob/species/vulpkanin/clothing/modules.dmi',
		SPECIES_TAJARAN = 'icons/bandastation/mob/species/tajaran/clothing/modules.dmi',
		SPECIES_SKRELL = 'icons/bandastation/mob/species/skrell/clothing/modules.dmi',
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/modules.dmi'
	)

/obj/item/clothing/suit
	worn_icon_species = list(
		SPECIES_VULPKANIN = 'icons/bandastation/mob/species/vulpkanin/clothing/suit.dmi',
		SPECIES_TAJARAN = 'icons/bandastation/mob/species/tajaran/clothing/suit.dmi',
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/suit.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/suit.dmi',
	)

/obj/item/clothing/head
	worn_icon_species = list(
		SPECIES_VULPKANIN = 'icons/bandastation/mob/species/vulpkanin/clothing/head.dmi',
		SPECIES_TAJARAN = 'icons/bandastation/mob/species/tajaran/clothing/head.dmi',
		SPECIES_SKRELL = 'icons/bandastation/mob/species/skrell/clothing/head.dmi',
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/head.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/head.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/helmets.dmi',
	)

/obj/item/clothing/under
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/uniform.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/uniform.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/uniforms.dmi',
	)

/obj/item/clothing/head/helmet
	worn_icon_species = list(
		SPECIES_VULPKANIN = 'icons/bandastation/mob/species/vulpkanin/clothing/head.dmi',
		SPECIES_TAJARAN = 'icons/bandastation/mob/species/tajaran/clothing/head.dmi',
		SPECIES_SKRELL = 'icons/bandastation/mob/species/skrell/clothing/head.dmi',
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/helmet.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/head.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/helmets.dmi',
	)

/obj/item/clothing/mask
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/mask.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/mask.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/masks.dmi',
	)

/obj/item/cigarette
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/mask.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/mask.dmi',
	)

/obj/item/clothing/glasses
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/eyes.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/eyes.dmi',
	)

/obj/item/clothing/ears
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/ears.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/ears.dmi',
	)

// AI EDIT START - Fit headset side states to the existing Vox ear artwork
/obj/item/radio/headset
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/ears.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/ears.dmi',
	)
// AI EDIT END

/obj/item/clothing/gloves
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/hands.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/hands.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/gloves.dmi',
	)

/obj/item/clothing/shoes
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/feet.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/feet.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/boots.dmi',
	)

/obj/item/clothing/neck
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/neck.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/neck.dmi',
	)

/obj/item/storage/backpack
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/back.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/back.dmi',
	)

/obj/item/storage/belt
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/belt.dmi',
		SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/belt.dmi',
	)

/obj/item/tank
	worn_icon_species = list(SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/back.dmi')

/obj/item/tank/internals/emergency_oxygen
	worn_icon_species = list(SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/belt.dmi')

/obj/item/tank/internals/plasmaman/belt
	worn_icon_species = list(SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/belt.dmi')

/obj/item/watertank
	worn_icon_species = list(SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/back.dmi')

/obj/item/defibrillator
	worn_icon_species = list(SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/back.dmi')

/obj/item/defibrillator/compact
	worn_icon_species = list(SPECIES_RESOMI = 'icons/bandastation/mob/species/resomi/clothing/belt.dmi')

/obj/item/mod/control
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/modsuits.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/modsuits.dmi',
	)

/obj/item/clothing/gloves/mod
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/modsuits.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/modsuits.dmi',
	)

/obj/item/clothing/shoes/mod
	worn_icon_species = list(
		SPECIES_VOX = 'icons/bandastation/mob/species/vox/clothing/modsuits.dmi',
		SPECIES_DRASK = 'icons/bandastation/mob/species/drask/clothing/modsuits.dmi',
	)

/datum/greyscale_config/jumpsuit/worn/vox
	name = "Vox jumpsuit (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/color_gags_vox.dmi'

/datum/greyscale_config/jumpsuit/prison/worn/vox
	name = "Vox prison jumpsuit (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/color_gags_vox.dmi'

/datum/greyscale_config/beret/worn/vox
	name = "Vox beret (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/color_gags_vox.dmi'

/datum/greyscale_config/beret_badge/worn/vox
	name = "Vox badged beret (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/color_gags_vox.dmi'

/datum/greyscale_config/sneakers/worn/vox
	name = "Vox sneakers (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/feet.dmi'

/datum/greyscale_config/sneakers_orange/worn/vox
	name = "Vox orange sneakers (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/feet.dmi'

/datum/greyscale_config/bandana/worn/vox
	name = "Vox bandana (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/mask.dmi'

/datum/greyscale_config/bandana/striped/worn/vox
	name = "Vox striped bandana (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/mask.dmi'

/datum/greyscale_config/bandana/skull/worn/vox
	name = "Vox skull bandana (Worn)"
	icon_file = 'icons/bandastation/mob/species/vox/clothing/mask.dmi'

/datum/greyscale_config/jumpsuit/worn/resomi
	name = "Resomi jumpsuit (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/uniform_gags.dmi'

/datum/greyscale_config/sneakers/worn/resomi
	name = "Resomi sneakers (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/feet_gags.dmi'

/datum/greyscale_config/jumpsuit/prison/worn/resomi
	name = "Resomi prison jumpsuit (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/uniform_gags.dmi'

/datum/greyscale_config/sneakers_orange/worn/resomi
	name = "Resomi orange sneakers (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/feet_gags.dmi'

/datum/greyscale_config/sneakers_marisa/worn/resomi
	name = "Resomi Marisa sneakers (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/feet_gags.dmi'

/datum/greyscale_config/beanie/worn/resomi
	name = "Resomi beanie (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/head_gags.dmi'

/datum/greyscale_config/beret/worn/resomi
	name = "Resomi beret (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/head_gags.dmi'

/datum/greyscale_config/beret_badge/worn/resomi
	name = "Resomi badged beret (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/head_gags.dmi'

/datum/greyscale_config/bandana/worn/resomi
	name = "Resomi bandana (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/mask_gags.dmi'

/datum/greyscale_config/bandana/striped/worn/resomi
	name = "Resomi striped bandana (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/mask_gags.dmi'

/datum/greyscale_config/bandana/skull/worn/resomi
	name = "Resomi skull bandana (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/mask_gags.dmi'

/datum/greyscale_config/winter_coats/worn/resomi
	name = "Resomi winter coat (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/suit.dmi'

/datum/greyscale_config/hoodie_pullover/worn/resomi
	name = "Resomi pullover hoodie (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/suit.dmi'

/datum/greyscale_config/hoodie_zipup/worn/resomi
	name = "Resomi zipup hoodie (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/suit.dmi'

/datum/greyscale_config/labcoat/worn/resomi
	name = "Resomi labcoat (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/suit.dmi'

/datum/greyscale_config/winter_hoods/worn/resomi
	name = "Resomi winter coat hood (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/head.dmi'

/datum/greyscale_config/hoodie_pullover_hood/worn/resomi
	name = "Resomi pullover hood (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/head.dmi'

/datum/greyscale_config/hoodie_zipup_hood/worn/resomi
	name = "Resomi zipup hood (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/head.dmi'

/datum/greyscale_config/ties/worn/resomi
	name = "Resomi ties (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/neck.dmi'

/datum/greyscale_config/scarf/worn/resomi
	name = "Resomi scarf (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/neck.dmi'

/datum/greyscale_config/infinity_scarf/worn/resomi
	name = "Resomi infinity scarf (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/neck.dmi'

/datum/greyscale_config/buttondown_slacks/worn/resomi
	name = "Resomi button-down and slacks (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/uniform.dmi'

/datum/greyscale_config/seifuku/worn/resomi
	name = "Resomi school uniform (Worn)"
	icon_file = 'icons/bandastation/mob/species/resomi/clothing/seifuku_gags.dmi'
