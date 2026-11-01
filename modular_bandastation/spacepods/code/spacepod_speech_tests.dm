/// Intercept only the external TTS dispatch, leaving native speech and its hearers unchanged.
/mob/living/carbon/human/consistent/spacepod_speech_counter
	var/tts_calls = 0
	var/last_tts_message
	var/last_tts_language
	var/tts_hearers_count = 0

/mob/living/carbon/human/consistent/spacepod_speech_counter/do_tts_message(message, language, message_mods, list/tts_filter, list/hearers)
	tts_calls++
	last_tts_message = message
	last_tts_language = language
	tts_hearers_count = length(hearers)

/// Mock only the headless display boundary; native Hear still translates and checks speech range.
/mob/living/carbon/human/consistent/spacepod_speech_listener
	var/last_displayed_message

/mob/living/carbon/human/consistent/spacepod_speech_listener/show_message(msg, type, alt_msg, alt_type, avoid_highlighting = FALSE)
	last_displayed_message = msg
	return TRUE

/// Both cabin occupants keep speaking without creating either native kind of overhead speech bubble.
/datum/unit_test/spacepod_speech_bubbles
	var/last_heard_message

/datum/unit_test/spacepod_speech_bubbles/proc/on_hearing(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	last_heard_message = hearing_args[HEARING_RAW_MESSAGE]

/datum/unit_test/spacepod_speech_bubbles/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.setDir(NORTH)
	var/mob/living/carbon/human/consistent/spacepod_speech_counter/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/spacepod_speech_counter/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/spacepod_speech_listener/listener = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	listener.mock_client = allocate(/datum/client_interface)
	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(on_hearing))
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The speech fixture's pilot could not board.")
	TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "The speech fixture's passenger could not board.")
	var/obj/item/radio/anchor = allocate(__IMPLIED_TYPE__, listener.loc)
	for(var/mob/living/carbon/human/consistent/spacepod_speech_counter/occupant as anything in list(pilot, passenger))
		TEST_ASSERT(HAS_TRAIT_FROM(occupant, TRAIT_RUNECHAT_HIDDEN, REF(pod)), "Boarding did not suppress the occupant's native runechat.")
		var/bubbles_before = length(occupant.update_on_z)
		last_heard_message = null
		occupant.say("Cabin speech remains audible")
		TEST_ASSERT_EQUAL(last_heard_message, "Cabin speech remains audible", "Suppressing cabin bubbles also blocked ordinary speech delivery.")
		TEST_ASSERT(findtext(listener.last_displayed_message, "Cabin speech remains audible"), "Native Hear did not deliver the intact cabin text to the display boundary.")
		TEST_ASSERT_EQUAL(occupant.tts_calls, 1, "A cabin utterance did not dispatch TTS exactly once.")
		TEST_ASSERT_EQUAL(occupant.last_tts_message, "Cabin speech remains audible", "The cabin fast path changed the TTS text.")
		TEST_ASSERT_EQUAL(occupant.last_tts_language, /datum/language/common, "The cabin fast path changed the TTS language.")
		TEST_ASSERT(occupant.tts_hearers_count > 0, "Cabin TTS lost the native speech hearers.")
		TEST_ASSERT_EQUAL(length(occupant.update_on_z), bubbles_before, "A real cabin utterance created the native speech-bubble sprite.")

		// These are the native creation entry points. Headless listeners have no real client, so
		// proceeding past their hidden-speaker gates would also produce an invalid-owner runtime.
		var/queued_before = length(SSrunechat.message_queue)
		listener.create_chat_message(occupant, /datum/language/common, "Hidden cabin text", list())
		listener.create_chat_message(occupant, raw_message = "Hidden cabin emote", runechat_flags = EMOTE_MESSAGE)
		var/atom/movable/virtualspeaker/proxy = allocate(/atom/movable/virtualspeaker, origin, occupant)
		listener.create_chat_message(proxy, /datum/language/common, "Hidden cabin radio text", list())
		proxy.runechat_anchors = list()
		proxy.runechat_anchors[listener] = anchor
		listener.create_chat_message(proxy, /datum/language/common, "Hidden anchored radio text", list())
		TEST_ASSERT_EQUAL(length(SSrunechat.message_queue), queued_before, "A hidden cabin speaker queued a native runechat overlay.")
	var/turf/destination = get_step(origin, NORTH)
	for(var/turf/footprint as anything in block(destination, locate(destination.x + 1, destination.y + 1, destination.z)))
		TEST_ASSERT(isopenturf(footprint) && !footprint.is_blocked_turf(ignore_atoms = list(pod)), "The speech fixture's movement destination is blocked at [COORD(footprint)].")
	TEST_ASSERT(pod.relaymove(pilot, NORTH), "The speech fixture could not perform a real piloted movement step.")
	STOP_PROCESSING(SSnewtonian_movement, pod.flight)
	pod.flight.process(0.05)
	TEST_ASSERT_EQUAL(pod.loc, destination, "The speech fixture did not actually move before speaking.")
	for(var/mob/living/carbon/human/consistent/spacepod_speech_counter/occupant as anything in list(pilot, passenger))
		var/bubbles_before = length(occupant.update_on_z)
		last_heard_message = null
		occupant.say("Moving cabin speech stays hidden")
		TEST_ASSERT_EQUAL(last_heard_message, "Moving cabin speech stays hidden", "Movement changed the cabin's native speech delivery.")
		TEST_ASSERT_EQUAL(occupant.tts_calls, 2, "Movement changed the cabin's one-TTS-dispatch-per-utterance behavior.")
		TEST_ASSERT_EQUAL(length(occupant.update_on_z), bubbles_before, "Movement restored the cabin's speech-bubble sprite.")
		TEST_ASSERT(HAS_TRAIT_FROM(occupant, TRAIT_RUNECHAT_HIDDEN, REF(pod)), "Movement dropped the occupant's runechat suppression.")
		TEST_ASSERT(pod.mob_exit(occupant, silent = TRUE), "The TTS control speaker could not leave the cabin.")
		bubbles_before = length(occupant.update_on_z)
		last_heard_message = null
		occupant.say("Outside speech remains audible")
		TEST_ASSERT_EQUAL(last_heard_message, "Outside speech remains audible", "The optimized cabin path changed outside speech delivery.")
		TEST_ASSERT(findtext(listener.last_displayed_message, "Outside speech remains audible"), "Native Hear did not deliver the intact outside text to the display boundary.")
		TEST_ASSERT_EQUAL(occupant.tts_calls, 3, "An outside utterance did not dispatch TTS exactly once.")
		TEST_ASSERT_EQUAL(occupant.last_tts_message, "Outside speech remains audible", "The outside control changed the TTS text.")
		TEST_ASSERT_EQUAL(length(occupant.update_on_z), bubbles_before + 1, "The outside control lost its native speech-bubble sprite.")
	UnregisterSignal(listener, COMSIG_MOVABLE_HEAR)

/// Normal exit, forced relocation and pod deletion release only the pod's own suppression source.
/datum/unit_test/spacepod_speech_lifecycle/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/turf/outside = get_step(origin, SOUTH)
	for(var/removal in list("exit", "relocate", "delete_pod"))
		var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
		var/pod_source = REF(pod)
		var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, outside)
		var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, outside)
		ADD_TRAIT(passenger, TRAIT_RUNECHAT_HIDDEN, TRAIT_SOURCE_UNIT_TESTS)
		TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The pilot could not board for [removal].")
		TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "The passenger could not board for [removal].")
		switch(removal)
			if("exit")
				pod.mob_exit(pilot, silent = TRUE)
				pod.mob_exit(passenger, silent = TRUE)
			if("relocate")
				pilot.forceMove(outside)
				passenger.forceMove(outside)
			if("delete_pod")
				qdel(pod)
		TEST_ASSERT(!HAS_TRAIT_FROM(pilot, TRAIT_RUNECHAT_HIDDEN, pod_source), "[removal] retained the pilot's pod runechat source.")
		TEST_ASSERT(!HAS_TRAIT_FROM(passenger, TRAIT_RUNECHAT_HIDDEN, pod_source), "[removal] retained the passenger's pod runechat source.")
		TEST_ASSERT(!HAS_TRAIT(pilot, TRAIT_RUNECHAT_HIDDEN), "[removal] left the pilot's ordinary runechat disabled.")
		TEST_ASSERT(HAS_TRAIT_FROM(passenger, TRAIT_RUNECHAT_HIDDEN, TRAIT_SOURCE_UNIT_TESTS), "[removal] removed another feature's runechat suppression.")
		REMOVE_TRAIT(passenger, TRAIT_RUNECHAT_HIDDEN, TRAIT_SOURCE_UNIT_TESTS)
		for(var/mob/living/occupant as anything in list(pilot, passenger))
			var/bubbles_before = length(occupant.update_on_z)
			occupant.say("Outside speech bubbles return")
			TEST_ASSERT_EQUAL(length(occupant.update_on_z), bubbles_before + 1, "[removal] did not restore native speech-bubble creation outside the pod.")
		qdel(pod)
		qdel(pilot)
		qdel(passenger)

/// The visual suppression must not stop actual native radio transmission from inside the cabin.
/datum/unit_test/spacepod_speech_radio
	var/receiver_received = FALSE

/datum/unit_test/spacepod_speech_radio/proc/on_radio_received(datum/source, list/data)
	SIGNAL_HANDLER
	receiver_received = TRUE

/datum/unit_test/spacepod_speech_radio/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, origin)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The radio fixture's pilot could not board.")
	var/obj/item/radio/sender = allocate(__IMPLIED_TYPE__, pod)
	var/obj/item/radio/receiver = allocate(__IMPLIED_TYPE__, locate(run_loc_floor_bottom_left.x + 13, origin.y, origin.z))
	sender.set_broadcasting(TRUE)
	sender.set_frequency(FREQ_CENTCOM)
	sender.special_channels = RADIO_SPECIAL_CENTCOM
	receiver.set_frequency(FREQ_CENTCOM)
	receiver.special_channels = RADIO_SPECIAL_CENTCOM
	RegisterSignal(receiver, COMSIG_RADIO_RECEIVE_MESSAGE, PROC_REF(on_radio_received))
	pilot.say("The cabin radio still transmits")
	TEST_ASSERT(receiver_received, "Disabling cabin speech bubbles stopped the native radio broadcast.")
	UnregisterSignal(receiver, COMSIG_RADIO_RECEIVE_MESSAGE)

/// A radio proxy can outlive its original speaker; its remaining hidden anchor still suppresses runechat.
/datum/unit_test/spacepod_speech_deleted_proxy/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, origin)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/listener = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The hidden-anchor fixture's pilot could not board.")
	var/mob/living/carbon/human/consistent/original_source = allocate(__IMPLIED_TYPE__, listener.loc)
	var/atom/movable/virtualspeaker/deleted_source_proxy = allocate(/atom/movable/virtualspeaker, origin, original_source)
	deleted_source_proxy.runechat_anchors = list()
	deleted_source_proxy.runechat_anchors[listener] = pilot
	qdel(original_source)
	TEST_ASSERT(QDELETED(deleted_source_proxy.source), "The radio proxy fixture's original source was not actually deleted.")
	var/queued_before = length(SSrunechat.message_queue)
	listener.create_chat_message(deleted_source_proxy, /datum/language/common, "Deleted radio source", list())
	TEST_ASSERT_EQUAL(length(SSrunechat.message_queue), queued_before, "Deleting the original source bypassed the hidden-anchor runechat gate.")

	// Native virtualspeaker initialization also accepts an absent source.
	var/atom/movable/virtualspeaker/null_source_proxy = allocate(/atom/movable/virtualspeaker, origin)
	TEST_ASSERT_NULL(null_source_proxy.source, "The native sourceless radio proxy unexpectedly acquired a source.")
	null_source_proxy.runechat_anchors = list()
	null_source_proxy.runechat_anchors[listener] = pilot
	listener.create_chat_message(null_source_proxy, /datum/language/common, "Absent radio source", list())
	TEST_ASSERT_EQUAL(length(SSrunechat.message_queue), queued_before, "An absent original source bypassed the hidden-anchor runechat gate.")
