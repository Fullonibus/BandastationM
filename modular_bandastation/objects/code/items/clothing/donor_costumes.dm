/datum/armor/clothing_under/primera
	bio = 0
	wound = 0

/obj/item/clothing/under/costume/primera
	abstract_type = /obj/item/clothing/under/costume/primera
	icon = 'modular_bandastation/objects/icons/obj/clothing/primera_inventory.dmi'
	worn_icon = 'modular_bandastation/objects/icons/obj/clothing/primera_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_right.dmi'
	armor_type = /datum/armor/clothing_under/primera
	can_adjust = FALSE
	female_sprite_flags = NO_FEMALE_UNIFORM
	supports_variations_flags = CLOTHING_DIGITIGRADE_MASK|CLOTHING_CERULEAN_MASK_LEGS
	bodyshapes_with_variations = BODYSHAPE_DIGITIGRADE|BODYSHAPE_CERULEAN
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/primera/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/primera/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/primera/drask.dmi',
	)

/obj/item/clothing/under/costume/primera/generate_digitigrade_icons(icon/base_icon, greyscale_colors)
	// Keep the original trouser patterns instead of replacing them with a single colour.
	if(icon_exists('modular_bandastation/objects/icons/mob/clothing/primera/digitigrade.dmi', worn_icon_state))
		return icon('modular_bandastation/objects/icons/mob/clothing/primera/digitigrade.dmi', worn_icon_state)
	return base_icon

/obj/item/clothing/under/costume/primera/villager
	name = "primera villager suit"
	desc = "Коричневый костюм с тёмным поясом и красными вставками."
	icon_state = "Villager1_suit"
	worn_icon_state = "Villager1_suit"
	inhand_icon_state = "Villager1_suit"

/obj/item/clothing/under/costume/primera/villager_dress
	name = "primera villager dress"
	desc = "Зелёное платье с золотистой отделкой поверх белой блузы."
	icon_state = "Villager2_dress"
	worn_icon_state = "Villager2_dress"
	inhand_icon_state = "Villager2_dress"

/obj/item/clothing/under/costume/primera/villager_sailor
	name = "primera villager sailor suit"
	desc = "Белая матросская рубашка с синим воротником и синие брюки."
	icon_state = "Villager3_suit"
	worn_icon_state = "Villager3_suit"
	inhand_icon_state = "Villager3_suit"

/obj/item/clothing/under/costume/primera/bubba
	name = "primera bubba suit"
	desc = "Заляпанная рубашка с тёмным галстуком и синие брюки."
	icon_state = "Bubba_Suit"
	worn_icon_state = "Bubba_Suit"
	inhand_icon_state = "Bubba_Suit"
	body_parts_covered = CHEST|GROIN|LEGS

/obj/item/clothing/under/costume/primera/jinx
	name = "primera jinx suit"
	desc = "Короткий чёрный топ со шнуровкой и тёмные брюки с фиолетовыми полосами."
	icon_state = "Jinx_Suit"
	worn_icon_state = "Jinx_Suit"
	inhand_icon_state = "Jinx_Suit"
	body_parts_covered = CHEST|GROIN|LEGS

/obj/item/clothing/under/costume/primera/joker
	name = "primera joker suit"
	desc = "Светлая рубашка, зелёный жилет и тёмные брюки."
	icon_state = "Joker_Suit"
	worn_icon_state = "Joker_Suit"
	inhand_icon_state = "Joker_Suit"

/obj/item/clothing/under/costume/primera/mel
	name = "primera mel dress"
	desc = "Длинное белое платье с чёрной отделкой у плеч и воротника."
	icon_state = "Mel_Dress"
	worn_icon_state = "Mel_Dress"
	inhand_icon_state = "Mel_Dress"

/obj/item/clothing/under/costume/primera/silco
	name = "primera silco suit"
	desc = "Бордовая рубашка, тёмный жилет с золотистой отделкой и чёрные брюки."
	icon_state = "Silco_Suit"
	worn_icon_state = "Silco_Suit"
	inhand_icon_state = "Silco_Suit"

/obj/item/clothing/under/costume/primera/tyler
	name = "primera tyler suit"
	desc = "Голубая узорчатая рубашка и тёмные шорты."
	icon_state = "Tyler_Suit"
	worn_icon_state = "Tyler_Suit"
	inhand_icon_state = "Tyler_Suit"
	body_parts_covered = CHEST|GROIN

/obj/item/clothing/under/costume/primera/sailor
	name = "primera sailor dress"
	desc = "Белое платье с синим матросским воротником, синей юбкой и малиновым бантом."
	icon_state = "Sailor_Dress"
	worn_icon_state = "Sailor_Dress"
	inhand_icon_state = "Sailor_Dress"
	body_parts_covered = CHEST|GROIN

/obj/item/clothing/suit/costume/primera
	abstract_type = /obj/item/clothing/suit/costume/primera
	icon = 'modular_bandastation/objects/icons/obj/clothing/primera_inventory.dmi'
	worn_icon = 'modular_bandastation/objects/icons/obj/clothing/primera_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_right.dmi'
	body_parts_covered = CHEST|GROIN|ARMS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON|CLOTHING_CERULEAN_MASK_INBETWEEN
	bodyshapes_with_variations = BODYSHAPE_CERULEAN
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/primera/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/primera/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/primera/drask.dmi',
	)
	allowed = list()

/obj/item/clothing/suit/costume/primera/drive
	name = "primera driver jacket"
	desc = "Белая атласная куртка с золотым скорпионом на спине."
	icon_state = "Drive_Jacket"
	worn_icon_state = "Drive_Jacket"
	inhand_icon_state = "Drive_Jacket"

/obj/item/clothing/suit/costume/primera/joker
	name = "primera joker coat"
	desc = "Длинное фиолетовое пальто с широкими лацканами."
	icon_state = "Joker_Jacket"
	worn_icon_state = "Joker_Jacket"
	inhand_icon_state = "Joker_Jacket"
	body_parts_covered = CHEST|GROIN|ARMS|LEGS

/obj/item/clothing/suit/costume/primera/silco
	name = "primera silco coat"
	desc = "Длинное коричневое пальто с красной подкладкой и золотистой окантовкой."
	icon_state = "Silco_Coat"
	worn_icon_state = "Silco_Coat"
	inhand_icon_state = "Silco_Coat"
	body_parts_covered = CHEST|GROIN|ARMS|LEGS

/obj/item/clothing/suit/costume/primera/tyler
	name = "primera tyler jacket"
	desc = "Красная куртка со светлым воротником и манжетами."
	icon_state = "Tyler_Jacket"
	worn_icon_state = "Tyler_Jacket"
	inhand_icon_state = "Tyler_Jacket"

/obj/item/clothing/suit/costume/primera/bubba
	name = "primera bubba apron"
	desc = "Жёлтый фартук с бурыми пятнами и коричневыми завязками."
	icon_state = "Bubba_Apron"
	worn_icon_state = "Bubba_Apron"
	inhand_icon_state = "Bubba_Apron"
	body_parts_covered = CHEST|GROIN

/obj/item/clothing/mask/primera
	abstract_type = /obj/item/clothing/mask/primera
	icon = 'modular_bandastation/objects/icons/obj/clothing/primera_inventory.dmi'
	worn_icon = 'modular_bandastation/objects/icons/obj/clothing/primera_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_right.dmi'
	flags_inv = HIDEFACIALHAIR|HIDESNOUT
	can_be_adjusted = FALSE
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/primera/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/primera/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/primera/drask.dmi',
		SPECIES_VULPKANIN = 'modular_bandastation/objects/icons/mob/clothing/primera/vulpkanin.dmi',
		SPECIES_TAJARAN = 'modular_bandastation/objects/icons/mob/clothing/primera/tajaran.dmi',
	)

/obj/item/clothing/mask/primera/villager
	name = "primera villager mask"
	desc = "Светлая карнавальная маска с тёмными деталями."
	icon_state = "Villager1_mask"
	worn_icon_state = "Villager1_mask"
	inhand_icon_state = "Villager1_mask"

/obj/item/clothing/mask/primera/bubba
	name = "primera bubba mask"
	desc = "Жуткая маска с чёрными волосами."
	icon_state = "Bubba_Mask"
	worn_icon_state = "Bubba_Mask"
	inhand_icon_state = "Bubba_Mask"
	flags_inv = HIDEFACE|HIDEFACIALHAIR|HIDESNOUT|HIDEHAIR

/obj/item/clothing/mask/primera/sailor
	name = "primera sailor mask"
	desc = "Бело-синяя карнавальная маска."
	icon_state = "Villager3_mask"
	worn_icon_state = "Villager3_mask"
	inhand_icon_state = "Villager3_mask"

/obj/item/clothing/head/primera
	abstract_type = /obj/item/clothing/head/primera
	icon = 'modular_bandastation/objects/icons/obj/clothing/primera_inventory.dmi'
	worn_icon = 'modular_bandastation/objects/icons/obj/clothing/primera_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_right.dmi'
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/primera/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/primera/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/primera/drask.dmi',
	)

/obj/item/clothing/head/primera/villager
	name = "primera villager hat"
	desc = "Коричневая широкополая шляпа с красной лентой."
	icon_state = "Villager1_hat"
	worn_icon_state = "Villager1_hat"
	inhand_icon_state = "Villager1_hat"

/obj/item/clothing/head/primera/villager_circlet
	name = "primera villager circlet"
	desc = "Золотистый обруч с длинной зелёной лентой."
	icon_state = "Villager2_hat"
	worn_icon_state = "Villager2_hat"
	inhand_icon_state = "Villager2_hat"

/obj/item/clothing/head/primera/sailor
	name = "primera sailor cap"
	desc = "Белая шапочка с синей окантовкой и оранжевой подвеской."
	icon_state = "Villager3_hat"
	worn_icon_state = "Villager3_hat"
	inhand_icon_state = "Villager3_hat"

/obj/item/clothing/neck/primera_scarf
	name = "primera villager scarf"
	desc = "Длинный тёмно-красный шарф."
	icon = 'modular_bandastation/objects/icons/obj/clothing/primera_inventory.dmi'
	worn_icon = 'modular_bandastation/objects/icons/obj/clothing/primera_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_right.dmi'
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/primera/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/primera/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/primera/drask.dmi',
	)
	icon_state = "Villager1_scarf"
	worn_icon_state = "Villager1_scarf"
	inhand_icon_state = "Villager1_scarf"

/obj/item/clothing/shoes/primera_sailor
	name = "primera sailor boots"
	desc = "Малиновые сапожки с белой отделкой."
	icon = 'modular_bandastation/objects/icons/obj/clothing/primera_inventory.dmi'
	worn_icon = 'modular_bandastation/objects/icons/obj/clothing/primera_costumes.dmi'
	lefthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_left.dmi'
	righthand_file = 'modular_bandastation/objects/icons/mob/inhands/primera_right.dmi'
	icon_state = "Sailor_Boots"
	worn_icon_state = "Sailor_Boots"
	inhand_icon_state = "Sailor_Boots"
	armor_type = /datum/armor/none
	supports_variations_flags = CLOTHING_DIGITIGRADE_MASK
	bodyshapes_with_variations = BODYSHAPE_DIGITIGRADE
	worn_icon_species = list(
		SPECIES_RESOMI = 'modular_bandastation/objects/icons/mob/clothing/primera/resomi.dmi',
		SPECIES_VOX = 'modular_bandastation/objects/icons/mob/clothing/primera/vox.dmi',
		SPECIES_DRASK = 'modular_bandastation/objects/icons/mob/clothing/primera/drask.dmi',
	)

/obj/item/clothing/shoes/primera_sailor/generate_digitigrade_icons(icon/base_icon, greyscale_colors)
	return icon('modular_bandastation/objects/icons/mob/clothing/primera/digitigrade.dmi', worn_icon_state)
