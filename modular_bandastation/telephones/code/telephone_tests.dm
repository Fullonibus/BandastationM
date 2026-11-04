/// Real phones and holders, isolated from any exchange loaded by the current map.
/datum/unit_test/telephone
	abstract_type = /datum/unit_test/telephone
	var/list/original_exchanges
	var/obj/machinery/central_telephone_exchange/switchboard
	var/obj/structure/transmitter/calling_phone
	var/obj/structure/transmitter/receiving_phone
	var/mob/living/carbon/human/consistent/calling_user
	var/mob/living/carbon/human/consistent/receiving_user

/datum/unit_test/telephone/New()
	. = ..()
	original_exchanges = GLOB.telephone_exchanges
	GLOB.telephone_exchanges = list()
	switchboard = allocate(/obj/machinery/central_telephone_exchange)
	switchboard.set_is_operational(TRUE)
	calling_phone = allocate(/obj/structure/transmitter)
	receiving_phone = allocate(/obj/structure/transmitter)
	calling_user = allocate(/mob/living/carbon/human/consistent)
	receiving_user = allocate(/mob/living/carbon/human/consistent)

/datum/unit_test/telephone/Destroy()
	. = ..()
	GLOB.telephone_exchanges = original_exchanges
	original_exchanges = null
	switchboard = null
	calling_phone = null
	receiving_phone = null
	calling_user = null
	receiving_user = null

/// A repeated or competing request cannot replace either end of an existing call.
/datum/unit_test/telephone/call_pair/Run()
	var/obj/structure/transmitter/third_phone = allocate(/obj/structure/transmitter)
	var/mob/living/carbon/human/consistent/third_user = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must hold the handset.")
	TEST_ASSERT(third_user.put_in_hands(third_phone.handset), "The competing caller must hold a handset.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The first call must start.")
	TEST_ASSERT(!calling_phone.start_call(calling_user, third_phone.phone_id), "A repeated request must not replace the reserved callee.")
	TEST_ASSERT(!third_phone.start_call(third_user, receiving_phone.phone_id), "An incoming call must reserve the callee against other callers.")
	TEST_ASSERT_EQUAL(calling_phone.current_call, receiving_phone, "The original caller must retain its peer.")
	TEST_ASSERT_EQUAL(receiving_phone.current_call, calling_phone, "The callee must retain the original caller.")
	TEST_ASSERT_NULL(third_phone.current_call, "A rejected caller must not retain a peer.")
	TEST_ASSERT(receiving_user.put_in_hands(receiving_phone.handset), "The recipient must lift the handset.")
	TEST_ASSERT(receiving_phone.answer_call(), "The reserved call must connect.")
	TEST_ASSERT_EQUAL(calling_phone.status, PHONE_CONNECTED, "The caller must enter the connected state.")
	TEST_ASSERT_EQUAL(receiving_phone.status, PHONE_CONNECTED, "The callee must enter the connected state.")
	TEST_ASSERT_EQUAL(calling_phone.call_timer, TIMER_ID_NULL, "Answering must cancel the ringing timeout.")
	calling_phone.end_call()
	TEST_ASSERT_NULL(calling_phone.current_call, "Hanging up must clear the initiating peer.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "Hanging up must also clear the remote peer.")
	TEST_ASSERT_EQUAL(receiving_phone.status, PHONE_IDLE, "The remote phone must return to idle.")
	TEST_ASSERT_NULL(receiving_phone.call_sound, "Hanging up must stop the remote ringer or tone.")

/// Forged IDs and directory restrictions are rejected at the server's dialing boundary.
/datum/unit_test/telephone/dial_permissions/Run()
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must hold the handset.")
	TEST_ASSERT(!calling_phone.start_call(receiving_user, receiving_phone.phone_id), "Another mob must not control the held handset.")
	TEST_ASSERT(!calling_phone.start_call(calling_user, calling_phone.phone_id), "A phone must not call itself.")
	TEST_ASSERT(!calling_phone.start_call(calling_user, "missing-telephone"), "An unknown ID must be rejected.")
	TEST_ASSERT(!calling_phone.start_call(calling_user, list(receiving_phone.phone_id)), "A non-text ID must be rejected.")
	receiving_phone.phone_category = PHONE_NET_COMMAND
	TEST_ASSERT(!calling_phone.start_call(calling_user, receiving_phone.phone_id), "Knowing a command phone's ID must not grant network access.")
	receiving_phone.phone_category = PHONE_NET_PUBLIC
	receiving_phone.do_not_disturb = TRUE
	TEST_ASSERT(!calling_phone.start_call(calling_user, receiving_phone.phone_id), "A forged request must not bypass do-not-disturb.")
	TEST_ASSERT_NULL(calling_phone.current_call, "Rejected requests must leave the caller idle.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "Rejected requests must leave the callee idle.")
	var/obj/structure/transmitter/centcom/priority_phone = allocate(/obj/structure/transmitter/centcom)
	TEST_ASSERT(receiving_user.put_in_hands(priority_phone.handset), "The priority caller must hold its own handset.")
	TEST_ASSERT(priority_phone.start_call(receiving_user, receiving_phone.phone_id), "Central Command must be able to bypass do-not-disturb.")
	receiving_phone.end_call()
	TEST_ASSERT_NULL(priority_phone.current_call, "Rejecting a ringing call must clear its caller.")

/// Dropping, giving and reaching the cord's limit preserve a call; docking or deletion ends it.
/datum/unit_test/telephone/handset_cleanup/Run()
	var/turf/origin = get_turf(calling_phone)
	var/turf/cord_limit = locate(origin.x + PHONE_MAX_RANGE, origin.y, origin.z)
	var/turf/beyond_cord = get_step(cord_limit, EAST)
	ADD_TRAIT(calling_user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must hold the handset.")
	calling_user.forceMove(locate(calling_phone.x + 2, calling_phone.y, calling_phone.z))
	TEST_ASSERT_EQUAL(calling_phone.ui_status(calling_user, GLOB.default_state), UI_INTERACTIVE, "The holder must control the phone beyond adjacency while the cord still reaches.")
	calling_user.forceMove(get_turf(calling_phone))
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The call must begin before dropping the handset.")
	calling_user.dropItemToGround(calling_phone.handset)
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, get_turf(calling_phone), "Dropping must leave the handset on the floor, not dock it.")
	TEST_ASSERT_EQUAL(calling_phone.ui_status(calling_user, GLOB.default_state), UI_CLOSE, "Dropping the handset must revoke control of its UI.")
	TEST_ASSERT_EQUAL(receiving_phone.current_call, calling_phone, "Dropping must preserve the ringing call.")
	TEST_ASSERT_NULL(calling_phone.handset.holder, "A handset on the floor must not retain its previous holder.")
	TEST_ASSERT_NOTNULL(calling_phone.handset.telephone_beam, "A handset on the floor must retain its cord.")
	TEST_ASSERT_EQUAL(calling_phone.handset.telephone_beam.target, calling_phone.handset, "The cord on the floor must follow the handset itself.")
	TEST_ASSERT(receiving_user.put_in_hands(receiving_phone.handset), "The recipient must lift its handset.")
	TEST_ASSERT(receiving_phone.answer_call(), "The recipient must be able to answer while the caller's handset lies on the floor.")
	TEST_ASSERT_EQUAL(calling_phone.status, PHONE_CONNECTED, "The off-hook handset on the floor must remain connected.")
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must be able to pick the handset back up.")
	var/mob/living/carbon/human/consistent/next_user = allocate(/mob/living/carbon/human/consistent)
	next_user.take(calling_user, calling_phone.handset)
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, next_user, "The native give/take path must transfer the handset without docking it.")
	TEST_ASSERT_EQUAL(calling_phone.handset.holder, next_user, "The recipient must become the handset's holder.")
	TEST_ASSERT(!calling_phone.can_use_handset(calling_user) && calling_phone.can_use_handset(next_user), "Control must move to the new holder.")
	TEST_ASSERT(calling_user.Move(beyond_cord, EAST), "The former holder must be free to walk beyond the cord after a handoff.")
	TEST_ASSERT(calling_user.Move(get_step(beyond_cord, NORTH), NORTH), "The former holder must remain free to move outside the cord.")
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, next_user, "Movement of the former holder must not recall the handset.")
	TEST_ASSERT_EQUAL(receiving_phone.current_call, calling_phone, "Giving the handset away must preserve the connected call.")
	TEST_ASSERT(next_user.Move(cord_limit, EAST), "The holder must be able to reach the cord's maximum length.")
	TEST_ASSERT(!next_user.Move(beyond_cord, EAST), "The cord must block an outward cardinal step.")
	TEST_ASSERT_EQUAL(next_user.loc, cord_limit, "A blocked step must leave the holder at the cord's limit.")
	var/turf/cord_corner = locate(cord_limit.x, origin.y + PHONE_MAX_RANGE, origin.z)
	TEST_ASSERT(next_user.Move(cord_corner, NORTH), "The holder must be able to walk along the cord's boundary.")
	TEST_ASSERT(!next_user.Move(get_step(cord_corner, NORTHEAST), NORTHEAST), "The cord must also block an outward diagonal step.")
	TEST_ASSERT_EQUAL(next_user.loc, cord_corner, "A blocked diagonal step must leave the holder in place.")
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, next_user, "Reaching the cord's limit must leave the handset in its holder's hand.")
	TEST_ASSERT_EQUAL(calling_phone.status, PHONE_CONNECTED, "Blocked movement must preserve the connected call.")
	calling_phone.recall_phone()
	receiving_phone.recall_phone()
	calling_user.forceMove(origin)
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The handset must work after being docked.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "A new call must start before moving the handset on the floor.")
	calling_user.dropItemToGround(calling_phone.handset)
	TEST_ASSERT(calling_phone.handset.Move(cord_limit, EAST), "The handset on the floor must move within the cord's length.")
	TEST_ASSERT(!calling_phone.handset.Move(beyond_cord, EAST), "The cord must block dragging an unheld handset too far.")
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, cord_limit, "A blocked drag must leave the handset on the floor at the cord's limit.")
	TEST_ASSERT_EQUAL(receiving_phone.current_call, calling_phone, "Blocked movement of the unheld handset must preserve the ringing call.")
	calling_user.forceMove(cord_limit)
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must lift the handset before deletion.")
	qdel(calling_phone.handset)
	TEST_ASSERT_NULL(calling_phone.handset, "A deleted handset must be detached from its base.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "Deleting a held handset must disconnect its remote peer.")
	TEST_ASSERT_EQUAL(calling_phone.call_timer, TIMER_ID_NULL, "Deleting the handset must cancel the ringing timeout.")

/// Picking up, handing over and moving the base obey the same cord as walking with the handset.
/datum/unit_test/telephone/cord_movement/Run()
	var/turf/origin = get_turf(calling_phone)
	var/turf/cord_limit = locate(origin.x + PHONE_MAX_RANGE, origin.y, origin.z)
	var/turf/beyond_cord = get_step(cord_limit, EAST)
	var/turf/near_limit = get_step(cord_limit, WEST)
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must lift the handset.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The call must begin before checking cord interactions.")
	TEST_ASSERT(calling_user.Move(cord_limit, EAST), "The holder must reach the cord's limit.")
	calling_user.dropItemToGround(calling_phone.handset)
	var/mob/living/carbon/human/consistent/next_user = allocate(/mob/living/carbon/human/consistent, beyond_cord)
	calling_phone.handset.attempt_pickup(next_user)
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, cord_limit, "An adjacent user beyond the cord must not pick up the handset.")
	TEST_ASSERT_NULL(calling_phone.handset.holder, "A rejected pickup must leave the handset unheld.")
	calling_phone.handset.attempt_pickup(calling_user)
	TEST_ASSERT_EQUAL(calling_phone.handset.holder, calling_user, "A user within the cord must be able to pick up the handset normally.")
	next_user.take(calling_user, calling_phone.handset)
	TEST_ASSERT_EQUAL(calling_user.get_active_held_item(), calling_phone.handset, "An out-of-range recipient must not unequip the offering user's handset.")
	TEST_ASSERT_EQUAL(calling_phone.handset.holder, calling_user, "A rejected handoff must retain the original holder.")
	TEST_ASSERT(next_user.Move(near_limit, WEST), "The recipient must be able to approach within the cord.")
	next_user.take(calling_user, calling_phone.handset)
	TEST_ASSERT_EQUAL(calling_phone.handset.holder, next_user, "The normal give/take path must work within the cord.")
	TEST_ASSERT(calling_user.Move(beyond_cord, EAST), "A successful handoff must release the former holder's movement restriction.")
	TEST_ASSERT(calling_user.Move(get_step(beyond_cord, NORTH), NORTH), "The former holder must remain free to move outside the cord.")
	next_user.forceMove(locate(beyond_cord.x, beyond_cord.y + 2, beyond_cord.z))
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, near_limit, "A forced relocation must leave the handset on the holder's previous reachable turf.")
	TEST_ASSERT_NULL(calling_phone.handset.holder, "Forced relocation must release the handset from the moved holder.")
	TEST_ASSERT_EQUAL(receiving_phone.current_call, calling_phone, "Leaving the handset on its reachable turf must preserve the call.")
	TEST_ASSERT(calling_phone.handset.Move(cord_limit, EAST), "The dropped handset must still be movable within the cord.")
	calling_phone.set_anchored(FALSE)
	var/turf/shifted_base = get_step(origin, EAST)
	TEST_ASSERT(calling_phone.Move(shifted_base, EAST), "An unfastened base must be able to move closer to its handset.")
	TEST_ASSERT(calling_phone.handset.Move(beyond_cord, EAST), "Moving the base must update the handset's reachable boundary.")
	TEST_ASSERT(!calling_phone.Move(origin, WEST), "The cord must block moving the base away from an unheld handset at full length.")
	TEST_ASSERT_EQUAL(calling_phone.loc, shifted_base, "A blocked base movement must leave the base in place.")
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, beyond_cord, "Moving the base must never dock its handset.")
	TEST_ASSERT_EQUAL(receiving_phone.current_call, calling_phone, "Moving either endpoint within the cord must preserve the call.")

/// Hanging up cancels audio already playing as well as callbacks waiting to play the next tone.
/datum/unit_test/telephone/audio_cleanup/Run()
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must hold the handset.")
	calling_phone.set_call_sound(/datum/looping_sound/telephone/dialtone)
	var/datum/looping_sound/telephone/dialtone = calling_phone.call_sound
	var/datum/sound_token/dialtone_token = dialtone.sound_token_instance
	TEST_ASSERT_NOTNULL(dialtone_token, "The dialtone must own a stoppable sound token.")
	var/dialtone_channel = dialtone_token.sound_channel
	TEST_ASSERT(SSsounds.using_channels[num2text(dialtone_channel)], "The playing tone must reserve its own channel.")
	calling_phone.recall_phone()
	TEST_ASSERT_NULL(calling_phone.call_sound, "Docking must release the phone's sound loop.")
	TEST_ASSERT(QDELETED(dialtone) && QDELETED(dialtone_token), "Docking must stop the sound already playing, not just cancel its next repetition.")
	TEST_ASSERT_NULL(SSsounds.using_channels[num2text(dialtone_channel)], "Docking must release the dialtone channel immediately.")
	TEST_ASSERT(!dialtone.is_active(), "A docked phone must not retain a callback that could restart its dialtone.")

	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must lift its handset again.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The call must begin before testing both ringing sounds.")
	var/datum/looping_sound/telephone/outgoing = calling_phone.call_sound
	var/datum/looping_sound/telephone/incoming = receiving_phone.call_sound
	var/datum/sound_token/outgoing_token = outgoing.sound_token_instance
	var/datum/sound_token/incoming_token = incoming.sound_token_instance
	TEST_ASSERT_NOTNULL(outgoing_token, "The initial dialing sound must be stoppable before ringback begins.")
	TEST_ASSERT_NOTNULL(incoming_token, "The receiving bell must own a stoppable sound token.")
	TEST_ASSERT(outgoing.timer_id && !outgoing.loop_started, "The outgoing sound must still be waiting for its initial dialing delay.")
	var/outgoing_channel = outgoing_token.sound_channel
	var/incoming_channel = incoming_token.sound_channel
	calling_phone.end_call()
	TEST_ASSERT(QDELETED(outgoing_token) && QDELETED(incoming_token), "Ending a call must stop both sounds immediately.")
	TEST_ASSERT_NULL(calling_phone.call_sound, "Ending a call must release the outgoing loop.")
	TEST_ASSERT_NULL(receiving_phone.call_sound, "Ending a call must release the incoming loop.")
	TEST_ASSERT(!outgoing.is_active() && !incoming.is_active(), "Ending a call must cancel both the delayed ringback and the repeated bell.")
	TEST_ASSERT_NULL(SSsounds.using_channels[num2text(outgoing_channel)], "The outgoing channel must be freed at hangup.")
	TEST_ASSERT_NULL(SSsounds.using_channels[num2text(incoming_channel)], "The incoming channel must be freed at hangup.")

	calling_phone.set_call_sound(/datum/looping_sound/telephone/disconnected)
	var/datum/looping_sound/telephone/disconnected = calling_phone.call_sound
	var/datum/sound_token/disconnected_token = disconnected.sound_token_instance
	TEST_ASSERT_NOTNULL(disconnected_token, "The three-beep sequence must own a stoppable sound token.")
	var/disconnected_channel = disconnected_token.sound_channel
	var/deadline = world.time + 5 SECONDS
	UNTIL(!disconnected.is_active() || world.time >= deadline)
	TEST_ASSERT(!disconnected.is_active(), "The three-beep sequence must stop instead of repeating.")
	TEST_ASSERT(QDELETED(disconnected_token), "Finishing the sequence must stop its audio token.")
	TEST_ASSERT_NULL(SSsounds.using_channels[num2text(disconnected_channel)], "Finishing the sequence must release its channel.")

	calling_phone.set_call_sound(/datum/looping_sound/telephone/disconnected)
	disconnected = calling_phone.call_sound
	disconnected_token = disconnected.sound_token_instance
	TEST_ASSERT_NOTNULL(disconnected_token, "A new three-beep sequence must start normally.")
	disconnected_channel = disconnected_token.sound_channel
	calling_phone.recall_phone()
	TEST_ASSERT(QDELETED(disconnected_token) && !disconnected.is_active(), "Docking must interrupt the three-beep sequence and cancel its callback immediately.")
	TEST_ASSERT_NULL(SSsounds.using_channels[num2text(disconnected_channel)], "Interrupting the sequence must release its channel immediately.")

/// Power changes and deletion use the same disconnection path for both participants.
/datum/unit_test/telephone/exchange_cleanup/Run()
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must hold the handset.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The ringing call must start.")
	switchboard.set_is_operational(FALSE)
	TEST_ASSERT_NULL(calling_phone.current_call, "Losing exchange power must disconnect the caller.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "Losing exchange power must disconnect the callee.")
	TEST_ASSERT(!calling_phone.start_call(calling_user, receiving_phone.phone_id), "An unpowered exchange must not connect new calls.")
	switchboard.set_is_operational(TRUE)
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "Restoring exchange power must permit new calls.")
	TEST_ASSERT(receiving_user.put_in_hands(receiving_phone.handset), "The recipient must lift its handset.")
	TEST_ASSERT(receiving_phone.answer_call(), "The call must connect before deleting its exchange.")
	qdel(switchboard)
	TEST_ASSERT_NULL(calling_phone.current_call, "Deleting an exchange must disconnect an ongoing caller.")
	TEST_ASSERT_NULL(receiving_phone.exchange, "Deleting an exchange must release the remote exchange reference.")
	TEST_ASSERT_EQUAL(receiving_phone.status, PHONE_IDLE, "Deleting an exchange must leave its phones idle.")
	TEST_ASSERT_NULL(calling_phone.find_exchange(), "The deleted exchange must not remain discoverable.")

/// Payment is accepted once and reserves credit until a call is actually answered.
/datum/unit_test/telephone/payphone_credit
	var/list/original_departmental_accounts

/datum/unit_test/telephone/payphone_credit/New()
	. = ..()
	original_departmental_accounts = SSeconomy.departmental_accounts
	SSeconomy.departmental_accounts = list()

/datum/unit_test/telephone/payphone_credit/Destroy()
	. = ..()
	SSeconomy.departmental_accounts = original_departmental_accounts
	original_departmental_accounts = null

/datum/unit_test/telephone/payphone_credit/Run()
	var/obj/structure/transmitter/mounted/payphone = allocate(/obj/structure/transmitter/mounted)
	var/datum/bank_account/department/service_account = allocate(/datum/bank_account/department, ACCOUNT_SRV, 0)
	var/datum/bank_account/payer = allocate(/datum/bank_account, "Telephone test", null, 1, FALSE)
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.set_account(payer)
	TEST_ASSERT(calling_user.put_in_hands(payphone.handset), "The payer must hold the payphone handset.")
	TEST_ASSERT(calling_user.put_in_hands(card), "The payer must hold the payment card.")
	payer.account_balance = PHONE_CALL_PRICE - 1
	TEST_ASSERT_EQUAL(payphone.item_interaction(calling_user, card, list()), ITEM_INTERACT_BLOCKING, "Insufficient funds must reject payment.")
	TEST_ASSERT(!payphone.is_paid, "A rejected payment must not create call credit.")
	TEST_ASSERT_EQUAL(service_account.account_balance, 0, "A rejected payment must not credit the department.")
	payer.account_balance = 20
	TEST_ASSERT_EQUAL(payphone.item_interaction(calling_user, card, list()), ITEM_INTERACT_SUCCESS, "A valid card must pay for a call.")
	TEST_ASSERT_EQUAL(payer.account_balance, 15, "The payphone must debit exactly five credits.")
	TEST_ASSERT_EQUAL(service_account.account_balance, 5, "The service department must receive the payment.")
	TEST_ASSERT_EQUAL(payphone.item_interaction(calling_user, card, list()), ITEM_INTERACT_BLOCKING, "A duplicate payment must be rejected while credit remains.")
	TEST_ASSERT_EQUAL(payer.account_balance, 15, "Repeated card use must not debit the payer again.")
	TEST_ASSERT(!payphone.start_call(calling_user, "missing-telephone"), "An invalid number must be rejected.")
	TEST_ASSERT(payphone.is_paid, "An invalid number must preserve the paid call.")
	TEST_ASSERT(receiving_user.put_in_hands(receiving_phone.handset), "The recipient must take its phone off-hook to make it busy.")
	TEST_ASSERT(!payphone.start_call(calling_user, receiving_phone.phone_id), "An off-hook phone must reject the call as busy.")
	TEST_ASSERT(payphone.is_paid, "A busy number must preserve the paid call.")
	receiving_phone.recall_phone()
	TEST_ASSERT(payphone.start_call(calling_user, receiving_phone.phone_id), "The paid call must ring an available phone.")
	var/deadline = world.time + 35 SECONDS
	UNTIL(!payphone.current_call || world.time >= deadline)
	TEST_ASSERT_NULL(payphone.current_call, "An unanswered call must time out within thirty seconds plus scheduler margin.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "The ringing timeout must release the recipient.")
	TEST_ASSERT(payphone.is_paid, "An unanswered call must preserve the paid call.")
	TEST_ASSERT(payphone.start_call(calling_user, receiving_phone.phone_id), "The retained credit must permit another call.")
	TEST_ASSERT(receiving_user.put_in_hands(receiving_phone.handset), "The recipient must lift its handset to answer.")
	TEST_ASSERT(receiving_phone.answer_call(), "The paid call must connect.")
	TEST_ASSERT(!payphone.is_paid, "Answering must consume exactly one paid call.")
	payphone.end_call()
	receiving_phone.recall_phone()
	TEST_ASSERT(!payphone.start_call(calling_user, receiving_phone.phone_id), "Another call must require a new payment.")

/// Observe the real speech and TTS220 delivery paths, without a network client or voice service.
/datum/unit_test/telephone/speech_relay
	var/heard_count = 0
	var/heard_message
	var/tts_message
	var/legacy_tts_enabled

/datum/unit_test/telephone/speech_relay/Destroy()
	if(!isnull(legacy_tts_enabled))
		SStts.tts_enabled = legacy_tts_enabled
	return ..()

/datum/unit_test/telephone/speech_relay/proc/on_hear(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	heard_count++
	heard_message = hearing_args[HEARING_RAW_MESSAGE]

/datum/unit_test/telephone/speech_relay/proc/on_tts(datum/source, listener, message)
	SIGNAL_HANDLER
	if(listener == receiving_user)
		tts_message = message

/datum/unit_test/telephone/speech_relay/Run()
	legacy_tts_enabled = SStts.tts_enabled
	SStts.tts_enabled = FALSE
	calling_user.voice = null
	calling_user.set_species(/datum/species/lizard)
	calling_user.set_active_language(/datum/language/common)
	var/mob/living/carbon/human/consistent/tts_listener/listener = allocate(/mob/living/carbon/human/consistent/tts_listener)
	receiving_user = listener
	listener.mock_client = allocate(/datum/client_interface)
	var/turf/remote_turf = locate(calling_phone.x + 10, calling_phone.y, calling_phone.z)
	receiving_phone.forceMove(remote_turf)
	listener.forceMove(remote_turf)
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must lift its handset.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The speech call must start.")
	TEST_ASSERT(listener.put_in_hands(receiving_phone.handset), "The recipient must lift its handset.")
	TEST_ASSERT(receiving_phone.answer_call(), "The speech call must connect.")
	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))
	// TTS220's signal define is included after the core unit tests.
	RegisterSignal(calling_user, "atom_tts_cast", PROC_REF(on_tts))
	calling_user.say("She is so sassy", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 1, "The remote listener must receive exactly one utterance.")
	TEST_ASSERT_EQUAL(heard_message, "SSShe isss ssso sssasssy", "The telephone must relay the processed accent rather than raw input.")
	TEST_ASSERT_EQUAL(tts_message, heard_message, "TTS220 must receive the listener's processed message.")
	calling_user.set_active_language(/datum/language/draconic)
	calling_user.say("Hidden words", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 2, "A second-language utterance must be relayed once.")
	TEST_ASSERT_NOTEQUAL(heard_message, "Hidden words", "The telephone must not reveal a language the listener cannot understand.")
	TEST_ASSERT_EQUAL(tts_message, heard_message, "TTS220 must voice the same scrambled language as chat.")
	receiving_phone.handset.attack_self(listener)
	calling_user.say("Lowered receiver", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 2, "A lowered receiver must mute reception.")
	receiving_phone.handset.attack_self(listener)
	calling_phone.handset.attack_self(calling_user)
	calling_user.say("Lowered sender", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 2, "A lowered caller handset must mute transmission.")
