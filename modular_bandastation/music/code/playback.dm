/datum/song
	volume = 75
	max_volume = 100
	max_sound_channels = 32

	/// Explicit engine selection: text Notes, MIDI sequence, or uploaded OGG.
	var/playback_mode = "midi"
	/// Loop playback until explicitly stopped.
	var/auto_repeat = FALSE
	/// Absolute deadline of the next text-note chord, in deciseconds.
	var/next_chord_time = 0
	/// Last processing time used for elapsed-time decay.
	var/last_process_time = 0
	/// Manual note-start delay in instrument subsystem ticks.
	var/midi_start_delay_ticks = 0
	/// Owned timer for a delayed note start.
	var/midi_start_timer
	/// Bypass the manual delay for a synchronized start.
	var/ignore_midi_start_delay = FALSE

/datum/song/Destroy()
	QDEL_NULL(piano_roll)
	auto_unison_enabled = FALSE
	. = ..()
	STOP_PROCESSING(SSinstruments, src)
	cleanup_music_uploads()
	loaded_file_tracks = null

/// Refresh all configured music sources and their spatial sound state.
/datum/song/do_hearcheck()
	last_hearcheck = world.time
	var/list/old = hearing_mobs.Copy()
	hearing_mobs.len = 0
	for(var/atom/source as anything in get_instrument_sources())
		for(var/mob/M in get_hearers_in_view(instrument_range, get_turf(source)))
			hearing_mobs[M] = get_dist(M, source)
	var/list/exited = old - hearing_mobs
	for(var/i in exited)
		terminate_sound_mob(i)
	if(playback_mode != "file")
		refresh_music_spatial()

/// Dispatch playback engines; the base text-note start cannot initialize MIDI/OGG or exact deadlines.
/datum/song/start_playing(atom/user)
	if(playing)
		return
	if(istype(parent, /obj/item/instrument))
		var/obj/item/instrument/instrument = parent
		if(!instrument.can_play(user))
			return
	if(midi_start_timer)
		return
	if(!using_instrument?.ready())
		to_chat(user, span_warning("An error has occured with [src]. Please reset the instrument."))
		ignore_midi_start_delay = FALSE
		return
	if(playback_mode == "file")
		start_file_playing(user)
		return
	if(playback_mode == "sequence")
		start_sequence(user)
		return
	if(midi_start_delay_ticks > 0 && !ignore_midi_start_delay)
		midi_start_timer = addtimer(CALLBACK(src, PROC_REF(delayed_midi_start), user), midi_start_delay_ticks * SSinstruments.wait, TIMER_STOPPABLE)
		return
	ignore_midi_start_delay = FALSE
	compile_chords()
	if(!length(compiled_chords))
		to_chat(user, span_warning("Song is empty."))
		ignore_midi_start_delay = FALSE
		return
	playing = TRUE
	//we can not afford to runtime, since we are going to be doing sound channel reservations and if we runtime it means we have a channel allocation leak.
	//wrap the rest of the stuff to ensure stop_playing() is called.
	do_hearcheck()
	SEND_SIGNAL(parent, COMSIG_INSTRUMENT_START, src, user)
	SEND_SIGNAL(user, COMSIG_ATOM_STARTING_INSTRUMENT, src)
	next_chord_time = world.time
	current_chord = 1
	music_player = user
	last_process_time = world.time
	START_PROCESSING(SSinstruments, src)
	if((id || multi_sync_enabled) && !sync_starting)
		sync_play()

/// Start Notes after the owned delay timer expires.
/datum/song/proc/delayed_midi_start(atom/user)
	midi_start_timer = null
	ignore_midi_start_delay = TRUE
	start_playing(user)

/// Cancel a pending note start and reset its bypass flag.
/datum/song/proc/cancel_delayed_midi_start()
	if(!midi_start_timer)
		return FALSE
	deltimer(midi_start_timer)
	midi_start_timer = null
	ignore_midi_start_delay = FALSE
	return TRUE

/datum/song/stop_playing(finished = FALSE)
	cancel_delayed_midi_start()
	cancel_sync_timers()
	var/was_playing = playing
	. = ..()
	if(!was_playing)
		return
	file_track_finish_time = 0
	last_process_time = 0
	next_chord_time = 0
	voice_ends.Cut()
	voice_levels.Cut()
	listener_spatial.Cut()
	for(var/datum/song/follower as anything in sequence_followers.Copy())
		if(!QDELETED(follower) && follower.sequence_master == src)
			follower.stop_playing()
	sequence_followers.Cut()
	if(sequence_master && !QDELETED(sequence_master))
		sequence_master.sequence_followers -= src
	sequence_master = null
	file_listeners.Cut()
	ignore_midi_start_delay = FALSE

/// Use absolute note deadlines with bounded catch-up instead of the base tick counter.
/datum/song/process_song(wait)
	if(playback_mode == "file")
		if(playing)
			process_file_playing()
			return
		return PROCESS_KILL

	if(playing)
		if(!length(compiled_chords))
			stop_playing(TRUE)
			return
		if(should_stop_playing(music_player) == STOP_PLAYING)
			stop_playing(FALSE)
			return
		// Keep overdue deadlines instead of discarding time after the catch-up budget.
		var/budget = 4
		while(playing && world.time >= next_chord_time && budget-- > 0)
			if(current_chord > length(compiled_chords))
				if(!repeat && !auto_repeat)
					stop_playing(TRUE)
					return
				if(!auto_repeat)
					repeat--
				current_chord = 1
				SEND_SIGNAL(parent, COMSIG_INSTRUMENT_REPEAT, TRUE)
			var/list/chord = compiled_chords[current_chord]
			play_chord(chord)
			next_chord_time += tempodiv_to_delay(chord[length(chord)])
			current_chord++
		return

	return PROCESS_KILL


/// Convert a note division to exact deciseconds, without rounding to subsystem ticks.
/datum/song/tempodiv_to_delay(tempodiv)
	if(!isnum(tempodiv) || tempodiv <= 0)
		tempodiv = 1 // no division by 0. some song converters tend to use 0 for when it wants to have no div, for whatever reason.
	return (60 SECONDS) / bpm / tempodiv

/// Keep the configured repeat count editable during playback.
/datum/song/set_repeats(new_repeats_value)
	repeat = round(new_repeats_value)
	if(repeat < 0)
		repeat = 0
	if(repeat > max_repeats)
		repeat = max_repeats

/// Process the selected engine and preserve elapsed time for note decay.
/datum/song/process(wait)
	if(!playing)
		if(auto_unison_enabled)
			if(world.time >= last_unison_check + 1 SECONDS)
				last_unison_check = world.time
				try_auto_unison_once()
			return
		return PROCESS_KILL
	if(playback_mode == "sequence")
		process_sequence()
		return
	var/elapsed = max(0, world.time - last_process_time)
	last_process_time = world.time
	if(playback_mode != "file")
		process_sequence_voices()
		process_decay(elapsed)
	process_song(elapsed)

/// Locate a musician who can currently play this instrument.
/datum/song/handheld/find_sync_player()
	var/obj/item/instrument/instrument = parent
	var/mob/living/player = instrument.loc
	if(isturf(instrument.loc))
		for(var/mob/living/nearby in instrument.loc)
			if(nearby.client && instrument.can_play(nearby))
				return nearby
		return null
	if(instrument.can_play(player))
		return player
	return null

/// Locate a musician who can currently play this instrument.
/datum/song/stationary/find_sync_player()
	var/obj/structure/musician/piano = parent
	for(var/mob/living/player in view(parent, 1))
		if(piano.can_play(player))
			return player

	return null

/obj/item/instrument/can_play(atom/music_player)
	if(!..())
		return FALSE
	var/mob/user = music_player
	if(src in user.held_items)
		return TRUE
	if(playable_while_worn && (user.get_slot_by_item(src) & slot_flags))
		return TRUE
	return isturf(loc) && loc == get_turf(user)

/// Select a playback engine, stopping the previous engine first.
/datum/song/proc/set_playback_mode(new_mode)
	if(!(new_mode in list("midi", "sequence", "file")))
		return
	if(playing)
		stop_playing()
	playback_mode = new_mode
