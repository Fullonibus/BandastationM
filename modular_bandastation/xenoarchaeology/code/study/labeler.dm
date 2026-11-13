/**
 * # Find labels
 *
 * New code on BeeStation's idea (42b0625, code/modules/xenoarchaeology/tools/xenoarchaeology_labeler.dm);
 * the BeeStation labeler is folded into the stratigraphic scanner.
 *
 * The crew dials in three words from fixed lists (what the find does, what wakes it, its second effect
 * or "None") with Alt-click and presses a printed tag onto a large find by clicking it. Nothing says
 * whether the tag is right. Right-click peels a tag off.
 */
/obj/item/excavation/depth_scanner
	/// What the find does, as an effect's label word
	var/effect_word
	/// What wakes it, as a trigger word
	var/trigger_word
	/// Its second effect's label word, or ARTIFACT_LABEL_NONE
	var/second_word
	COOLDOWN_DECLARE(print_cooldown)

/obj/item/excavation/depth_scanner/examine(mob/user)
	. = ..()
	if(effect_word || trigger_word || second_word)
		. += "Бирка на экране: <i>[effect_word || "..."] / [trigger_word || "..."] / [second_word || "..."]</i>"

/obj/item/excavation/depth_scanner/click_alt(mob/user)
	ui_interact(user)
	return CLICK_ACTION_SUCCESS

/// Use in hand is the scanner pulse: the tag screen opens only by Alt-click or on a find with an unfinished tag.
/obj/item/excavation/depth_scanner/interact(mob/user)
	return FALSE

/// Whether all three words are set.
/obj/item/excavation/depth_scanner/proc/is_complete()
	return effect_word && trigger_word && second_word

/**
 * Dials one field to a word from its list. Returns TRUE if it changed.
 * `field` is "effect", "trigger" or "second"; a null word clears the field.
 */
/obj/item/excavation/depth_scanner/proc/set_word(field, word)
	if(word && !(word in words_for(field)))
		return FALSE
	switch(field)
		if("effect")
			if(effect_word == word)
				return FALSE
			effect_word = word
		if("trigger")
			if(trigger_word == word)
				return FALSE
			trigger_word = word
		if("second")
			if(second_word == word)
				return FALSE
			second_word = word
		else
			return FALSE
	return TRUE

/// The words a field may take.
/obj/item/excavation/depth_scanner/proc/words_for(field)
	switch(field)
		if("effect")
			return artifact_effect_label_names()
		if("trigger")
			return artifact_trigger_label_names()
		if("second")
			return list(ARTIFACT_LABEL_NONE) + artifact_effect_label_names()
	return list()

/// A label datum for the words now set, or null if any is missing.
/obj/item/excavation/depth_scanner/proc/make_label()
	if(!is_complete())
		return null
	return new /datum/artifact_label(effect_word, trigger_word, second_word)

/// Presses a tag with the words dialled in onto `find`; with words missing, opens the tag screen instead.
/obj/item/excavation/depth_scanner/proc/label_find(obj/machinery/artifact/find, mob/living/user)
	if(!is_complete())
		balloon_alert(user, "бирка заполнена не полностью!")
		ui_interact(user)
		return ITEM_INTERACT_BLOCKING
	if(!COOLDOWN_FINISHED(src, print_cooldown))
		return ITEM_INTERACT_BLOCKING
	COOLDOWN_START(src, print_cooldown, 2 SECONDS)
	playsound(src, 'sound/items/taperecorder/taperecorder_print.ogg', 35, TRUE)
	if(!do_after(user, 1 SECONDS, find))
		return ITEM_INTERACT_BLOCKING
	var/datum/artifact_label/new_label = make_label()
	if(!new_label)
		return ITEM_INTERACT_BLOCKING
	var/replaced = !!find.label
	find.apply_label(new_label, user)
	// A tag sets the sale price, and anyone can reach a find, so leave a trail for admins.
	log_game("[key_name(user)] tagged artifact [find.serial] as [effect_word] / [trigger_word] / [second_word] at [AREACOORD(find)].")
	playsound(find, 'sound/items/handling/component_pickup.ogg', 30, TRUE)
	user.visible_message(
		span_notice("[user] прижимает напечатанную бирку к [find]."),
		span_notice((replaced ? "Вы снимаете старую бирку и прижимаете новую к [find]." : "Вы прижимаете бирку к [find].")),
	)
	return ITEM_INTERACT_SUCCESS

/obj/item/excavation/depth_scanner/interact_with_atom_secondary(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/machinery/artifact))
		return NONE
	var/obj/machinery/artifact/find = interacting_with
	if(!find.label)
		balloon_alert(user, "бирки нет!")
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, 1 SECONDS, find))
		return ITEM_INTERACT_BLOCKING
	if(!find.remove_label(user))
		return ITEM_INTERACT_BLOCKING
	log_game("[key_name(user)] peeled the tag off artifact [find.serial] at [AREACOORD(find)].")
	playsound(find, 'sound/items/poster/poster_ripped.ogg', 20, TRUE)
	user.visible_message(
		span_notice("[user] снимает бирку с [find]."),
		span_notice("Вы снимаете бирку с [find]."),
	)
	return ITEM_INTERACT_SUCCESS

// ===== tgui =====

/obj/item/excavation/depth_scanner/ui_state(mob/user)
	return GLOB.hands_state

/obj/item/excavation/depth_scanner/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoarchLabeler", "Бирка находки")
		ui.open()

/obj/item/excavation/depth_scanner/ui_static_data(mob/user)
	return list(
		"effects" = artifact_effect_label_names(),
		"triggers" = artifact_trigger_label_names(),
		"none" = ARTIFACT_LABEL_NONE,
	)

/obj/item/excavation/depth_scanner/ui_data(mob/user)
	return list(
		"effect" = effect_word,
		"trigger" = trigger_word,
		"second" = second_word,
	)

/obj/item/excavation/depth_scanner/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("set")
			var/field = params["field"]
			var/word = params["word"]
			if(!istext(field) || (!isnull(word) && !istext(word)))
				return FALSE
			if(set_word(field, word))
				playsound(src, 'sound/machines/terminal/terminal_button03.ogg', 15, TRUE)
				return TRUE
		if("clear")
			if(effect_word || trigger_word || second_word)
				effect_word = null
				trigger_word = null
				second_word = null
				playsound(src, 'sound/machines/terminal/terminal_button07.ogg', 15, TRUE)
				return TRUE
	return FALSE
