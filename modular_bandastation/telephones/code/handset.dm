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
	/// The base owns this handset and recalls it when the cord cannot reach.
	var/obj/structure/transmitter/attached_to
	/// The living mob currently holding the receiver in a hand.
	var/mob/living/holder
	/// Lowering the handset mutes both transmission and reception without hanging up.
	var/raised = FALSE
	/// The cord is drawn only while the handset is held.
	var/datum/beam/telephone_beam

/obj/item/telephone/Initialize(mapload, obj/structure/transmitter/base)
	. = ..()
	if(!istype(base))
		return INITIALIZE_HINT_QDEL
	attached_to = base
	icon = base.icon

/obj/item/telephone/Destroy()
	clear_holder()
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
	RegisterSignal(holder, COMSIG_MOVABLE_MOVED, PROC_REF(on_holder_moved))
	RegisterSignal(holder, COMSIG_QDELETING, PROC_REF(on_holder_deleted))
	check_tether()
	if(holder && attached_to)
		telephone_beam = holder.Beam(attached_to, icon_state = "zipline_hook", time = INFINITY, maxdistance = PHONE_MAX_RANGE)

/obj/item/telephone/dropped(mob/user, silent = FALSE)
	. = ..()
	clear_holder()
	if(!QDELING(src))
		attached_to?.recall_phone()

/obj/item/telephone/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(attached_to && loc != attached_to && (!ismob(loc) || (holder && loc != holder)))
		clear_holder()
		attached_to?.recall_phone()

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

/** Releases the holder, movement listeners and cord before recall or deletion. */
/obj/item/telephone/proc/clear_holder()
	if(holder)
		UnregisterSignal(holder, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		holder = null
	raised = FALSE
	inhand_icon_state = "rpb_phone"
	lose_hearing_sensitivity(ROUNDSTART_TRAIT)
	QDEL_NULL(telephone_beam)

/** Recalls the handset when either end moves beyond the cord or into another z-level/container. */
/obj/item/telephone/proc/check_tether()
	if(!attached_to || !holder)
		return
	var/turf/base_turf = get_turf(attached_to)
	var/turf/holder_turf = get_turf(holder)
	if(!base_turf || !holder_turf || !isturf(holder.loc) || base_turf.z != holder_turf.z || get_dist(base_turf, holder_turf) > PHONE_MAX_RANGE)
		attached_to.recall_phone()

/obj/item/telephone/proc/on_holder_moved()
	SIGNAL_HANDLER
	check_tether()

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
