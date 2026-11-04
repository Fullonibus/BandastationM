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

/// Dropping, exceeding the cord and destroying a held handset all release the other end.
/datum/unit_test/telephone/handset_cleanup/Run()
	ADD_TRAIT(calling_user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must hold the handset.")
	calling_user.forceMove(locate(calling_phone.x + 2, calling_phone.y, calling_phone.z))
	TEST_ASSERT_EQUAL(calling_phone.ui_status(calling_user, GLOB.default_state), UI_INTERACTIVE, "The holder must control the phone beyond adjacency while the cord still reaches.")
	calling_user.forceMove(get_turf(calling_phone))
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The call must begin before dropping the handset.")
	calling_user.dropItemToGround(calling_phone.handset)
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, calling_phone, "Dropping must return the handset to its base.")
	TEST_ASSERT_EQUAL(calling_phone.ui_status(calling_user, GLOB.default_state), UI_CLOSE, "Dropping the handset must revoke control of its UI.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "Dropping must disconnect the remote phone.")
	TEST_ASSERT_NULL(calling_phone.handset.holder, "Returning the handset must clear its holder.")
	TEST_ASSERT_NULL(calling_phone.handset.telephone_beam, "Returning the handset must delete its cord.")
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must be able to lift the returned handset.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The phone must work after a dropped handset.")
	calling_user.forceMove(locate(calling_phone.x + PHONE_MAX_RANGE + 1, calling_phone.y, calling_phone.z))
	TEST_ASSERT_EQUAL(calling_phone.handset.loc, calling_phone, "Walking beyond the cord must return the handset.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "Walking beyond the cord must disconnect the remote phone.")
	calling_user.forceMove(get_turf(calling_phone))
	TEST_ASSERT(calling_user.put_in_hands(calling_phone.handset), "The caller must lift the handset before deletion.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The phone must work after exceeding the cord.")
	qdel(calling_phone.handset)
	TEST_ASSERT_NULL(calling_phone.handset, "A deleted handset must be detached from its base.")
	TEST_ASSERT_NULL(receiving_phone.current_call, "Deleting a held handset must disconnect its remote peer.")
	TEST_ASSERT_EQUAL(calling_phone.call_timer, TIMER_ID_NULL, "Deleting the handset must cancel the ringing timeout.")

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
