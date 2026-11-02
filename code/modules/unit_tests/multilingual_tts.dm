/// An inert fixture must not register itself as the live SStts singleton.
/datum/controller/subsystem/tts/multilingual_test
	name = "Language TTS unit fixture"
	ss_flags = SS_NO_INIT | SS_NO_FIRE

/datum/controller/subsystem/tts/multilingual_test/New()
	return

/// Prepared requests exercise legacy language routing and queue ordering without contacting a TTS service.
/datum/unit_test/multilingual_tts/Run()
	var/datum/controller/subsystem/tts/live_tts = SStts
	var/datum/controller/subsystem/tts/tts = allocate(/datum/controller/subsystem/tts/multilingual_test)
	TEST_ASSERT_EQUAL(SStts, live_tts, "The isolated fixture must not replace the live TTS subsystem.")
	tts.tts_enabled = TRUE
	tts.max_concurrent_requests = 0
	tts.available_speakers = list("unit-test-voice")
	tts.queued_http_messages = allocate(/datum/heap, GLOBAL_PROC_REF(cmp_word_length_asc))
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/known = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/unknown = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/also_unknown = allocate(/mob/living/carbon/human/consistent)
	known.grant_language(/datum/language/draconic)
	var/list/mods = list(LANGUAGE_MESSAGE_SEGMENTS = list(
		list("language" = /datum/language/common, "message" = "Привет"),
		list("language" = /datum/language/draconic, "message" = "тайна"),
		list("language" = /datum/language/common, "message" = "снова"),
	))
	var/raw_message = "Привет тайна снова"
	var/datum/tts_request/utterance = tts.queue_tts_message(speaker, raw_message, /datum/language/common, "unit-test-voice", listeners = list(known, unknown, also_unknown), identifier = "multilingual-tts-test", message_mods = mods)
	TEST_ASSERT_NOTNULL(utterance, "Cyrillic-only speech must be accepted for synthesis.")
	TEST_ASSERT(utterance.translated, "The legacy voice must receive already translated listener groups instead of automatically selecting blips.")
	TEST_ASSERT_EQUAL(length(tts.queued_tts_messages[WEAKREF(speaker)]), 1, "Listener variants must share one utterance queue entry.")
	TEST_ASSERT_EQUAL(length(utterance.variants), 1, "Listeners with identical understanding must reuse an audio request.")
	TEST_ASSERT(WEAKREF(known) in utterance.listeners, "A listener knowing all languages should receive the original voice request.")
	TEST_ASSERT(!(WEAKREF(unknown) in utterance.listeners), "An unknown language must never route to plaintext audio.")
	var/datum/tts_request/unknown_voice = tts.get_tts_variant(utterance, unknown)
	TEST_ASSERT_NOTNULL(unknown_voice, "Unknown Cyrillic syllables must have a voiced synthesis request.")
	TEST_ASSERT_NOTEQUAL(unknown_voice, utterance, "The original audio must not be used for an unknown fragment.")
	TEST_ASSERT(unknown_voice.translated, "Unknown syllables should be spoken, not automatically replaced with blips.")
	TEST_ASSERT(WEAKREF(also_unknown) in unknown_voice.listeners, "Both listeners should share the same translated voice.")
	var/expected = unknown.translate_language(speaker, /datum/language/common, raw_message, message_mods = mods)
	var/list/unknown_body = json_decode(unknown_voice.request.body)
	TEST_ASSERT_EQUAL(unknown_body["text"], tts_speech_filter(expected), "The HTTP request must contain translated syllables, never the unknown plaintext.")
	TEST_ASSERT(!unknown_voice.request.in_progress, "Preparing routing tests must not start an external HTTP request.")
	TEST_ASSERT_EQUAL(tts.get_tts_variant(utterance, also_unknown), unknown_voice, "Equivalent listeners must reuse the same pending audio.")

	var/mob/living/carbon/human/late_listener = allocate(/mob/living/carbon/human/consistent)
	late_listener.grant_language(/datum/language/draconic)
	late_listener.add_blocked_language(/datum/language/common, UNDERSTOOD_LANGUAGE)
	var/list/radio_context = list("message" = raw_message, "language" = /datum/language/common, "mods" = mods)
	var/datum/tts_request/late_voice = tts.get_tts_variant(utterance, late_listener, radio_context)
	TEST_ASSERT_NOTNULL(late_voice, "A late radio listener must get an independently translated voice.")
	TEST_ASSERT_NOTEQUAL(late_voice, utterance, "A late radio listener must not get the original audio as a fallback.")
	TEST_ASSERT_EQUAL(length(late_voice.listeners), 0, "Creating a radio variant must not add that listener to local speech.")
	TEST_ASSERT_EQUAL(length(tts.queued_tts_messages[WEAKREF(speaker)]), 1, "Late radio variants must not create additional utterance slots.")
	var/list/damaged_context = list("message" = "********", "language" = /datum/language/common, "mods" = mods)
	TEST_ASSERT_NULL(tts.get_tts_variant(utterance, unknown, damaged_context), "Fully obscured radio text must stay silent, never fall back to original audio.")

	utterance.audio_file = "prepared-parent"
	utterance.audio_length = 10
	unknown_voice.audio_file = "prepared-unknown"
	unknown_voice.audio_length = 20
	TEST_ASSERT_NULL(utterance.get_playback_length(), "The utterance must wait for all pending variants before playing.")
	late_voice.audio_file = "prepared-radio"
	late_voice.audio_length = 30
	TEST_ASSERT_EQUAL(utterance.get_playback_length(), 30, "The following utterance must wait for the longest variant, not a sum of variants.")
	late_voice.timed_out = TRUE
	TEST_ASSERT_EQUAL(utterance.get_playback_length(), 20, "A failed variant must not block the other listeners forever.")
	var/datum/tts_request/next = tts.queue_tts_message(speaker, "Next sentence", /datum/language/common, "unit-test-voice", listeners = list(known), identifier = "multilingual-tts-next", message_mods = list())
	var/list/queue = tts.queued_tts_messages[WEAKREF(speaker)]
	TEST_ASSERT_EQUAL(length(queue), 2, "Only complete utterances should occupy the speaker's queue.")
	TEST_ASSERT_EQUAL(queue[1], utterance, "The first utterance must keep its place.")
	TEST_ASSERT_EQUAL(queue[2], next, "The next utterance must follow all variants of the first.")
	var/datum/tts_request/preview = tts.queue_tts_message(known, "Blips preview", speaker = "unit-test-voice", local = TRUE, force_blips = TRUE, identifier = "multilingual-tts-preview")
	TEST_ASSERT(preview.force_blips && !preview.translated, "An explicit blips preview must retain the player's requested mode.")

/// Cyrillic words and alien syllables remain pronounceable while unsafe punctuation is removed.
/datum/unit_test/multilingual_tts_filters/Run()
	var/message = "Привет, Ёжик! Hello 123"
	TEST_ASSERT_EQUAL(tts_speech_filter(message), message, "Cyrillic speech must survive the synthesis filter.")
	TEST_ASSERT_EQUAL(tts_gibberish_speech_filter(message), message, "Cyrillic gibberish must survive the radio filter.")
	var/filtered = tts_speech_filter("Привет;|$`<>мир")
	TEST_ASSERT(findtext(filtered, "Привет") && findtext(filtered, "мир"), "Safe words should survive filtering.")
	for(var/unsafe in list(";", "|", "$", "`", "<", ">"))
		TEST_ASSERT(!findtext(filtered, unsafe), "Unsafe punctuation [unsafe] must still be removed.")
