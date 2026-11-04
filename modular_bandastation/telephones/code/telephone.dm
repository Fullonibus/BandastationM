/// A wired telephone base; each call owns a reciprocal peer and a cancellable timeout.
/obj/structure/transmitter
	name = "rotary telephone"
	desc = "A stationary telephone. Lift the handset to make or answer a call."
	icon = 'modular_bandastation/telephones/icons/phone.dmi'
	icon_state = "rotary"
	post_init_icon_state = "rotary"
	greyscale_config = /datum/greyscale_config/transmitter
	greyscale_colors = "#6e7766"
	anchored = TRUE
	pass_flags = PASSTABLE
	layer = OBJ_LAYER + 0.01
	/// Number used as the directory key; assigned once at initialization.
	var/phone_id
	/// Label displayed in the directory and call history.
	var/display_name
	/// Directory icon.
	var/phone_icon = "phone"
	/// Owned handset, including while another mob holds it.
	var/obj/item/telephone/handset
	/// Reciprocal connection, reserved while ringing as well as while talking.
	var/obj/structure/transmitter/current_call
	/// Powered exchange responsible for the current connection.
	var/obj/machinery/central_telephone_exchange/exchange
	/// Call state, one of PHONE_*.
	var/status = PHONE_IDLE
	/// Whether incoming calls should be rejected, except calls from Central Command.
	var/do_not_disturb = FALSE
	/// Network visible to callers; null hides incoming calls to payphones.
	var/phone_category = PHONE_NET_PUBLIC
	/// Networks this phone is permitted to call.
	var/list/networks_transmit = list(PHONE_NET_PUBLIC)
	/// Whether caller identification and history are available.
	var/is_advanced = TRUE
	/// Whether outgoing calls require payment.
	var/is_free = TRUE
	/// Credit for one successfully connected call.
	var/is_paid = FALSE
	/// Whether the one permitted rename was already used.
	var/was_renamed = FALSE
	/// Last five incoming/outgoing calls, storing strings rather than atom references.
	var/list/callers_list = list()
	/// Stoppable ring timeout, canceled before the next call can start.
	var/call_timer = TIMER_ID_NULL
	/// Active handset or ringer sound, stopped on every state transition.
	var/datum/looping_sound/telephone/call_sound
	/// Prevents dropped() reentering recall while the handset is being returned.
	var/recalling = FALSE

/obj/structure/transmitter/Initialize(mapload)
	. = ..()
	var/static/next_phone_id = 1000
	while(!phone_id || GLOB.telephones[phone_id])
		phone_id = num2text(next_phone_id++)
	GLOB.telephones[phone_id] = src
	if(!display_name)
		display_name = get_area_name(src, TRUE)
	handset = new(src, src)
	update_appearance()

/obj/structure/transmitter/Destroy()
	GLOB.telephones -= phone_id
	end_call()
	SStgui.close_uis(src)
	if(handset)
		handset.attached_to = null
		QDEL_NULL(handset)
	return ..()

/obj/structure/transmitter/examine(mob/user)
	. = ..()
	. += span_notice("Номер: [phone_id]. Название: [display_name].")
	if(is_advanced && current_call)
		. += span_notice("Абонент: [current_call.display_name].")
	. += span_notice("Нажмите на телефон с трубкой в руке, чтобы открыть телефонную книгу. Alt+ЛКМ — назвать телефон.")
	if(!is_free)
		. += span_notice("Один разговор стоит [PHONE_CALL_PRICE] кредитов. Оплата картой или монетой; занятые номера не расходуют оплаченный звонок.")

/obj/structure/transmitter/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	if(!can_interact(user) || !isliving(user) || !ISADVANCEDTOOLUSER(user) || !handset)
		return
	if(handset.loc == src)
		if(!user.put_in_active_hand(handset))
			return
		playsound(src, 'modular_bandastation/telephones/sound/remote_pickup.ogg', 40, FALSE)
		if(status == PHONE_INCOMING)
			answer_call()
		else if(find_exchange())
			set_call_sound(/datum/looping_sound/telephone/dialtone)
		else
			set_call_sound(/datum/looping_sound/telephone/unavailable)
		update_appearance()
	if(can_use_handset(user))
		ui_interact(user)

/// Only the conscious, capable mob actually holding this handset can control it.
/obj/structure/transmitter/proc/can_use_handset(mob/user)
	if(!isliving(user) || !ISADVANCEDTOOLUSER(user) || QDELETED(handset))
		return FALSE
	var/mob/living/living_user = user
	return !living_user.incapacitated && living_user.is_holding(handset) && get_dist(src, user) <= PHONE_MAX_RANGE && z == user.z

/obj/structure/transmitter/ui_host(mob/user)
	return handset || src

/obj/structure/transmitter/ui_status(mob/user, datum/ui_state/state)
	if(!can_use_handset(user))
		return UI_CLOSE
	return handset.ui_status(user, GLOB.hands_state)

/obj/structure/transmitter/ui_interact(mob/user, datum/tgui/ui)
	if(!can_use_handset(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PhoneMenu", display_name)
		ui.open()

/obj/structure/transmitter/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !can_use_handset(usr))
		return
	switch(action)
		if("call_phone")
			start_call(usr, params["phone_id"])
		if("hangup")
			if(!current_call)
				return FALSE
			var/obj/structure/transmitter/other = current_call
			end_call()
			set_call_sound(/datum/looping_sound/telephone/disconnected)
			if(other.handset?.holder)
				other.set_call_sound(/datum/looping_sound/telephone/disconnected)
		if("toggle_dnd")
			do_not_disturb = !do_not_disturb
			update_appearance()
		if("clear_history")
			if(is_advanced)
				callers_list.Cut()
		else
			return FALSE
	return TRUE

/obj/structure/transmitter/ui_data(mob/user)
	var/list/directory = list()
	for(var/id in GLOB.telephones)
		var/obj/structure/transmitter/target = GLOB.telephones[id]
		if(can_dial(target))
			directory += list(list("phone_id" = id, "display_name" = target.display_name, "phone_category" = target.phone_category, "phone_icon" = target.phone_icon))
	return list(
		"display_name" = display_name,
		"phone_id" = phone_id,
		"status" = status,
		"do_not_disturb" = do_not_disturb,
		"is_advanced" = is_advanced,
		"is_free" = is_free,
		"is_paid" = is_paid,
		"call_price" = PHONE_CALL_PRICE,
		"online" = !!find_exchange(),
		"handset_held" = can_use_handset(user),
		"current_call" = current_call ? list("display_name" = is_advanced ? current_call.display_name : "Неизвестный абонент", "phone_id" = is_advanced ? current_call.phone_id : "") : null,
		"callers_list" = is_advanced ? callers_list : list(),
		"transmitters" = directory,
	)

/// Finds a working exchange when dialing; no subsystem polling is needed.
/obj/structure/transmitter/proc/find_exchange()
	for(var/obj/machinery/central_telephone_exchange/candidate as anything in GLOB.telephone_exchanges)
		if(candidate.is_operational)
			return candidate
	return null

/// Shared directory and server-side dialing permission check.
/obj/structure/transmitter/proc/can_dial(obj/structure/transmitter/target)
	return !QDELETED(target) && target != src && target.handset && (target.phone_category in networks_transmit) && (!target.do_not_disturb || phone_category == PHONE_NET_CENTCOM)

/// Reserves both ends atomically, rejecting repeated requests before changing any state.
/obj/structure/transmitter/proc/start_call(mob/user, target_id)
	if(!can_use_handset(user) || status != PHONE_IDLE || current_call || !istext(target_id) || (!is_free && !is_paid))
		return FALSE
	var/obj/structure/transmitter/target = GLOB.telephones[target_id]
	var/obj/machinery/central_telephone_exchange/connection = find_exchange()
	if(!connection || !can_dial(target))
		return FALSE
	if(target.current_call || target.status != PHONE_IDLE || target.handset.loc != target)
		to_chat(user, span_warning("Линия занята."))
		set_call_sound(/datum/looping_sound/telephone/busy)
		return FALSE
	current_call = target
	target.current_call = src
	exchange = connection
	target.exchange = connection
	status = PHONE_OUTGOING
	target.status = PHONE_INCOMING
	add_call_history("out", target)
	target.add_call_history("in", src)
	set_call_sound(/datum/looping_sound/telephone/outgoing)
	target.set_call_sound(/datum/looping_sound/telephone/incoming)
	call_timer = addtimer(CALLBACK(src, PROC_REF(end_call)), 30 SECONDS, TIMER_STOPPABLE)
	update_appearance()
	target.update_appearance()
	return TRUE

/// Connects only the matching reserved pair; payment is consumed when answered.
/obj/structure/transmitter/proc/answer_call()
	var/obj/structure/transmitter/calling_phone = current_call
	if(status != PHONE_INCOMING || !calling_phone || calling_phone.current_call != src || calling_phone.status != PHONE_OUTGOING || !exchange?.is_operational || !can_use_handset(handset?.loc) || QDELETED(calling_phone.handset) || calling_phone.handset.loc == calling_phone)
		end_call()
		return FALSE
	if(calling_phone.call_timer != TIMER_ID_NULL)
		deltimer(calling_phone.call_timer)
	calling_phone.call_timer = TIMER_ID_NULL
	status = PHONE_CONNECTED
	calling_phone.status = PHONE_CONNECTED
	calling_phone.is_paid = FALSE
	set_call_sound(null)
	calling_phone.set_call_sound(null)
	update_appearance()
	calling_phone.update_appearance()
	return TRUE

/// Clears this end before visiting the peer, so teardown cannot recurse or affect a later call.
/obj/structure/transmitter/proc/end_call()
	var/obj/structure/transmitter/other = current_call
	current_call = null
	exchange = null
	status = PHONE_IDLE
	if(call_timer != TIMER_ID_NULL)
		deltimer(call_timer)
	call_timer = TIMER_ID_NULL
	set_call_sound(null)
	if(!QDELETED(other) && other.current_call == src)
		other.end_call()
	update_appearance()
	SStgui.update_uis(src)

/// Returns the owned handset, ending any active or ringing call.
/obj/structure/transmitter/proc/recall_phone()
	if(recalling || QDELETED(handset) || handset.loc == src)
		return
	recalling = TRUE
	end_call()
	if(ismob(handset.loc))
		var/mob/user = handset.loc
		user.temporarilyRemoveItemFromInventory(handset, force = TRUE)
	handset.clear_holder()
	handset.forceMove(src)
	playsound(src, 'modular_bandastation/telephones/sound/remote_hangup.ogg', 40, FALSE)
	recalling = FALSE
	SStgui.close_uis(src)
	update_appearance()

/obj/structure/transmitter/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	handset?.check_tether()
	handset?.update_beam()

/obj/structure/transmitter/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool == handset)
		recall_phone()
		return ITEM_INTERACT_SUCCESS
	if(is_free)
		return ..()
	var/obj/item/card/id/card = tool.GetID()
	if(!card && !istype(tool, /obj/item/coin))
		return ..()
	if(is_paid || current_call)
		to_chat(user, span_notice("Звонок уже оплачен или линия занята."))
		return ITEM_INTERACT_BLOCKING
	if(card)
		var/datum/bank_account/service_account = SSeconomy.get_dep_account(ACCOUNT_SRV)
		if(!card.registered_account || !service_account || !service_account.transfer_money(card.registered_account, PHONE_CALL_PRICE, "Telephone: [phone_id]"))
			to_chat(user, span_warning("Не удалось оплатить звонок."))
			return ITEM_INTERACT_BLOCKING
	else
		if(!user.temporarilyRemoveItemFromInventory(tool))
			return ITEM_INTERACT_BLOCKING
		qdel(tool)
	is_paid = TRUE
	playsound(src, 'sound/machines/coindrop.ogg', 30, TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/structure/transmitter/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/structure/transmitter/click_alt(mob/user)
	if(was_renamed || !can_interact(user))
		return
	var/new_name = tgui_input_text(user, "Как назвать телефон? Название можно изменить один раз.", "Телефон", display_name, MAX_NAME_LEN)
	if(QDELETED(src) || was_renamed || !new_name || !can_interact(user))
		return
	display_name = strip_html(new_name)
	was_renamed = TRUE
	return CLICK_ACTION_SUCCESS

/obj/structure/transmitter/update_overlays()
	. = ..()
	var/wall_phone = istype(src, /obj/structure/transmitter/mounted)
	var/prefix = wall_phone ? "wall" : "rotary"
	if(handset?.loc == src)
		. += mutable_appearance(icon, "[prefix]_handset[!wall_phone && status == PHONE_INCOMING ? "_ring" : ""]")
	var/status_color = do_not_disturb ? "red" : (status == PHONE_INCOMING ? "yellow" : "green")
	. += mutable_appearance('modular_bandastation/telephones/icons/phone.dmi', "[prefix]_[status_color]")
	. += emissive_appearance('modular_bandastation/telephones/icons/phone.dmi', "[prefix]_light[status == PHONE_INCOMING ? "_blink" : ""]", src)

/// Stores a bounded history without retaining the remote phone.
/obj/structure/transmitter/proc/add_call_history(direction, obj/structure/transmitter/other)
	if(length(callers_list) >= 5)
		callers_list.Cut(1, 2)
	callers_list += list(list("dir" = direction, "id" = other.phone_id, "name" = other.display_name))

/// Owns exactly one looping sound for the current call state.
/obj/structure/transmitter/proc/set_call_sound(sound_type)
	QDEL_NULL(call_sound)
	if(sound_type && handset)
		call_sound = new sound_type(handset, TRUE)

/// Telephone tones follow the handset; the incoming bell follows the base while docked.
/datum/looping_sound/telephone
	volume = 20
	use_sound_tokens = TRUE
	never_native_repeat = TRUE

/datum/looping_sound/telephone/outgoing
	start_sound = 'modular_bandastation/telephones/sound/dial.ogg'
	start_length = 3.2 SECONDS
	mid_sounds = list('modular_bandastation/telephones/sound/ring_outgoing.ogg' = 1)
	mid_length = 6 SECONDS

/datum/looping_sound/telephone/incoming
	mid_sounds = list('modular_bandastation/telephones/sound/telephone_ring.ogg' = 1)
	mid_length = 4 SECONDS
	volume = 60

/datum/looping_sound/telephone/dialtone
	mid_sounds = list('modular_bandastation/telephones/sound/dialtone.ogg' = 1)
	mid_length = 5 SECONDS
	volume = 10
	extra_range = 1 - SOUND_RANGE

/datum/looping_sound/telephone/busy
	mid_sounds = list('modular_bandastation/telephones/sound/phone_busy.ogg' = 1)
	mid_length = 5 SECONDS

/datum/looping_sound/telephone/unavailable
	parent_type = /datum/looping_sound/telephone/busy
	start_sound = 'modular_bandastation/telephones/sound/callstation_unavailable.ogg'
	start_length = 5.7 SECONDS

/datum/looping_sound/telephone/disconnected
	mid_sounds = list('modular_bandastation/telephones/sound/disconnected.ogg' = 1)
	mid_length = 3 SECONDS

/// Plays the three-tone sequence once, then stops its token instead of repeating.
/datum/looping_sound/telephone/disconnected/start_sound_loop()
	loop_started = TRUE
	play(get_sound())
	timer_id = addtimer(CALLBACK(src, PROC_REF(stop)), mid_length, TIMER_CLIENT_TIME | TIMER_STOPPABLE | TIMER_DELETE_ME, SSsound_loops)
