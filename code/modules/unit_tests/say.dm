/// Test to verify message mods are parsed correctly
/datum/unit_test/get_message_mods
	var/mob/host_mob

/datum/unit_test/get_message_mods/Run()
	host_mob = allocate(/mob/living/carbon/human/consistent)

	test("Hello", "Hello", list())
	test(";HELP", "HELP", list(MODE_HEADSET = TRUE))
	test(";%Never gonna give you up", "Never gonna give you up", list(MODE_HEADSET = TRUE, MODE_SING = TRUE))
	test(".s Gun plz", "Gun plz", list(RADIO_KEY = RADIO_KEY_SECURITY, RADIO_EXTENSION = RADIO_CHANNEL_SECURITY))
	test("...What", "...What", list())

/datum/unit_test/get_message_mods/proc/test(message, expected_message, list/expected_mods)
	var/list/mods = list()
	TEST_ASSERT_EQUAL(host_mob.get_message_mods(message, mods), expected_message, "Chopped message was not what we expected. Message: [message]")

	for (var/mod_key in mods)
		TEST_ASSERT_EQUAL(mods[mod_key], expected_mods[mod_key], "The value for [mod_key] was not what we expected. Message: [message]")
		expected_mods -= mod_key

	TEST_ASSERT(!expected_mods.len,
		"Some message mods were expected, but were not returned by get_message_mods: [json_encode(expected_mods)]. Message: [message]")

/// Test to ensure native tongue languages properly impact speech
/datum/unit_test/speech_modifiers
	var/mob/living/carbon/human/talking_lizard
	var/list/handle_speech_result = null

/datum/unit_test/speech_modifiers/proc/handle_speech(datum/source, list/speech_args)
	SIGNAL_HANDLER

	TEST_ASSERT(speech_args[SPEECH_MESSAGE], "Handle speech signal does not have a message arg")
	TEST_ASSERT(speech_args[SPEECH_LANGUAGE], "Handle speech signal does not have a language arg")

	// saving hearing_args directly via handle_speech_result = speech_args won't work since the arg list
	// is a temporary variable that gets garbage collected after it's done being used by procs
	// therefore we need to create a new list and transfer the args
	handle_speech_result = list()
	handle_speech_result += speech_args

/datum/unit_test/speech_modifiers/Run()
	talking_lizard = allocate(/mob/living/carbon/human/consistent)
	talking_lizard.set_species(/datum/species/lizard)
	var/hissed_quote = "SSShe isss ssso sssasssy"
	var/unhissed_quote = "She is so sassy"

	RegisterSignal(talking_lizard, COMSIG_MOB_SAY, PROC_REF(handle_speech))

	// lizard's forked tongue causes hissing when speaking common
	talking_lizard.set_active_language(/datum/language/common)
	talking_lizard.say(unhissed_quote)
	TEST_ASSERT(handle_speech_result, "Handle speech signal was not fired")
	TEST_ASSERT_EQUAL(hissed_quote, handle_speech_result[SPEECH_MESSAGE], "Speech modifier test failed: [handle_speech_result[SPEECH_LANGUAGE]] did not equal [hissed_quote] when spoken by a lizard in language [handle_speech_result[SPEECH_LANGUAGE]]")

	handle_speech_result = null

	// lizard's forked tongue does not cause hissing when speaking native draconic
	talking_lizard.set_active_language(/datum/language/draconic)
	talking_lizard.say(unhissed_quote)
	TEST_ASSERT(handle_speech_result, "Handle speech signal was not fired")
	TEST_ASSERT_EQUAL(unhissed_quote, handle_speech_result[SPEECH_MESSAGE], "Speech modifier test failed: [handle_speech_result[SPEECH_LANGUAGE]] did not equal [unhissed_quote] when spoken by a lizard in language [handle_speech_result[SPEECH_LANGUAGE]]")


/// Test to verify COMSIG_MOB_SAY is sent the exact same list as the message args, as they're operated on
/datum/unit_test/say_signal

/datum/unit_test/say_signal/Run()
	var/mob/living/dummy = allocate(/mob/living)

	RegisterSignal(dummy, COMSIG_MOB_SAY, PROC_REF(check_say))
	dummy.say("Make sure the say signal gets the arglist say is past, no copies!")

/datum/unit_test/say_signal/proc/check_say(mob/living/source, list/say_args)
	SIGNAL_HANDLER

	TEST_ASSERT_EQUAL(REF(say_args), source.last_say_args_ref, "Say signal didn't get the argslist of say as a reference. \
		This is required for the signal to function in most places - do not create a new instance of a list when passing it in to the signal.")

// For the above test to track the last use of say's message args.
/mob/living
	var/last_say_args_ref

/// This unit test translates a string from one language to another depending on if the person can understand the language
/datum/unit_test/translate_language
	var/mob/host_mob

/datum/unit_test/translate_language/Run()
	host_mob = allocate(/mob/living/carbon/human/consistent)
	var/surfer_quote = "surfing in the USA"

	host_mob.grant_language(/datum/language/beachbum, SPOKEN_LANGUAGE) // can speak but can't understand
	host_mob.add_blocked_language(subtypesof(/datum/language) - /datum/language/beachbum, source = LANGUAGE_STONER)
	TEST_ASSERT_NOTEQUAL(surfer_quote, host_mob.translate_language(host_mob, /datum/language/beachbum, surfer_quote), "Language test failed. Mob was supposed to understand: [surfer_quote]")

	host_mob.grant_language(/datum/language/beachbum, ALL) // can now understand
	TEST_ASSERT_EQUAL(surfer_quote, host_mob.translate_language(host_mob, /datum/language/beachbum, surfer_quote), "Language test failed. Mob was supposed NOT to understand: [surfer_quote]")

/// Inline language switches respect knowledge and physical restrictions without losing ordinary text.
/datum/unit_test/multilingual_speech/Run()
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent)
	speaker.grant_language(/datum/language/draconic)
	var/list/expected = list(
		list("language" = /datum/language/common, "message" = "Привет"),
		list("language" = /datum/language/draconic, "message" = "тайна"),
		list("language" = /datum/language/common, "message" = "снова"),
	)
	var/list/segments = speaker.parse_language_segments("Привет ,o тайна ,0 снова", /datum/language/common)
	TEST_ASSERT_EQUAL(json_encode(segments), json_encode(expected), "Mixed Cyrillic speech did not preserve its languages and text.")
	TEST_ASSERT_NULL(speaker.parse_language_segments("Слово,o запятая,0 ,? текст", /datum/language/common), "Embedded and unknown markers must remain ordinary text.")
	var/list/empty_segments = speaker.parse_language_segments(",o ,0", /datum/language/common)
	TEST_ASSERT_NOTNULL(empty_segments, "An empty switched message must be distinguished from ordinary text.")
	TEST_ASSERT_EQUAL(length(empty_segments), 0, "Language markers alone must not create spoken fragments.")
	TEST_ASSERT_EQUAL(length(speaker.parse_language_segments("Привет ,o", /datum/language/common)), 1, "A trailing marker must not create an empty fragment.")
	TEST_ASSERT_EQUAL(length(speaker.parse_language_segments(",o тайна ,o ещё", /datum/language/common)), 2, "Repeated switches must preserve both pieces of text.")

	speaker.grant_language(/datum/language/xenocommon)
	TEST_ASSERT(!speaker.can_speak_language(/datum/language/xenocommon), "The human tongue should not permit xenocommon.")
	TEST_ASSERT_NULL(speaker.parse_language_segments("Привет ,4 тайна", /datum/language/common), "Knowing a language must not bypass tongue restrictions.")
	var/list/unavailable_segments = speaker.parse_language_segments("Привет ,4 тайна ,0 снова", /datum/language/common)
	var/list/unavailable_first = unavailable_segments?[1]
	TEST_ASSERT_EQUAL(unavailable_first?["message"], "Привет ,4 тайна", "An unavailable marker must not discard text before a later valid switch.")
	speaker.add_blocked_language(/datum/language/draconic, SPOKEN_LANGUAGE)
	TEST_ASSERT_NULL(speaker.parse_language_segments("Привет ,o тайна", /datum/language/common), "Blocked languages must not be selected by an inline marker.")
	var/mob/living/carbon/human/key_speaker = allocate(/mob/living/carbon/human/consistent)
	key_speaker.grant_language(/datum/language/vox)
	key_speaker.grant_language(/datum/language/voltaic)
	var/datum/language_holder/key_holder = key_speaker.get_language_holder()
	key_holder.omnitongue = TRUE
	var/list/case_segments = key_speaker.parse_language_segments(",V птица ,v искра", /datum/language/common)
	TEST_ASSERT_EQUAL(length(case_segments), 2, "Distinct uppercase and lowercase keys must both create fragments.")
	var/list/upper_segment = case_segments?[1]
	var/list/lower_segment = case_segments?[2]
	TEST_ASSERT_EQUAL(upper_segment?["language"], /datum/language/vox, "Uppercase V must select Vox-pidgin.")
	TEST_ASSERT_EQUAL(lower_segment?["language"], /datum/language/voltaic, "Lowercase v must select Voltaic independently of Vox-pidgin.")

	listener.add_blocked_language(/datum/language/draconic, UNDERSTOOD_LANGUAGE)
	var/list/mods = list(LANGUAGE_MESSAGE_SEGMENTS = segments)
	var/raw_message = "Привет тайна снова"
	var/unknown_piece = listener.translate_language(speaker, /datum/language/draconic, "тайна")
	TEST_ASSERT_EQUAL(listener.translate_language(speaker, /datum/language/common, raw_message, message_mods = mods), "Привет [unknown_piece] снова", "Only the unknown language fragment should be scrambled.")
	var/damaged_message = "Повреждённое сообщение"
	TEST_ASSERT_EQUAL(listener.translate_language(speaker, /datum/language/common, damaged_message, message_mods = mods), stars(damaged_message, 100), "A changed transmission with unknown fragments must conceal all received text instead of restoring the original fragments.")
	var/list/three_segments = segments.Copy()
	three_segments += list(list("language" = /datum/language/voltaic, "message" = "третья"))
	mods[LANGUAGE_MESSAGE_SEGMENTS] = three_segments
	listener.grant_partial_language(/datum/language/voltaic, 100)
	TEST_ASSERT_EQUAL(listener.translate_language(speaker, /datum/language/common, "Привет тайна снова третья", message_mods = mods), "Привет [unknown_piece] снова третья", "Full mutual understanding of one fragment must not reveal a different unknown language.")
	TEST_ASSERT_EQUAL(listener.translate_language(speaker, /datum/language/common, damaged_message, message_mods = mods), stars(damaged_message, 100), "A final mutually understood fragment must not expose an unknown fragment in a damaged transmission.")
	listener.remove_partial_language(/datum/language/voltaic)
	mods[LANGUAGE_MESSAGE_SEGMENTS] = segments
	listener.grant_partial_language(/datum/language/draconic, 100)
	TEST_ASSERT_EQUAL(listener.translate_language(speaker, /datum/language/common, raw_message, message_mods = mods), raw_message, "Mutual understanding must still apply to individual fragments.")
	TEST_ASSERT_EQUAL(listener.translate_language(speaker, /datum/language/common, damaged_message, message_mods = mods), damaged_message, "Full mutual understanding must preserve the received damaged text.")
	listener.remove_partial_language(/datum/language/draconic)
	listener.remove_blocked_language(/datum/language/draconic, UNDERSTOOD_LANGUAGE)
	listener.grant_language(/datum/language/draconic)
	TEST_ASSERT_EQUAL(listener.translate_language(speaker, /datum/language/common, raw_message, message_mods = mods), raw_message, "A listener knowing every language should understand the complete sentence.")
	TEST_ASSERT_EQUAL(listener.translate_language(speaker, /datum/language/common, damaged_message, message_mods = mods), damaged_message, "Knowing every language must not undo transmission damage.")

/// Suppressed fragments must not combine into an audible whitespace-only utterance.
/datum/unit_test/multilingual_speech_suppressed
	/// Physical utterances received by the nearby listener.
	var/heard_count = 0

/// Runs the real succumb body without the native verb's live-client input gate.
/mob/living/carbon/human/consistent/last_words/succumb()
	INVOKE_GAME_VERB(src, src, /mob/living, succumb)

/datum/unit_test/multilingual_speech_suppressed/proc/suppress_speech(datum/source, list/speech_args)
	SIGNAL_HANDLER
	speech_args[SPEECH_MESSAGE] = ""

/datum/unit_test/multilingual_speech_suppressed/proc/on_hear(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	heard_count++

/datum/unit_test/multilingual_speech_suppressed/Run()
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent/last_words)
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent)
	listener.mock_client = allocate(/datum/client_interface)
	speaker.grant_language(/datum/language/draconic)
	speaker.forceMove(run_loc_floor_bottom_left)
	listener.forceMove(get_step(speaker, EAST))
	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))
	speaker.say("Audible", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 1, "The nearby listener must hear speech before it is suppressed.")
	heard_count = 0
	RegisterSignal(speaker, COMSIG_MOB_SAY, PROC_REF(suppress_speech))
	speaker.say("Suppressed", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 0, "Suppressed single-language speech must remain silent.")
	speaker.say("Suppressed ,o also suppressed", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 0, "Suppressing every language fragment must not emit a blank utterance.")
	speaker.set_oxy_loss(speaker.maxHealth - ((speaker.hardcrit_threshold + speaker.dead_threshold) / 2), forced = TRUE)
	TEST_ASSERT_EQUAL(speaker.stat, HARD_CRIT, "The speaker must be in hard critical condition before their last words.")
	speaker.whisper("Suppressed ,o also suppressed", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(speaker.stat, DEAD, "Suppressing mixed last words must still allow the speaker to succumb.")

/// Marionettes must relay speech after earlier signal handlers have modified it.
/datum/unit_test/multilingual_speech_marionette
	/// The mannequin whose relayed speech is observed.
	var/obj/structure/mannequin/puppet
	/// Speech received from the mannequin, excluding the puller's own utterance.
	var/list/relayed_messages = list()

/datum/unit_test/multilingual_speech_marionette/proc/on_hear(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	if(hearing_args[HEARING_SPEAKER] == puppet)
		relayed_messages += hearing_args[HEARING_RAW_MESSAGE]

/datum/unit_test/multilingual_speech_marionette/Run()
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent)
	listener.mock_client = allocate(/datum/client_interface)
	listener.grant_language(/datum/language/draconic)
	speaker.grant_language(/datum/language/draconic)
	speaker.forceMove(run_loc_floor_bottom_left)
	listener.forceMove(get_step(speaker, EAST))
	puppet = allocate(/obj/structure/mannequin, get_step(speaker, NORTH))
	var/obj/item/clothing/mask/animal/pig/mask = allocate(/obj/item/clothing/mask/animal/pig)
	mask.animal_sounds = list("Oink!")
	mask.animal_sounds_alt_probability = 0
	TEST_ASSERT(speaker.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK), "The speech-changing mask must be equipped before pulling.")
	speaker.start_pulling(puppet)
	TEST_ASSERT_EQUAL(speaker.pulling, puppet, "The speaker must pull the mannequin to relay speech.")
	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))
	speaker.say("Secret ,o hidden", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(length(relayed_messages), 1, "Mixed speech must be relayed exactly once.")
	if(trim(relayed_messages[1]) != "Oink!")
		TEST_FAIL("The mannequin must relay the mask's sound, never the original language fragment; received [relayed_messages[1]].")
	mask.clothing_flags |= VOICEBOX_DISABLED
	speaker.set_species(/datum/species/lizard)
	speaker.set_active_language(/datum/language/common)
	relayed_messages.Cut()
	speaker.say("She is so sassy ,o She is so sassy ,0 She is so sassy", ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(length(relayed_messages), 1, "The mannequin must relay all processed language fragments together.")
	TEST_ASSERT_EQUAL(relayed_messages[1], "SSShe isss ssso sssasssy She is so sassy SSShe isss ssso sssasssy", "The mannequin must preserve the tongue's changes to every fragment.")

/// Accepts rendered speech without a network client so synthesis delivery can be observed.
/mob/living/carbon/human/consistent/tts_listener/show_message(msg, type, alt_msg, alt_type, avoid_highlighting = FALSE)
	return TRUE

/// Mixed speech keeps native accents and travels as one message through speech, whispers and radio.
/datum/unit_test/multilingual_speech_modifiers
	/// Number of complete messages received during the current delivery scenario.
	var/heard_count = 0
	/// Last translated message captured at the listener.
	var/heard_message
	/// Voice synthesis must receive the same intelligible and scrambled text as the listener.
	var/tts_message
	/// The listener whose synthesis input is captured.
	var/mob/tts_listener
	/// Restore the legacy subsystem gate even if an assertion ends the test early.
	var/legacy_tts_enabled

/datum/unit_test/multilingual_speech_modifiers/Destroy()
	if(!isnull(legacy_tts_enabled))
		SStts.tts_enabled = legacy_tts_enabled
	return ..()

/datum/unit_test/multilingual_speech_modifiers/proc/on_tts(datum/source, listener, message)
	SIGNAL_HANDLER
	if(listener == tts_listener)
		tts_message = message

/datum/unit_test/multilingual_speech_modifiers/proc/on_hear(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	heard_count++
	heard_message = hearing_args[HEARING_RAW_MESSAGE]

/datum/unit_test/multilingual_speech_modifiers/Run()
	legacy_tts_enabled = SStts.tts_enabled
	SStts.tts_enabled = FALSE
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	speaker.voice = null // Observe synthesis inputs without contacting an external voice service.
	speaker.set_species(/datum/species/lizard)
	speaker.set_active_language(/datum/language/common)
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent/tts_listener)
	listener.grant_language(/datum/language/draconic)
	listener.mock_client = allocate(/datum/client_interface)
	tts_listener = listener
	speaker.forceMove(run_loc_floor_bottom_left)
	listener.forceMove(get_step(run_loc_floor_bottom_left, EAST))
	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))
	// TTS220's signal define is included after the core unit tests.
	RegisterSignal(speaker, "atom_tts_cast", PROC_REF(on_tts))
	var/input = "She is so sassy ,o She is so sassy ,0 She is so sassy"
	var/expected = "SSShe isss ssso sssasssy She is so sassy SSShe isss ssso sssasssy"
	speaker.say(input)
	TEST_ASSERT_EQUAL(heard_count, 1, "Mixed speech must be delivered once.")
	TEST_ASSERT_EQUAL(heard_message, expected, "The tongue must modify common fragments while leaving native draconic intact.")
	TEST_ASSERT_EQUAL(tts_message, expected, "TTS must voice the complete sentence for a listener knowing every language.")
	heard_count = 0
	speaker.whisper(input, ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 1, "Mixed whispers must be delivered once.")
	TEST_ASSERT_EQUAL(heard_message, expected, "Whispering must preserve all language fragments.")
	listener.add_blocked_language(/datum/language/draconic, UNDERSTOOD_LANGUAGE)
	var/unknown_piece = listener.translate_language(speaker, /datum/language/draconic, "She is so sassy")
	var/unknown_expected = "SSShe isss ssso sssasssy [unknown_piece] SSShe isss ssso sssasssy"
	heard_count = 0
	speaker.say(input, ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 1, "A listener missing one language must still receive one sentence.")
	TEST_ASSERT_EQUAL(heard_message, unknown_expected, "Ordinary speech must conceal only the unknown fragment.")
	TEST_ASSERT_EQUAL(tts_message, unknown_expected, "TTS must voice scrambled syllables for unknown fragments instead of revealing their original text.")
	heard_count = 0
	speaker.whisper(input, ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 1, "An unknown-language whisper must still be delivered once.")
	TEST_ASSERT_EQUAL(heard_message, unknown_expected, "Whispering must not expose the unknown fragment.")
	TEST_ASSERT_EQUAL(tts_message, unknown_expected, "Whispered TTS must voice the listener's scrambled language fragments.")
	listener.forceMove(locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	heard_count = 0
	speaker.whisper(input, ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 1, "A listener in eavesdrop range must receive one obscured whisper.")
	TEST_ASSERT(!findtext(heard_message, "She is so sassy"), "Eavesdropping must not restore the unknown language's original text.")
	TEST_ASSERT_EQUAL(tts_message, heard_message, "Eavesdropped TTS must not undo the whisper's distance masking.")

	listener.forceMove(locate(run_loc_floor_bottom_left.x + 10, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	var/obj/item/radio/transmitter = allocate(/obj/item/radio)
	var/obj/item/radio/receiver = allocate(/obj/item/radio)
	transmitter.forceMove(speaker.loc)
	receiver.forceMove(listener.loc)
	transmitter.set_frequency(FREQ_CENTCOM)
	transmitter.special_channels = RADIO_SPECIAL_CENTCOM
	transmitter.set_broadcasting(TRUE)
	receiver.set_frequency(FREQ_CENTCOM)
	receiver.special_channels = RADIO_SPECIAL_CENTCOM
	heard_count = 0
	speaker.say(input, ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 1, "A distant listener must receive one mixed radio message.")
	TEST_ASSERT_EQUAL(heard_message, unknown_expected, "Radio must conceal only the unknown fragment.")
	listener.remove_blocked_language(/datum/language/draconic, UNDERSTOOD_LANGUAGE)
	heard_count = 0
	speaker.say(input, ignore_spam = TRUE)
	TEST_ASSERT_EQUAL(heard_count, 1, "A listener knowing every language must receive one mixed radio message.")
	TEST_ASSERT_EQUAL(heard_message, expected, "Radio must retain the language fragments and native accent processing.")

/// This runs some simple speech tests on a speaker and listener and determines if a person can hear whispering or speaking as they are moved a distance away
/datum/unit_test/speech
	var/mob/living/carbon/human/speaker
	var/mob/living/carbon/human/listener
	var/list/handle_speech_result = null
	var/list/handle_hearing_result = null

	var/obj/item/radio/speaker_radio
	var/obj/item/radio/listener_radio
	var/speaker_radio_heard_message = FALSE
	var/listener_radio_received_message = FALSE

/datum/unit_test/speech/proc/handle_speech(datum/source, list/speech_args)
	SIGNAL_HANDLER

	TEST_ASSERT(speech_args[SPEECH_MESSAGE], "Handle speech signal does not have a message arg")
	TEST_ASSERT(speech_args[SPEECH_SPANS], "Handle speech signal does not have spans arg")
	TEST_ASSERT(speech_args[SPEECH_LANGUAGE], "Handle speech signal does not have a language arg")
	TEST_ASSERT(speech_args[SPEECH_RANGE], "Handle speech signal does not have a range arg")

	// saving speech_args directly via handle_speech_result = speech_args won't work since the arg list
	// is a temporary variable that gets garbage collected after it's done being used by procs
	// therefore we need to create a new list and transfer the args
	handle_speech_result = list()
	handle_speech_result += speech_args

/datum/unit_test/speech/proc/handle_hearing(datum/source, list/hearing_args)
	SIGNAL_HANDLER

	TEST_ASSERT(hearing_args[HEARING_SPEAKER], "Handle hearing signal does not have a speaker arg")
	TEST_ASSERT(hearing_args[HEARING_LANGUAGE], "Handle hearing signal does not have a language arg")
	TEST_ASSERT(hearing_args[HEARING_RAW_MESSAGE], "Handle hearing signal does not have a raw message arg")
	// TODO radio unit tests
	//TEST_ASSERT(hearing_args[HEARING_RADIO_FREQ], "Handle hearing signal does not have a radio freq arg")
	TEST_ASSERT(hearing_args[HEARING_SPANS], "Handle hearing signal does not have a spans arg")
	TEST_ASSERT(hearing_args[HEARING_MESSAGE_MODE], "Handle hearing signal does not have a message mode arg")

	// saving hearing_args directly via handle_hearing_result = hearing_args won't work since the arg list
	// is a temporary variable that gets garbage collected after it's done being used by procs
	// therefore we need to create a new list and transfer the args
	handle_hearing_result = list()
	handle_hearing_result += hearing_args

/datum/unit_test/speech/proc/handle_radio_hearing(datum/source, mob/living/user, message, channel)
	SIGNAL_HANDLER

	speaker_radio_heard_message = TRUE

/datum/unit_test/speech/proc/handle_radio_speech(datum/source, list/data)
	SIGNAL_HANDLER

	listener_radio_received_message = TRUE

/datum/unit_test/speech/Run()
	speaker = allocate(/mob/living/carbon/human/consistent)
	// Name changes to make understanding breakpoints easier
	speaker.name = "SPEAKER"
	listener = allocate(/mob/living/carbon/human/consistent)
	listener.name = "LISTENER"
	speaker_radio = allocate(/obj/item/radio)
	speaker_radio.name = "SPEAKER RADIO"
	listener_radio = allocate(/obj/item/radio)
	listener_radio.name = "LISTENER RADIO"
	// Hear() requires a client otherwise it will early return
	var/datum/client_interface/mock_client = new()
	listener.mock_client = mock_client

	RegisterSignal(speaker, COMSIG_MOB_SAY, PROC_REF(handle_speech))
	RegisterSignal(speaker_radio, COMSIG_RADIO_NEW_MESSAGE, PROC_REF(handle_radio_hearing))

	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(handle_hearing))
	RegisterSignal(listener_radio, COMSIG_RADIO_RECEIVE_MESSAGE, PROC_REF(handle_radio_speech))

	// speaking and whispering should be hearable
	conversation(distance = 1)
	// speaking should be hearable but not whispering
	conversation(distance = 5)
	// neither speaking or whispering should be hearable
	conversation(distance = 10)

	// Radio test
	radio_test()

	// Language test
	speaker.grant_language(/datum/language/beachbum)
	speaker.set_active_language(/datum/language/beachbum)
	listener.add_blocked_language(/datum/language/beachbum)
	// speaking and whispering should be hearable
	conversation(distance = 1)
	// speaking should be hearable but not whispering
	conversation(distance = 5)
	// neither speaking or whispering should be hearable
	conversation(distance = 10)

#define NORMAL_HEARING_RANGE 7
#define WHISPER_HEARING_RANGE 1

/datum/unit_test/speech/proc/conversation(distance = 0)
	speaker.forceMove(run_loc_floor_bottom_left)
	listener.forceMove(locate((run_loc_floor_bottom_left.x + distance), run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))

	var/pangram_quote = "The quick brown fox jumps over the lazy dog"

	// speaking
	speaker.say(pangram_quote)
	TEST_ASSERT(handle_speech_result, "Handle speech signal was not fired")
	TEST_ASSERT_EQUAL(islist(handle_hearing_result), distance <= NORMAL_HEARING_RANGE, "Handle hearing signal was not fired")

	if(handle_hearing_result)
		if(listener.has_language(handle_speech_result[SPEECH_LANGUAGE]))
			TEST_ASSERT_EQUAL(pangram_quote, handle_hearing_result[HEARING_RAW_MESSAGE], "Language test failed. Mob was supposed to understand: [pangram_quote] using language [handle_speech_result[SPEECH_LANGUAGE]]")
		else
			TEST_ASSERT_NOTEQUAL(pangram_quote, handle_hearing_result[HEARING_RAW_MESSAGE], "Language test failed. Mob was NOT supposed to understand: [pangram_quote] using language [handle_speech_result[SPEECH_LANGUAGE]]")

	handle_speech_result = null
	handle_hearing_result = null

	// whispering
	speaker.whisper(pangram_quote)
	TEST_ASSERT(handle_speech_result, "Handle speech signal was not fired")
	TEST_ASSERT_EQUAL(islist(handle_hearing_result), distance <= WHISPER_HEARING_RANGE, "Handle hearing signal was not fired")

	handle_speech_result = null
	handle_hearing_result = null

/datum/unit_test/speech/proc/radio_test()
	speaker_radio_heard_message = FALSE
	listener_radio_received_message = FALSE

	speaker.forceMove(run_loc_floor_bottom_left)
	listener.forceMove(locate((run_loc_floor_bottom_left.x + 10), run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))

	speaker_radio.forceMove(run_loc_floor_bottom_left)
	speaker_radio.set_broadcasting(TRUE)
	listener_radio.forceMove(locate((run_loc_floor_bottom_left.x + 10), run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	// Normally speaking, if there isn't a functional telecomms array on the same z-level, then handheld radios
	// have a short delay before sending the message. We use the centcom frequency to get around this.
	speaker_radio.set_frequency(FREQ_CENTCOM)
	speaker_radio.special_channels = RADIO_SPECIAL_CENTCOM
	listener_radio.set_frequency(FREQ_CENTCOM)
	listener_radio.special_channels = RADIO_SPECIAL_CENTCOM

	var/pangram_quote = "The quick brown fox jumps over the lazy dog"

	speaker.say(pangram_quote)
	TEST_ASSERT(handle_speech_result, "Handle speech signal was not fired (radio test)")
	TEST_ASSERT(speaker_radio_heard_message, "Speaker's radio did not hear them speak (radio test)")
	TEST_ASSERT_EQUAL(speaker_radio.get_frequency(), listener_radio.get_frequency(), "Radio frequencies were not equal (radio test)")
	TEST_ASSERT(listener_radio_received_message, "Listener's radio did not receive the broadcast (radio test)")
	TEST_ASSERT(islist(handle_hearing_result), "Listener failed to hear radio message (radio test)")

	handle_speech_result = null
	handle_hearing_result = null
	speaker_radio_heard_message = FALSE
	listener_radio_received_message = FALSE

	speaker_radio.set_frequency(FREQ_CTF_RED)
	speaker.say(pangram_quote)
	TEST_ASSERT(handle_speech_result, "Handle speech signal was not fired (radio test)")
	TEST_ASSERT_NULL(handle_hearing_result, "Listener erroneously heard radio message (radio test)")
	TEST_ASSERT_NOTEQUAL(speaker_radio.get_frequency(), listener_radio.get_frequency(), "Radio frequencies were erroneously equal (radio test)")

	handle_speech_result = null
	handle_hearing_result = null
	speaker_radio_heard_message = FALSE
	listener_radio_received_message = FALSE
	speaker_radio.set_broadcasting(FALSE)

#undef NORMAL_HEARING_RANGE
#undef WHISPER_HEARING_RANGE

/datum/unit_test/emphasis_characters
	abstract_type = /datum/unit_test/emphasis_characters
	var/base_input
	var/expected_output

/datum/unit_test/emphasis_characters/Run()
	TEST_ASSERT_EQUAL(replacetext(apply_message_emphasis(base_input), "&#8203;", ""), expected_output, "")

/datum/unit_test/emphasis_characters/basic
	base_input = @"Blah Blah Blah"
	expected_output = @"Blah Blah Blah"

/datum/unit_test/emphasis_characters/complex
	base_input = @"Blah + Blah = Blah :)"
	expected_output = @"Blah + Blah = Blah :)"

/datum/unit_test/emphasis_characters/italic
	base_input = @"|Blah| Blah Blah"
	expected_output = @"<i>Blah</i> Blah Blah"

/datum/unit_test/emphasis_characters/bold
	base_input = @"+Blah+ Blah Blah"
	expected_output = @"<b>Blah</b> Blah Blah"

/datum/unit_test/emphasis_characters/small
	base_input = @"^Blah^ Blah Blah"
	expected_output = @"<small>Blah</small> Blah Blah"

/datum/unit_test/emphasis_characters/multiple
	base_input = @"|Blah| Blah +Blah+"
	expected_output = @"<i>Blah</i> Blah <b>Blah</b>"

/datum/unit_test/emphasis_characters/escaped
	base_input = @"\|Blah\| \+Blah\+ Blah"
	expected_output = @"|Blah| +Blah+ Blah"
