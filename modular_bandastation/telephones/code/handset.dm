/** A tethered receiver which relays its holder's audible speech through an established call. */
/obj/item/telephone
	name = "handset"
	desc = "Телефонная трубка. Используйте в руке, чтобы поднести её к уху или опустить. Alt+ЛКМ по трубке открывает телефонную книгу."
	icon = 'modular_bandastation/telephones/icons/phone.dmi'
	icon_state = "phone"
	inhand_icon_state = "rpb_phone"
	lefthand_file = 'modular_bandastation/telephones/icons/phone_lefthand.dmi'
	righthand_file = 'modular_bandastation/telephones/icons/phone_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	/// The base owns this handset; its cord limits ordinary movement.
	var/obj/structure/transmitter/attached_to
	/// The living mob currently holding the receiver in a hand.
	var/mob/living/holder
	/// Lowering the handset mutes both transmission and reception without hanging up.
	var/raised = FALSE
	/// The cord follows the holder or the handset lying on the floor.
	var/datum/beam/telephone_beam

/obj/item/telephone/Initialize(mapload, obj/structure/transmitter/base)
	. = ..()
	if(!istype(base))
		return INITIALIZE_HINT_QDEL
	attached_to = base
	icon = base.icon
	RegisterSignal(src, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_tether_pre_move))
	RegisterSignal(base, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_tether_pre_move))

/obj/item/telephone/Destroy()
	clear_holder()
	if(attached_to)
		UnregisterSignal(attached_to, COMSIG_MOVABLE_PRE_MOVE)
	if(attached_to?.handset == src)
		attached_to.handset = null
		attached_to.end_call()
		attached_to.update_appearance()
	attached_to = null
	return ..()

/obj/item/telephone/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	clear_holder()
	if(!(slot & ITEM_SLOT_HANDS) || !isliving(user))
		attached_to?.recall_phone()
		return
	holder = user
	raised = TRUE
	inhand_icon_state = "rpb_phone_ear"
	become_hearing_sensitive(ROUNDSTART_TRAIT)
	RegisterSignal(holder, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_tether_pre_move))
	RegisterSignal(holder, COMSIG_MOVABLE_MOVED, PROC_REF(on_holder_moved))
	RegisterSignal(holder, COMSIG_QDELETING, PROC_REF(on_holder_deleted))
	check_tether()
	update_beam()

/obj/item/telephone/dropped(mob/user, silent = FALSE)
	. = ..()
	clear_holder()
	if(!QDELING(src))
		update_beam()

/obj/item/telephone/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(holder && loc != holder)
		clear_holder()
	check_tether()
	update_beam()

/obj/item/telephone/attack_self(mob/user)
	. = ..()
	if(!attached_to?.can_use_handset(user))
		return
	raised = !raised
	inhand_icon_state = raised ? "rpb_phone_ear" : "rpb_phone"
	user.update_held_items()
	balloon_alert(user, raised ? "трубка у уха" : "трубка опущена")

/obj/item/telephone/click_alt(mob/user)
	if(!attached_to?.can_use_handset(user))
		return CLICK_ACTION_BLOCKING
	attached_to.ui_interact(user)
	return CLICK_ACTION_SUCCESS

/obj/item/telephone/attempt_pickup(mob/living/user, skip_grav = FALSE)
	if(!cord_reaches(user, attached_to))
		balloon_alert(user, "шнур не дотягивается!")
		return TRUE
	return ..()

/obj/item/telephone/on_offer_taken(mob/living/offerer, mob/living/taker)
	. = ..()
	if(.)
		return
	if(!cord_reaches(taker, attached_to))
		balloon_alert(taker, "шнур не дотягивается!")
		return TRUE

/** Releases the holder, movement listeners and cord before recall or deletion. */
/obj/item/telephone/proc/clear_holder()
	if(holder)
		UnregisterSignal(holder, list(COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		holder = null
	raised = FALSE
	inhand_icon_state = "rpb_phone"
	lose_hearing_sensitivity(ROUNDSTART_TRAIT)
	QDEL_NULL(telephone_beam)

/** Draws the cord while off-hook, including between holders during a handoff. */
/obj/item/telephone/proc/update_beam()
	QDEL_NULL(telephone_beam)
	if(attached_to && loc != attached_to && cord_reaches(src, attached_to))
		telephone_beam = attached_to.Beam(ismob(loc) ? loc : src, icon_state = "zipline_hook", time = INFINITY, maxdistance = PHONE_MAX_RANGE + 1)

/** Whether two endpoints fit within the cord on the same z-level. */
/obj/item/telephone/proc/cord_reaches(atom/first, atom/second)
	var/turf/first_turf = get_turf(first)
	var/turf/second_turf = get_turf(second)
	return first_turf && second_turf && first_turf.z == second_turf.z && get_dist(first_turf, second_turf) <= PHONE_MAX_RANGE

/** Stops an ordinary step or dragging either endpoint before the cord is overstretched. */
/obj/item/telephone/proc/on_tether_pre_move(atom/movable/source, atom/new_loc)
	SIGNAL_HANDLER
	if(!attached_to || loc == attached_to)
		return NONE
	var/turf/destination = get_turf(new_loc)
	var/turf/anchor = get_turf(source == attached_to ? src : attached_to)
	if(cord_reaches(destination, anchor))
		return NONE
	// Forced relocations may leave an endpoint outside the cord; allow it to approach the other end.
	if(destination && anchor && !cord_reaches(source, anchor) && destination.z == anchor.z && get_dist(destination, anchor) < get_dist(get_turf(source), anchor))
		return NONE
	if(ismob(source))
		balloon_alert(source, "шнур натянут!")
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/** Keeps container handling, but never docks a handset because its distance changed. */
/obj/item/telephone/proc/check_tether()
	if(!attached_to || loc == attached_to)
		return
	var/turf/base_turf = get_turf(attached_to)
	var/turf/handset_turf = get_turf(src)
	if(!base_turf || !handset_turf || (!isturf(loc) && (!ismob(loc) || !isturf(loc.loc))))
		attached_to.recall_phone()
	else if(!cord_reaches(src, attached_to))
		attached_to.end_call()

/obj/item/telephone/proc/on_holder_moved(atom/movable/source, atom/old_loc)
	SIGNAL_HANDLER
	if(holder && !cord_reaches(holder, attached_to) && cord_reaches(old_loc, attached_to))
		holder.transferItemToLoc(src, get_turf(old_loc), force = TRUE, silent = TRUE)
	check_tether()
	update_beam()

/obj/item/telephone/proc/on_holder_deleted()
	SIGNAL_HANDLER
	attached_to?.recall_phone()

/obj/item/telephone/Hear(atom/movable/speaker, datum/language/message_language, raw_message, radio_freq, radio_freq_name, radio_freq_color, list/spans, list/message_mods = list(), message_range = 0)
	. = ..()
	if(!raised || speaker != holder || radio_freq || message_mods[MODE_RELAY] || !attached_to?.can_use_handset(holder))
		return
	if(HAS_TRAIT(speaker, TRAIT_SIGN_LANG) || message_mods[MODE_CUSTOM_SAY_ERASE_INPUT])
		return
	var/obj/structure/transmitter/other = attached_to.current_call
	var/obj/item/telephone/receiver = other?.handset
	if(attached_to.status != PHONE_CONNECTED || other?.status != PHONE_CONNECTED || other.current_call != attached_to)
		return
	if(!receiver?.raised || !other.can_use_handset(receiver.holder))
		return

	// Hear receives treated speech after saymodes, rather than the unfiltered COMSIG_MOB_SAY input.
	var/list/relayed_mods = message_mods.Copy()
	relayed_mods[MODE_RELAY] = TRUE
	relayed_mods[MODE_SPEAKER_NAME_OVERRIDE] = "Голос в телефонной трубке"
	relayed_mods[MODE_TTS_FILTERS] = list(/datum/singleton/sound_effect/radio)
	var/atom/movable/virtualspeaker/voice = new(get_turf(receiver), speaker)
	voice.runechat_anchors = list()
	voice.runechat_anchors[receiver.holder] = receiver
	receiver.holder.Hear(voice, message_language, raw_message, null, null, null, spans, relayed_mods, INFINITY)
	voice.source = null
	voice.runechat_anchors = null
	qdel(voice)
	log_say("TELEPHONE: [key_name(speaker)] at '[attached_to.display_name]' to '[other.display_name]' said '[raw_message]'")
