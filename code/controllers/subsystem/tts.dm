#define TTS_REQUEST_REF "ref"
#define TTS_REQUEST_EXPIRE "expiry_time"

SUBSYSTEM_DEF(tts)
	name = "Text To Speech"
	wait = 0.05 SECONDS
	priority = FIRE_PRIORITY_TTS
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	/// Queued HTTP requests that have yet to be sent. TTS requests are handled as lists rather than datums.
	var/datum/heap/queued_http_messages

	/// An associative list of mobs mapped to a list of their own /datum/tts_request_target
	var/list/queued_tts_messages = list()

	/// TTS audio files that are being processed on when to be played.
	var/list/current_processing_tts_messages = list()

	/// HTTP requests currently in progress but not being processed yet
	var/list/in_process_http_messages = list()

	/// HTTP requests that are being processed to see if they've been finished
	var/list/current_processing_http_messages = list()

	/// TTS requests for radio TTS audio playback. Cleared when it's been in here for 30 seconds. list("identifier" = list("ref" = [ref], "expiry_time" = world.time))
	var/list/completed_tts_messages = list()

	/// TTS requests for radios who heard a TTS message. list("identifier" = list("radio" = [ref], "hearers" = list([hearer_ref], ...)))
	var/list/list/queued_radio_messages = list()

	/// List of radio TTS messages with compression, used for fixing radio TTS during ionosphere storms to conceal text.
	var/list/list/queued_radio_messages_compression = list()
	/// Received radio text and language modifiers, before any per-listener translation.
	var/list/queued_radio_message_context = list()

	/// A list of available speakers, which are string identifiers of the TTS voices that can be used to generate TTS messages.
	var/list/available_speakers = list()

	/// Whether TTS is enabled or not
	var/tts_enabled = FALSE
	/// Whether the TTS engine supports pitch adjustment or not.
	var/pitch_enabled = FALSE

	/// TTS messages won't play if requests took longer than this duration of time.
	var/message_timeout = 7 SECONDS

	/// The max concurrent http requests that can be made at one time. Used to prevent 1 server from overloading the tts server
	var/max_concurrent_requests = 4

	/// Used to calculate the average time it takes for a tts message to be received from the http server
	/// For tts messages which time out, it won't keep tracking the tts message and will just assume that the message took
	/// 7 seconds (or whatever the value of message_timeout is) to receive back a response.
	var/average_tts_messages_time = 0
	/// Used as the Tram voice, to keep narration the same across tram devices.
	var/tram_voice = null
	/// Used as the Computer voice, to keep narration the same across computers.
	var/computer_voice = null

/datum/controller/subsystem/tts/vv_edit_var(var_name, var_value)
	// tts being enabled depends on whether it actually exists
	if(NAMEOF(src, tts_enabled) == var_name)
		return FALSE
	return ..()

/datum/controller/subsystem/tts/stat_entry(msg)
	msg = "\n  Active:[length(in_process_http_messages)]|Standby:[length(queued_http_messages?.L)]|Avg:[average_tts_messages_time]"
	return ..()

/proc/cmp_word_length_asc(datum/tts_request/a, datum/tts_request/b)
	return length(b.message) - length(a.message)

/// Establishes (or re-establishes) a connection to the TTS server and updates the list of available speakers.
/// This is blocking, so be careful when calling.
/datum/controller/subsystem/tts/proc/establish_connection_to_tts()
	var/datum/http_request/request = new()
	var/list/headers = list()
	headers["Authorization"] = CONFIG_GET(string/tts_http_token)
	request.prepare(RUSTG_HTTP_METHOD_GET, "[CONFIG_GET(string/tts_http_url)]/tts-voices", "", headers, timeout_seconds = CONFIG_GET(number/tts_http_timeout_seconds))
	request.begin_async()
	UNTIL(request.is_complete())
	var/datum/http_response/response = request.into_response()
	if(response.errored || response.status_code != 200)
		stack_trace(response.error)
		return FALSE
	available_speakers = json_decode(response.body)
	tts_enabled = TRUE
	if(CONFIG_GET(str_list/tts_voice_blacklist))
		var/list/blacklisted_voices = CONFIG_GET(str_list/tts_voice_blacklist)
		log_config("Processing the TTS voice blacklist.")
		for(var/voice in blacklisted_voices)
			if(available_speakers.Find(voice))
				log_config("Removed speaker [voice] from the TTS voice pool per config.")
				available_speakers.Remove(voice)
	if(CONFIG_GET(string/tts_tram_announcer_override))
		tram_voice = CONFIG_GET(string/tts_tram_announcer_override)
	else
		tram_voice = pick(available_speakers)
	if(CONFIG_GET(string/tts_computer_voice_override))
		computer_voice = CONFIG_GET(string/tts_computer_voice_override)
	else
		computer_voice = pick(available_speakers)
	var/datum/http_request/request_pitch = new()
	var/list/headers_pitch = list()
	headers_pitch["Authorization"] = CONFIG_GET(string/tts_http_token)
	request_pitch.prepare(RUSTG_HTTP_METHOD_GET, "[CONFIG_GET(string/tts_http_url)]/pitch-available", "", headers_pitch, timeout_seconds = CONFIG_GET(number/tts_http_timeout_seconds))
	request_pitch.begin_async()
	UNTIL(request_pitch.is_complete())
	pitch_enabled = TRUE
	var/datum/http_response/response_pitch = request_pitch.into_response()
	if(response_pitch.errored || response_pitch.status_code != 200)
		if(response_pitch.errored)
			stack_trace(response.error)
		pitch_enabled = FALSE
	rustg_file_write(json_encode(available_speakers), "data/cached_tts_voices.json")
	rustg_file_write("rustg HTTP requests can't write to folders that don't exist, so we need to make it exist.", "tmp/tts/init.txt")
	return TRUE

/datum/controller/subsystem/tts/Initialize()
	if(!CONFIG_GET(string/tts_http_url))
		return SS_INIT_NO_NEED

	queued_http_messages = new /datum/heap(GLOBAL_PROC_REF(cmp_word_length_asc))
	max_concurrent_requests = CONFIG_GET(number/tts_max_concurrent_requests)
	if(!establish_connection_to_tts())
		return SS_INIT_FAILURE
	return SS_INIT_SUCCESS

/datum/controller/subsystem/tts/proc/play_tts(datum/weakref/target, list/listeners, sound/audio, sound/audio_blips, datum/language/language, range = 7, volume_offset = 0, ignore_observers = FALSE, source_speaker = null, audio_length = 10 SECONDS, audio_length_blips = 10 SECONDS, volume_preference = /datum/preference/numeric/volume/sound_tts_volume, volume_signal = COMSIG_MOB_TTS_VOLUME_PREFERENCE_APPLIED, translated = FALSE)
	var/atom/actual_target = target?.resolve()
	var/turf/turf_source
	if(actual_target)
		turf_source = get_turf(actual_target)
	if(!turf_source && actual_target) // if there's a target, we better have a turf
		return

	var/channel = SSsounds.random_available_channel()
	var/list/final_listeners = listeners
	if(!ignore_observers && actual_target)
		final_listeners += SSmobs.dead_players_by_zlevel[turf_source.z] //observers always hear through walls
	var/list/blips_hearers = list()
	var/list/voice_hearers = list()
	for(var/hearer in final_listeners)
		if(isnull(hearer))
			continue
		var/atom/movable/hearer_atom
		if(isweakref(hearer))
			var/datum/weakref/weakref = hearer
			hearer_atom = weakref?.resolve()
		else
			hearer_atom = hearer
		if(!hearer_atom || QDELING(hearer_atom))
			continue
		if(!ismob(hearer_atom))
			continue
		var/mob/listening_mob = hearer_atom.get_listening_mob()
		/// volume modifier for TTS as set by the player in preferences.
		var/volume_modifier = listening_mob.client?.prefs.read_preference(volume_preference)/100
		var/tts_pref = listening_mob.client?.prefs.read_preference(/datum/preference/choiced/sound_tts)
		var/hear_self_pref = listening_mob.client?.prefs.read_preference(/datum/preference/toggle/sound_tts_hear_self_radio)
		if(volume_modifier == 0 || (tts_pref == TTS_SOUND_OFF))
			continue
		if(listening_mob == source_speaker && !hear_self_pref)
			continue // don't hear your own radio tts if you got it turned off

		var/sound_volume = ((listening_mob == actual_target)? 60 : 85) + volume_offset
		sound_volume = sound_volume*volume_modifier
		var/datum/language_holder/holder = listening_mob.get_language_holder()
		var/sound/audio_to_use = (tts_pref == TTS_SOUND_BLIPS) ? audio_blips : audio
		if(!translated && !holder.has_language(language))
			if (tts_pref == TTS_SOUND_OFF)
				continue
			else
				audio_to_use = audio_blips
		if(actual_target && get_dist(listening_mob, turf_source) <= range)
			if(tts_pref == TTS_SOUND_BLIPS || (!translated && !holder.has_language(language)))
				blips_hearers += listening_mob
			else
				voice_hearers += listening_mob
			listening_mob.playsound_local(
				turf_source,
				vol = sound_volume,
				falloff_exponent = SOUND_FALLOFF_EXPONENT,
				channel = channel,
				pressure_affected = TRUE,
				sound_to_use = audio_to_use,
				max_distance = SOUND_RANGE,
				falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE,
				distance_multiplier = 1,
				use_reverb = TRUE
			)
		else if(!actual_target)
			listening_mob.playsound_local(
				null, //play it locally
				vol = sound_volume,
				falloff_exponent = SOUND_FALLOFF_EXPONENT,
				channel = channel,
				pressure_affected = FALSE,
				sound_to_use = audio_to_use,
				max_distance = SOUND_RANGE,
				falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE,
				distance_multiplier = 1,
				use_reverb = TRUE
			)
	if(actual_target)
		new /datum/threed_sound(
			new_parent = actual_target,
			new_sound = audio,
			current_listeners = voice_hearers,
			can_add_new_listeners = FALSE,
			volume = 85 + volume_offset,
			sound_range = SOUND_RANGE,
			sound_length = audio_length,
			channel = channel,
			preference_volume = volume_preference,
			preference_signal = volume_signal
		)
		new /datum/threed_sound(
			new_parent = actual_target,
			new_sound = audio_blips,
			current_listeners = blips_hearers,
			can_add_new_listeners = FALSE,
			volume = 85 + volume_offset,
			sound_range = SOUND_RANGE,
			sound_length = audio_length_blips,
			channel = channel,
			preference_volume = volume_preference,
			preference_signal = volume_signal
		)


// Need to wait for all HTTP requests to complete here because of a rustg crash bug that causes crashes when dd restarts whilst HTTP requests are ongoing.
/datum/controller/subsystem/tts/Shutdown()
	tts_enabled = FALSE
	for(var/datum/tts_request/data in in_process_http_messages)
		var/datum/http_request/request = data.request
		var/datum/http_request/request_blips = data.request_blips
		var/datum/http_request/request_radio = data.request_radio
		var/datum/http_request/request_blips_radio = data.request_blips_radio
		UNTIL(request.is_complete() && request_blips.is_complete() && request_radio.is_complete() && request_blips_radio.is_complete())

#define SHIFT_DATA_ARRAY(tts_message_queue, target, data) \
	popleft(##data); \
	if(length(##data) == 0) { \
		##tts_message_queue -= ##target; \
	};

#define TTS_ARBRITRARY_DELAY "arbritrary delay"

/datum/controller/subsystem/tts/fire(resumed)
	if(!tts_enabled)
		ss_flags |= SS_NO_FIRE
		return

	if(!resumed)
		while(length(in_process_http_messages) < max_concurrent_requests && length(queued_http_messages.L) > 0)
			var/datum/tts_request/entry = queued_http_messages.pop()
			var/timeout = entry.start_time + message_timeout
			if(timeout < world.time)
				entry.timed_out = TRUE
				continue
			entry.start_requests()
			in_process_http_messages += entry
		current_processing_http_messages = in_process_http_messages.Copy()
		current_processing_tts_messages = queued_tts_messages.Copy()

	// For speed
	var/list/processing_messages = current_processing_http_messages
	while(processing_messages.len)
		var/datum/tts_request/current_request = processing_messages[processing_messages.len]
		processing_messages.len--
		if(!current_request.requests_completed())
			continue

		in_process_http_messages -= current_request
		average_tts_messages_time = MC_AVERAGE(average_tts_messages_time, world.time - current_request.start_time)
		var/identifier = current_request.identifier
		var/datum/http_response/normal_response = current_request.request.into_response()
		var/datum/http_response/blips_response = current_request.request_blips.into_response()
		var/datum/http_response/radio_response = current_request.request_radio.into_response()
		var/datum/http_response/radio_blips_response = current_request.request_blips_radio.into_response()
		var/datum/http_response/radio_gibberish_response = current_request.request_radio_gibberish.into_response()
		if(current_request.requests_errored())
			queued_radio_messages -= identifier
			queued_radio_messages_compression -= identifier
			queued_radio_message_context -= identifier
			current_request.timed_out = TRUE
			log_tts("TTS HTTP request errored | Normal: [normal_response.error] | Blips: [blips_response.error] | Radio: [radio_response.error] | Radio Blips: [radio_blips_response.error] | Radio Gibberish [radio_gibberish_response.error]", list(
				"normal" = normal_response,
				"blips" = blips_response,
				"radio" = radio_response,
				"radio_blips" = radio_blips_response,
				"radio_gibberish" = radio_gibberish_response
			))
			continue
		if(length(normal_response.headers) && normal_response.headers.Find("audio-length"))
			current_request.audio_length = text2num(normal_response.headers["audio-length"]) * 10 || 0
		if(length(blips_response.headers) && blips_response.headers.Find("audio-length"))
			current_request.audio_length_blips = text2num(blips_response.headers["audio-length"]) * 10 || 0
		if(length(radio_response.headers) && radio_response.headers.Find("audio-length"))
			current_request.audio_length_radio = text2num(radio_response.headers["audio-length"]) * 10 || 0
		if(length(radio_blips_response.headers) && radio_blips_response.headers.Find("audio-length"))
			current_request.audio_length_blips_radio = text2num(radio_blips_response.headers["audio-length"]) * 10 || 0
		if(length(radio_gibberish_response.headers) && radio_gibberish_response.headers.Find("audio-length"))
			current_request.audio_length_radio_gibberish = text2num(radio_gibberish_response.headers["audio-length"]) * 10
		current_request.audio_file = "tmp/tts/[identifier].ogg"
		current_request.audio_file_blips = "tmp/tts/[identifier]_blips.ogg" // We aren't as concerned about the audio length for blips as we are with actual speech
		current_request.audio_file_radio = "tmp/tts/[identifier]_radio.ogg"
		current_request.audio_file_blips_radio = "tmp/tts/[identifier]_blips_radio.ogg"
		current_request.audio_file_radio_gibberish = "tmp/tts/[identifier]_radio_gibberish.ogg"
		// Don't need the request anymore so we can deallocate it
		current_request.request = null
		current_request.request_blips = null
		current_request.request_radio = null
		current_request.request_blips_radio = null
		current_request.request_radio_gibberish = null
		if(MC_TICK_CHECK)
			return

	var/list/processing_tts_messages = current_processing_tts_messages
	while(processing_tts_messages.len)
		if(MC_TICK_CHECK)
			return

		var/datum/tts_target = processing_tts_messages[processing_tts_messages.len]
		var/list/data = processing_tts_messages[tts_target]
		processing_tts_messages.len--
		if(QDELETED(tts_target))
			queued_tts_messages -= tts_target
			continue

		var/datum/tts_request/current_target = data[1]
		// This determines when we start the timer to time out.
		// This is so that the TTS message doesn't get timed out if it's waiting
		// on another TTS message to finish playing their audio.

		// For example, if a TTS message plays for more than 7 seconds, which is our current timeout limit,
		// then the next TTS message would be unable to play.
		// In the normal case, we just set timeout to start_time as it means we aren't waiting on
		// a TTS message to finish playing
		var/timeout_start = current_target.when_to_play || current_target.start_time

		var/timeout = timeout_start + message_timeout
		// Here, we check if the request has timed out or not.
		// If current_target.timed_out is set to TRUE, it means the request failed in some way
		// and there is no TTS audio file to play.
		if(timeout < world.time || current_target.timed_out)
			queued_radio_messages -= current_target.identifier
			queued_radio_messages_compression -= current_target.identifier
			queued_radio_message_context -= current_target.identifier
			SHIFT_DATA_ARRAY(queued_tts_messages, tts_target, data)
			continue

		if(current_target.audio_file)
			if(current_target.audio_file == TTS_ARBRITRARY_DELAY)
				if(current_target.when_to_play < world.time)
					SHIFT_DATA_ARRAY(queued_tts_messages, tts_target, data)
				continue
			var/sound/audio_file
			var/sound/audio_file_blips
			if(current_target.local)
				if(current_target.use_blips || current_target.force_blips)
					audio_file_blips = new(current_target.audio_file_blips)
					SEND_SOUND(current_target.target, audio_file_blips)
				else
					audio_file = new(current_target.audio_file)
					SEND_SOUND(current_target.target, audio_file)
				SHIFT_DATA_ARRAY(queued_tts_messages, tts_target, data)

			else if(current_target.when_to_play < world.time)
				var/playback_length = current_target.get_playback_length()
				if(isnull(playback_length))
					continue
				play_tts_request(current_target, tts_target, current_target.listeners)
				for(var/text in current_target.variants)
					var/datum/tts_request/variant = current_target.variants[text]
					if(variant && !variant.timed_out)
						play_tts_request(variant, tts_target, variant.listeners)
				completed_tts_messages[current_target.identifier] = list(
					TTS_REQUEST_REF = current_target,
					TTS_REQUEST_EXPIRE = world.time + 30 SECONDS,
				)

				if(length(data) != 1)
					var/datum/tts_request/next_target = data[2]
					next_target.when_to_play = world.time + playback_length
				else
					// So that if the audio file is already playing whilst a new file comes in,
					// it won't play in the middle of the audio file.
					var/datum/tts_request/arbritrary_delay = new()
					arbritrary_delay.when_to_play = world.time + playback_length
					arbritrary_delay.audio_file = TTS_ARBRITRARY_DELAY
					queued_tts_messages[tts_target] += arbritrary_delay
				SHIFT_DATA_ARRAY(queued_tts_messages, tts_target, data)

	for(var/identifier, radio_list in queued_radio_messages)
		if(MC_TICK_CHECK)
			return
		if(!completed_tts_messages[identifier])
			continue

		for(var/radio, hearer_list in radio_list)
			if(isweakref(radio))
				var/datum/weakref/weakref = radio
				var/obj/radio_obj = weakref.resolve()
				if(QDELETED(radio_obj))
					queued_radio_messages[identifier] -= radio
					continue

			var/datum/tts_request/tts_request = completed_tts_messages[identifier][TTS_REQUEST_REF]
			var/list/groups = list()
			var/list/radio_hearers = hearer_list
			for(var/datum/weakref/listener_ref as anything in radio_hearers.Copy())
				var/mob/listener = listener_ref.resolve()
				var/datum/tts_request/variant = tts_request.translated ? get_tts_variant(tts_request, listener, queued_radio_message_context[identifier]) : tts_request
				if(!listener || !variant || variant.timed_out)
					hearer_list -= listener_ref
					continue
				if(!variant.audio_file)
					continue
				LAZYADD(groups[variant], listener_ref)
				hearer_list -= listener_ref
			for(var/datum/tts_request/variant as anything in groups)
				play_tts_request(variant, radio == TTS_GHOST_RADIO ? null : radio, groups[variant], radio = TRUE, compressed = queued_radio_messages_compression[identifier] > COMPRESSION_REPLACE_CHARACTER_THRESHOLD)
			if(!length(hearer_list))
				radio_list -= radio
		if(!length(radio_list))
			clear_radio_message(identifier)

	for(var/identifier, request in completed_tts_messages)
		if (world.time < completed_tts_messages[identifier][TTS_REQUEST_EXPIRE])
			continue

		clear_radio_message(identifier)

#undef TTS_ARBRITRARY_DELAY

/** Plays one already prepared listener group with the existing spatial, volume and blips preferences. */
/datum/controller/subsystem/tts/proc/play_tts_request(datum/tts_request/request, datum/weakref/location, list/listeners, radio = FALSE, compressed = FALSE)
	if(request.translated && !length(listeners))
		return
	if(location && !location.resolve())
		return
	var/audio_file = radio ? (compressed ? request.audio_file_radio_gibberish : request.audio_file_radio) : request.audio_file
	play_tts(
		target = location,
		listeners = listeners,
		audio = sound(audio_file),
		audio_blips = sound(radio ? request.audio_file_blips_radio : request.audio_file_blips),
		language = request.language,
		range = radio ? INFINITY : request.message_range,
		volume_offset = request.volume_offset,
		ignore_observers = radio || request.translated,
		source_speaker = radio ? request.target : null,
		audio_length = radio ? request.audio_length_radio : request.audio_length,
		audio_length_blips = radio ? request.audio_length_blips_radio : request.audio_length_blips,
		volume_preference = radio ? /datum/preference/numeric/volume/sound_tts_radio_volume : /datum/preference/numeric/volume/sound_tts_volume,
		volume_signal = radio ? COMSIG_MOB_TTS_RADIO_VOLUME_PREFERENCE_APPLIED : COMSIG_MOB_TTS_VOLUME_PREFERENCE_APPLIED,
		translated = request.translated,
	)

/datum/controller/subsystem/tts/proc/queue_tts_message(datum/target, message, datum/language/language, speaker, filter, list/listeners, local = FALSE, message_range = 7, volume_offset = 0, pitch = 0, special_filters = "", blip_base = "male", blip_number = "1", force_blips = FALSE, identifier = "invalid", list/message_mods, datum/tts_request/parent_request)
	if(!tts_enabled)
		return

	// TGS updates can clear out the tmp folder, so we need to create the folder again if it no longer exists.
	if(!fexists("tmp/tts/init.txt"))
		rustg_file_write("rustg HTTP requests can't write to folders that don't exist, so we need to make it exist.", "tmp/tts/init.txt")

	var/static/regex/contains_alphanumeric = regex("\[a-zA-Zа-яА-ЯёЁ0-9]")
	// If there is no alphanumeric char, the output will usually be static, so
	// don't bother sending
	if(contains_alphanumeric.Find(message) == 0)
		return

	var/shell_scrubbed_input = tts_speech_filter(html_decode(message))
	if(!(speaker in available_speakers))
		return
	var/list/listener_weakrefs = list()
	for(var/listener in listeners)
		listener_weakrefs += WEAKREF(listener)
	var/list/headers = list()
	headers["Content-Type"] = "application/json"
	headers["Authorization"] = CONFIG_GET(string/tts_http_token)
	var/datum/http_request/request = new()
	var/datum/http_request/request_blips = new()
	var/datum/http_request/request_radio = new()
	var/datum/http_request/request_blips_radio = new()
	var/datum/http_request/request_radio_gibberish = new()
	var/file_name = "tmp/tts/[identifier].ogg"
	var/file_name_blips = "tmp/tts/[identifier]_blips.ogg"
	var/file_name_radio = "tmp/tts/[identifier]_radio.ogg"
	var/file_name_blips_radio = "tmp/tts/[identifier]_blips_radio.ogg"
	var/file_name_radio_gibberish = "tmp/tts/[identifier]_radio_gibberish.ogg"
	request.prepare(RUSTG_HTTP_METHOD_GET, "[CONFIG_GET(string/tts_http_url)]/tts?voice=[speaker]&identifier=[identifier]&filter=[tts_filter_encode(filter, speaker, pitch)]&pitch=[pitch]&special_filters=[url_encode(special_filters)]", json_encode(list("text" = shell_scrubbed_input)), headers, file_name, timeout_seconds = CONFIG_GET(number/tts_http_timeout_seconds))
	request_blips.prepare(RUSTG_HTTP_METHOD_GET, "[CONFIG_GET(string/tts_http_url)]/tts-blips?voice=[speaker]&identifier=[identifier]&filter=[tts_filter_encode(filter, speaker, pitch, blips = TRUE)]&pitch=[pitch]&special_filters=[url_encode(special_filters)]&blip_base=[blip_base]&blip_number=[blip_number]", json_encode(list("text" = shell_scrubbed_input)), headers, file_name_blips, timeout_seconds = CONFIG_GET(number/tts_http_timeout_seconds))
	request_radio.prepare(RUSTG_HTTP_METHOD_GET, "[CONFIG_GET(string/tts_http_url)]/tts-radio?voice=[speaker]&identifier=[identifier]&filter=[tts_filter_encode(filter, speaker, pitch)]&pitch=[pitch]&special_filters=[url_encode(special_filters)]", json_encode(list("text" = shell_scrubbed_input)), headers, file_name_radio, timeout_seconds = CONFIG_GET(number/tts_http_timeout_seconds))
	request_blips_radio.prepare(RUSTG_HTTP_METHOD_GET, "[CONFIG_GET(string/tts_http_url)]/tts-blips-radio?voice=[speaker]&identifier=[identifier]&filter=[tts_filter_encode(filter, speaker, pitch, blips = TRUE)]&pitch=[pitch]&special_filters=[url_encode(special_filters)]&blip_base=[blip_base]&blip_number=[blip_number]", json_encode(list("text" = shell_scrubbed_input)), headers, file_name_blips_radio, timeout_seconds = CONFIG_GET(number/tts_http_timeout_seconds))
	request_radio_gibberish.prepare(RUSTG_HTTP_METHOD_GET, "[CONFIG_GET(string/tts_http_url)]/tts-radio?voice=[speaker]&identifier=[identifier]&filter=[tts_filter_encode(filter, speaker, pitch)]&pitch=[pitch]&special_filters=[url_encode(special_filters)]", json_encode(list("raw_text" = shell_scrubbed_input, "gibberish_text" = shell_scrubbed_input)), headers, file_name_radio_gibberish, timeout_seconds = CONFIG_GET(number/tts_http_timeout_seconds))
	var/datum/tts_request/current_request = new /datum/tts_request(identifier, request, request_blips, request_radio, request_blips_radio, request_radio_gibberish, shell_scrubbed_input, target, local, language, message_range, volume_offset, listener_weakrefs, pitch, force_blips)
	current_request.raw_message = message
	current_request.translated = !!parent_request || (!local && ismovable(target) && !isnull(message_mods))
	current_request.message_mods = message_mods
	if(!parent_request)
		var/list/player_queued_tts_messages = queued_tts_messages[WEAKREF(target)]
		if(!player_queued_tts_messages)
			player_queued_tts_messages = list()
			queued_tts_messages[WEAKREF(target)] = player_queued_tts_messages
		player_queued_tts_messages += current_request
	if(length(in_process_http_messages) < max_concurrent_requests)
		current_request.start_requests()
		in_process_http_messages += current_request
	else
		queued_http_messages.insert(current_request)
	if(current_request.translated && !parent_request)
		current_request.variant_args = list(
			"target" = target, "language" = language, "speaker" = speaker, "filter" = filter,
			"local" = local, "message_range" = message_range, "volume_offset" = volume_offset,
			"pitch" = pitch, "special_filters" = special_filters, "blip_base" = blip_base,
			"blip_number" = blip_number, "force_blips" = force_blips,
		)
		current_request.listeners = list()
		var/list/nearby_listeners = listeners ? listeners.Copy() : list()
		var/atom/movable/source = target
		nearby_listeners |= SSmobs.dead_players_by_zlevel[source.z]
		for(var/mob/listener in nearby_listeners)
			var/datum/tts_request/variant = get_tts_variant(current_request, listener)
			if(variant)
				variant.listeners |= WEAKREF(listener)
		for(var/radio, radio_listeners in queued_radio_messages[identifier])
			for(var/datum/weakref/listener_ref as anything in radio_listeners)
				var/mob/listener = listener_ref.resolve()
				if(listener)
					get_tts_variant(current_request, listener, queued_radio_message_context[identifier])
	return current_request

/** Reuses translated audio or requests a new variant without adding another utterance to the speaker's queue. */
/datum/controller/subsystem/tts/proc/get_tts_variant(datum/tts_request/parent_request, mob/listener, list/radio_context)
	var/atom/movable/source = parent_request.target
	if(!source || QDELETED(source) || !listener || QDELETED(listener))
		return null
	listener = listener.get_listening_mob()
	if(!listener || QDELETED(listener))
		return null
	var/message = radio_context ? radio_context["message"] : parent_request.raw_message
	var/language = radio_context ? radio_context["language"] : parent_request.language
	var/list/mods = radio_context ? radio_context["mods"] : parent_request.message_mods
	var/list/heard_messages = parent_request.message_mods?[MODE_TTS_LISTENER_MESSAGES]
	var/translation
	if(!radio_context && (REF(listener) in heard_messages))
		translation = heard_messages[REF(listener)]
	else
		translation = isobserver(listener) ? message : listener.translate_language(source, language, message, message_mods = mods)
	if(translation == parent_request.raw_message)
		return parent_request
	if(translation in parent_request.variants)
		return parent_request.variants[translation]
	var/list/variant_args = parent_request.variant_args.Copy()
	variant_args["message"] = translation
	variant_args["identifier"] = "[parent_request.identifier]-[md5(translation)]"
	variant_args["parent_request"] = parent_request
	var/datum/tts_request/variant = queue_tts_message(arglist(variant_args))
	parent_request.variants[translation] = variant
	return variant

/datum/controller/subsystem/tts/proc/clear_radio_message(identifier)
	completed_tts_messages[identifier] -= TTS_REQUEST_REF // don't stick around
	completed_tts_messages -= identifier
	queued_radio_messages -= identifier
	queued_radio_messages_compression -= identifier
	queued_radio_message_context -= identifier

/// Helper to get a random TTS voice for a certain gender. Passing no gender just results in a random voice.
/datum/controller/subsystem/tts/proc/random_tts_voice(gender = NEUTER)
	if(!tts_enabled)
		return null

	var/sanity = 0
	while(sanity < 10)
		var/voice = pick(available_speakers)
		if(gender != MALE && gender != FEMALE)
			return voice
		if(gender == MALE && findtext(voice, "Man"))
			return voice
		if(gender == FEMALE && findtext(voice, "Woman"))
			return voice
		sanity += 1

	return pick(available_speakers) // failsafe

/// A struct containing information on an individual player or mob who has made a TTS request
/datum/tts_request
	/// The mob to play this TTS message on
	var/mob/target
	/// The people who are going to hear this TTS message
	/// Does nothing if local is set to TRUE
	var/list/listeners
	/// The HTTP request of this message
	var/datum/http_request/request
	/// The HTTP request of this message for blips
	var/datum/http_request/request_blips
	/// The HTTP request of this message's radio version
	var/datum/http_request/request_radio
	/// The HTTP request of this blip message's radio version
	var/datum/http_request/request_blips_radio
	/// The HTTP request of this message's radio gibberish version
	var/datum/http_request/request_radio_gibberish
	/// The language to limit this TTS message to
	var/datum/language/language
	/// The message itself
	var/message
	/// The message identifier
	var/identifier
	/// The volume offset to play this TTS at.
	var/volume_offset = 0
	/// Whether this TTS message should be sent to the target only or not.
	var/local = FALSE
	/// The message range to play this TTS message
	var/message_range = 7
	/// The time at which this request was started
	var/start_time

	/// The audio file of this tts request.
	var/sound/audio_file
	/// The blips audio file of this tts request.
	var/sound/audio_file_blips
	/// The radio audio file of this tts request.
	var/sound/audio_file_radio
	/// The blips radio audio file of this tts request.
	var/sound/audio_file_blips_radio
	/// The gibberish radio audio file of this tts request.
	var/sound/audio_file_radio_gibberish
	/// The audio length of this tts request.
	var/audio_length
	var/audio_length_blips
	var/audio_length_radio
	var/audio_length_blips_radio
	var/audio_length_radio_gibberish
	/// When the audio file should play at the minimum
	var/when_to_play = 0
	/// Whether this request was timed out or not
	var/timed_out = FALSE
	/// Does this use blips during local generation or not?
	var/use_blips = FALSE
	/// What's the pitch adjustment?
	var/pitch = 0
	/// Should we force play blips? Used for the blips preview.
	var/force_blips = FALSE
	/// Input text before filtering, retained for per-listener translation.
	var/raw_message
	/// Speech modifiers describing the language fragments of raw_message.
	var/list/message_mods
	/// Audio has already been translated for its intended listeners.
	var/translated = FALSE
	/// Translated text mapped to its audio request; null means the text cannot be synthesized.
	var/list/variants = list()
	/// Existing synthesis options reused by local and late radio variants.
	var/list/variant_args

/** Waits for the utterance's variants and returns their longest duration, so later speech keeps its order. */
/datum/tts_request/proc/get_playback_length()
	if(!audio_file)
		return null
	. = audio_length || 0
	for(var/text in variants)
		var/datum/tts_request/variant = variants[text]
		if(!variant || variant.timed_out)
			continue
		if(!variant.audio_file)
			return null
		. = max(., variant.audio_length)


/datum/tts_request/New(identifier, datum/http_request/request, datum/http_request/request_blips, datum/http_request/request_radio, datum/http_request/request_blips_radio, datum/http_request/request_radio_gibberish, message, target, local, datum/language/language, message_range, volume_offset, list/listeners, pitch, force_blips = FALSE)
	. = ..()
	src.identifier = identifier
	src.request = request
	src.request_blips = request_blips
	src.request_radio = request_radio
	src.request_blips_radio = request_blips_radio
	src.request_radio_gibberish = request_radio_gibberish
	src.message = message
	src.language = language
	src.target = target
	src.local = local
	src.message_range = message_range
	src.volume_offset = volume_offset
	src.listeners = listeners
	src.pitch = pitch
	src.force_blips = force_blips
	start_time = world.time

/datum/tts_request/proc/start_requests()
	if(istype(target, /client))
		var/client/current_client = target
		use_blips = (current_client?.prefs.read_preference(/datum/preference/choiced/sound_tts) == TTS_SOUND_BLIPS)
	else if(istype(target, /mob))
		use_blips = (target.client?.prefs.read_preference(/datum/preference/choiced/sound_tts) == TTS_SOUND_BLIPS)
	if(local)
		if(use_blips || force_blips)
			request_blips.begin_async()
		else
			request.begin_async()
	else
		request.begin_async()
		request_blips.begin_async()
		request_radio.begin_async()
		request_blips_radio.begin_async()
		request_radio_gibberish.begin_async()

/datum/tts_request/proc/get_primary_request()
	if(local)
		if(use_blips || force_blips)
			return request_blips
		else
			return request
	else
		return request

/datum/tts_request/proc/get_primary_response()
	if(local)
		if(use_blips || force_blips)
			return request_blips.into_response()
		else
			return request.into_response()
	else
		return request.into_response()

/datum/tts_request/proc/requests_errored()
	if(local)
		var/datum/http_response/response
		if(use_blips || force_blips)
			response = request_blips.into_response()
		else
			response = request.into_response()
		return response.errored
	else
		var/datum/http_response/response = request.into_response()
		var/datum/http_response/response_blips = request_blips.into_response()
		var/datum/http_response/response_radio = request_radio.into_response()
		var/datum/http_response/response_blips_radio = request_blips_radio.into_response()
		var/datum/http_response/response_radio_gibberish = request_radio_gibberish.into_response()
		return response.errored || response_blips.errored || response_radio.errored || response_blips_radio.errored || response_radio_gibberish.errored

/datum/tts_request/proc/requests_completed()
	if(local)
		if(use_blips || force_blips)
			return request_blips.is_complete()
		else
			return request.is_complete()
	else
		return request.is_complete() && request_blips.is_complete() && request_blips_radio.is_complete() && request_radio.is_complete() && request_radio_gibberish.is_complete()

#undef TTS_REQUEST_REF
#undef TTS_REQUEST_EXPIRE

/**
 * Checks if the passed mob can hear radio TTS
 *
 * * hearer - The mob to check if they can hear radio TTS
 * * radio_frequency - The frequency of the radio TTS message
 */
/proc/can_hear_radio_tts(mob/hearer, radio_frequency)
	if(!SStts.tts_enabled && !SStts220.is_enabled) // BANDASTATION EDIT: Spatial TTS
		return FALSE

	if(HAS_TRAIT(hearer, TRAIT_DEAF) || IS_UNCONSCIOUS(hearer))
		return FALSE

	var/tts_pref = hearer.client?.prefs.read_preference(/datum/preference/choiced/sound_tts) || TTS_SOUND_OFF
	if(tts_pref == TTS_SOUND_OFF)
		return FALSE

	var/radio_tts_pref = hearer.client?.prefs.read_preference(/datum/preference/choiced/sound_tts_radio) || TTS_SOUND_NO_RADIO
	switch(radio_tts_pref)
		if(TTS_SOUND_NO_RADIO)
			return FALSE
		if(TTS_SOUND_DEPARTMENTAL_RADIO) // don't give them the full common firehose if they turned it off
			return radio_frequency != FREQ_COMMON

	return TRUE

#undef SHIFT_DATA_ARRAY
