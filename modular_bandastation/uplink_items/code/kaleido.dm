/obj/item/organ/eyes/robotic/kaleido
	name = "Hardened Kaleido Optics eyes"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "Укреплённые кибернетические глаза с оптическим приближением. Используйте действие импланта для включения и отключения приближения."
	icon = 'modular_bandastation/uplink_items/icons/items.dmi'
	icon_state = "eyes-c-kaleido"
	organ_flags = ORGAN_ROBOTIC | ORGAN_HIDDEN
	eye_color_left = "#6f00ff"
	eye_color_right = "#6f00ff"
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	var/datum/component/scope/scope

/obj/item/organ/eyes/robotic/kaleido/Initialize(mapload)
	. = ..()
	scope = AddComponent(/datum/component/scope, range_modifier = 4, zoom_method = null)
	AddElement(/datum/element/empprotection, EMP_PROTECT_SELF)

/obj/item/organ/eyes/robotic/kaleido/Destroy()
	. = ..()
	scope = null

/obj/item/organ/eyes/robotic/kaleido/ui_action_click()
	if(!owner || !mob_effects_active || (organ_flags & ORGAN_FAILING))
		return
	if(scope.tracker)
		scope.stop_zooming(owner)
	else
		scope.zoom(owner)

/obj/item/organ/eyes/robotic/kaleido/on_mob_remove(mob/living/carbon/eye_owner, special, movement_flags)
	if(scope?.tracker)
		scope.stop_zooming(eye_owner)
	return ..()
