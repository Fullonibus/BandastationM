/datum/song/playkey_legacy(note, acc as text, oct, atom/player)
	if(cached_legacy_ext == "mid" && using_instrument.pcm_samples)
		if(world.time >= last_hearcheck + SSinstruments.musician_hearcheck_mindelay)
			do_hearcheck()
		play_sequence_note(list("key" = note_offset_lookup[note] + oct * 12 + (accent_lookup[acc] || 0) + 12, "velocity" = 127, "channel" = 0), 0.5)
		return
	// handle accidental -> B<>C of E<>F
	if(acc == "b" && (note == 3 || note == 6)) // C or F
		if(note == 3)
			oct--
		note--
		acc = "n"
	else if(acc == "#" && (note == 2 || note == 5)) // B or E
		if(note == 2)
			oct++
		note++
		acc = "n"
	else if(acc == "#" && (note == 7)) //G#
		note = 1
		acc = "b"
	else if(acc == "#") // mass convert all sharps to flats, octave jump already handled
		acc = "b"
		note++

	// check octave, C is allowed to go to 9
	if(oct < 1 || (note == 3 ? oct > 9 : oct > 8))
		return

	// now generate name
	var/soundfile = "sound/runtime/instruments/[cached_legacy_dir]/[ascii2text(note+64)][acc][oct].[cached_legacy_ext]"
	soundfile = file(soundfile)
	// make sure the note exists
	if(!fexists(soundfile))
		return
	// and play
	if((world.time - SSinstruments.musician_hearcheck_mindelay) > last_hearcheck)
		do_hearcheck()
	var/sound/music_played = sound(soundfile)
	for(var/i in hearing_mobs)
		var/mob/M = i
		var/listener_volume = get_listener_volume_multiplier(M)
		if(!listener_volume)
			continue
		M.playsound_local(nearest_music_source(M), null, get_output_volume(volume * using_instrument.volume_multiplier) * listener_volume, sound_to_use = music_played, pressure_affected = FALSE, max_distance = instrument_range, falloff_distance = get_sound_falloff_distance(), falloff_exponent = INSTRUMENT_FALLOFF_EXPONENT)
		// Could do environment and echo later but not for now

/datum/song/playkey_synth(key, atom/player)
	key = clamp(key + note_shift, key_min, key_max)
	if((world.time - SSinstruments.musician_hearcheck_mindelay) > last_hearcheck)
		do_hearcheck()
	if(!length(hearing_mobs))
		return FALSE
	var/datum/instrument_key/K = using_instrument.samples[num2text(key)] //See how easy it is to make a number text?
	var/channel = pop_channel()
	if(isnull(channel))
		return FALSE
	. = TRUE
	var/sound/copy = sound(K.sample)
	var/volume = get_output_volume(src.volume * using_instrument.volume_multiplier)
	copy.frequency = K.frequency
	copy.volume = volume
	var/channel_text = num2text(channel)
	channels_playing[channel_text] = 100
	last_channel_played = channel_text
	for(var/i in hearing_mobs)
		var/mob/M = i
		var/listener_volume = get_listener_volume_multiplier(M)
		if(!listener_volume)
			continue
		M.playsound_local(nearest_music_source(M), null, volume * listener_volume, FALSE, K.frequency, INSTRUMENT_FALLOFF_EXPONENT, channel, FALSE, copy, instrument_range, get_sound_falloff_distance())
		// Could do environment and echo later but not for now

/datum/song/process_decay(wait_ds)
	var/linear_dropoff = cached_linear_dropoff * wait_ds
	var/exponential_dropoff = cached_exponential_dropoff ** wait_ds
	for(var/channel in channels_playing)
		if(voice_ends[channel])
			continue
		if(full_sustain_held_note && (channel == last_channel_played))
			continue
		var/current_volume = channels_playing[channel]
		switch(sustain_mode)
			if(SUSTAIN_LINEAR)
				current_volume -= linear_dropoff
			if(SUSTAIN_EXPONENTIAL)
				current_volume /= exponential_dropoff
		channels_playing[channel] = current_volume
		var/dead = current_volume <= sustain_dropoff_volume
		var/channelnumber = text2num(channel)
		if(dead)
			channels_playing -= channel
			channels_idle += channel
			for(var/i in hearing_mobs)
				var/mob/M = i
				M.stop_sound_channel(channelnumber)
		else
			for(var/i in hearing_mobs)
				var/mob/M = i
				update_music_voice_listener(M, channelnumber, (current_volume * 0.01) * get_output_volume(volume * using_instrument.volume_multiplier))
	trim_idle_channels()

/// Update output gain and refresh active listener volumes.
/datum/song/set_volume(volume)
	src.volume = clamp(round(volume, 1), max(0, min_volume), max_volume)
	update_sustain()
	if(playing && playback_mode == "file")
		update_file_playback_volume()
	else if(playing)
		refresh_music_spatial()


/// Apply the existing note output gain.
/datum/song/proc/get_output_volume(base_volume = volume)
	return base_volume * INSTRUMENT_OUTPUT_GAIN


/// Apply the existing OGG output gain.
/datum/song/proc/get_file_output_volume(base_volume = volume)
	return base_volume * INSTRUMENT_FILE_OUTPUT_GAIN


/// Clamp sound falloff to the instrument's range.
/datum/song/proc/get_sound_falloff_distance()
	if(instrument_range <= 1)
		return 0
	return min(INSTRUMENT_FALLOFF_DISTANCE, instrument_range - 1)


/datum/song/terminate_all_sounds(clear_channels = TRUE)
	. = ..()
	if(clear_channels)
		voice_ends.Cut()
		voice_levels.Cut()

/datum/song/pop_channel()
	. = ..()
	if(isnull(.))
		. = steal_oldest_note()

/// Replace only this song's own oldest voice when channels are exhausted.
/datum/song/proc/steal_oldest_note()
	if(!length(channels_playing))
		return null
	var/channel = channels_playing[1]
	for(var/mob/listener as anything in hearing_mobs)
		listener.stop_sound_channel(text2num(channel))
	channels_playing -= channel
	voice_ends -= channel
	voice_levels -= channel
	return text2num(channel)

/// Retain a small warm channel cache and release unused allocations.
/datum/song/proc/trim_idle_channels()
	while(length(channels_idle) > 4)
		var/channel = channels_idle[1]
		channels_idle.Cut(1, 2)
		SSsounds.free_sound_channel(text2num(channel))
		using_sound_channels--
		SSinstruments.current_instrument_channels--

/// Read the listener's existing instrument volume preference.
/datum/song/proc/get_listener_volume_multiplier(mob/listener)
	var/instrument_volume = listener?.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_instruments)
	if(!instrument_volume)
		return 0
	return instrument_volume / 100

