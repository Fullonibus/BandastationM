/datum/song
	/// Uploaded sound resource selected for OGG playback.
	var/file_track
	/// Selected resource's display name.
	var/file_track_name
	/// Selected resource duration in deciseconds.
	var/file_track_length = 0
	/// Absolute end time of the current OGG cycle.
	var/file_track_finish_time = 0
	/// OGG resources retained by this instrument.
	var/list/loaded_file_tracks = list()
	/// Listener -> whether its current file channel uses non-positional stereo mode.
	var/list/file_listeners = list()
	var/list/music_uploads = list()
	var/file_track_hash
	var/list/song_cues = list()
	var/auto_sing = FALSE
	var/singing_tts = FALSE
	var/next_cue = 1
	var/next_music_upload = 0
	var/cue_spacing = 5

/datum/song/proc/get_instrument_sources()
	var/list/sources = list(parent)
	for(var/atom/source as anything in music_sources.Copy())
		if(QDELETED(source))
			music_sources -= source
			continue
		sources |= source
	return sources

/// Ordinary instruments have no per-source mixer; concert receivers may attenuate it.
/datum/song/proc/get_music_source_gain(atom/source)
	return 1

/datum/song/proc/nearest_music_source(mob/listener)
	var/turf/destination = get_turf(listener)
	var/turf/nearest = get_turf(parent)
	var/distance = INFINITY
	for(var/atom/source as anything in get_instrument_sources())
		var/turf/origin = get_turf(source)
		if(!origin || !destination || origin.z != destination.z)
			continue
		var/current = get_dist_euclidean(origin, destination)
		if(current < distance)
			distance = current
			nearest = origin
	return nearest

/datum/song/proc/cleanup_music_uploads()
	for(var/path in music_uploads)
		fdel(path)
	music_uploads.Cut()
	music_sources.Cut()

/datum/song/proc/set_file_track(new_file, mob/user)
	if(!can_use_advanced_music(user))
		return FALSE
	if(!is_valid_music_upload(new_file) || length(loaded_file_tracks) >= 12)
		to_chat(user, span_warning("Load an OGG up to 10 MB (maximum 12 tracks per instrument)."))
		return FALSE
	if(world.time < next_music_upload)
		return FALSE
	next_music_upload = world.time + 10 SECONDS
	var/hash = md5(new_file)
	var/path = "data/music_[REF(src)]_[hash].ogg"
	if(!fcopy(new_file, path))
		return FALSE
	var/duration = get_music_upload_duration(path)
	if(QDELETED(user) || !can_use_advanced_music(user) || !in_range(parent, user))
		fdel(path)
		return FALSE
	if(!is_valid_music_duration(duration))
		fdel(path)
		to_chat(user, span_warning("The OGG duration could not be read, or exceeds 30 minutes."))
		return FALSE
	if(playing)
		stop_playing()
	music_uploads |= path
	file_track = file(path)
	file_track_name = SANITIZE_FILENAME("[new_file]")
	file_track_hash = hash
	file_track_length = duration
	song_cues = list()
	cue_spacing = 5
	store_loaded_file_track(file_track_name, file_track, duration)
	for(var/list/track as anything in loaded_file_tracks)
		if(track["name"] == file_track_name)
			track["hash"] = hash
			track["cues"] = song_cues
			track["spacing"] = cue_spacing
			track["path"] = path
	prune_music_uploads()
	playback_mode = "file"
	return TRUE

/datum/song/proc/select_loaded_file_track(track_name)
	for(var/list/track as anything in loaded_file_tracks)
		if(track["name"] != track_name)
			continue
		if(playing)
			stop_playing()
		file_track = track["file"]
		file_track_name = track["name"]
		file_track_length = track["length"]
		file_track_hash = track["hash"]
		song_cues = track["cues"] || list()
		cue_spacing = track["spacing"] || 5
		playback_mode = "file"
		return TRUE
	return FALSE

/datum/song/proc/prune_music_uploads()
	var/list/used = list()
	for(var/list/track as anything in loaded_file_tracks)
		if(track["path"])
			used |= track["path"]
	for(var/path in music_uploads.Copy())
		if(!(path in used))
			fdel(path)
			music_uploads -= path

/datum/song/proc/start_file_playing(atom/player)
	if(!can_use_advanced_music(player))
		return
	if(!file_track)
		return FALSE
	playing = TRUE
	music_player = player
	playback_started_at = world.time
	file_track_finish_time = playback_started_at + file_track_length
	next_cue = 1
	do_hearcheck()
	if(!play_file_to_current_listeners(player))
		stop_playing()
		return FALSE
	SEND_SIGNAL(parent, COMSIG_INSTRUMENT_START, src, player)
	SEND_SIGNAL(player, COMSIG_ATOM_STARTING_INSTRUMENT, src)
	START_PROCESSING(SSinstruments, src)
	if(auto_unison_enabled && !sync_starting)
		sync_play()
	return TRUE

/datum/song/proc/play_file_to_current_listeners(atom/player)
	var/channel = pop_channel()
	if(isnull(channel))
		channel_starvation++
		to_chat(player, span_warning("No music channel is currently available."))
		return FALSE
	var/channel_text = num2text(channel)
	channels_playing[channel_text] = 100
	last_channel_played = channel_text
	file_listeners.Cut()
	update_file_listeners()
	return TRUE

/datum/song/proc/update_file_playback_volume()
	update_file_listeners()

/// Recompute audibility and location, without restarting existing listeners.
/datum/song/proc/update_file_listeners()
	if(!playing || playback_mode != "file")
		return
	var/list/sources = get_instrument_sources()
	for(var/mob/listener as anything in file_listeners.Copy())
		if(QDELETED(listener))
			file_listeners -= listener
			continue
		if(!(listener in hearing_mobs) || !listener.client)
			terminate_sound_mob(listener)
			file_listeners -= listener
	for(var/mob/listener as anything in hearing_mobs)
		var/turf/destination = get_turf(listener)
		var/turf/nearest
		var/atom/nearest_source
		var/distance = INFINITY
		for(var/atom/source as anything in sources)
			var/turf/origin = get_turf(source)
			if(!origin || !destination || origin.z != destination.z)
				continue
			var/new_distance = get_dist_euclidean(destination, origin)
			if(new_distance < distance)
				distance = new_distance
				nearest = origin
				nearest_source = source
		var/multiplier = get_listener_volume_multiplier(listener)
		if(!nearest || distance > instrument_range || !multiplier || HAS_TRAIT(listener, TRAIT_DEAF))
			if(listener in file_listeners)
				terminate_sound_mob(listener)
				file_listeners -= listener
			continue
		var/sound/track = make_file_sound(listener, nearest_source, distance, multiplier)
		SEND_SOUND(listener, track)

/** Prepare the actual sound packet; replace the channel at its current offset on 2D/3D changes. */
/datum/song/proc/make_file_sound(mob/listener, atom/source, distance, multiplier)
	var/sound/track = sound(file_track)
	track.channel = text2num(last_channel_played)
	var/stereo = configure_file_sound(track, source, get_turf(listener), distance, multiplier)
	if((listener in file_listeners) && file_listeners[listener] == stereo)
		track.status = SOUND_UPDATE
	else
		// Re-select the client sound mode without losing the track's current position.
		track.offset = max(0, (world.time - playback_started_at) / (1 SECONDS))
	file_listeners[listener] = stereo
	return track

/** Default instrument policy is positional audio at every distance; return its playback mode. */
/datum/song/proc/configure_file_sound(sound/track, atom/source, turf/destination, distance, multiplier)
	var/turf/origin = get_turf(source)
	track.volume = max(0, get_file_output_volume() * get_music_source_gain(source) * multiplier * (1 - CALCULATE_SOUND_VOLUME_RATIO(100, distance, instrument_range, get_sound_falloff_distance(), INSTRUMENT_FALLOFF_EXPONENT)))
	track.x = origin.x - destination.x
	track.z = origin.y - destination.y
	track.y = 0
	track.falloff = instrument_range
	return FALSE

/datum/song/proc/process_file_playing()
	if(should_stop_playing(music_player) == STOP_PLAYING)
		stop_playing()
		return
	if(world.time >= last_hearcheck + 5)
		do_hearcheck()
		update_file_listeners()
	if(!can_use_advanced_music(music_player))
		stop_playing()
		return
	process_song_cues()
	if(world.time < file_track_finish_time)
		return
	if(repeat > 0 || auto_repeat)
		if(!auto_repeat)
			repeat--
		terminate_all_sounds()
		playback_started_at = file_track_finish_time
		file_track_finish_time += file_track_length
		next_cue = 1
		play_file_to_current_listeners(music_player)
		SEND_SIGNAL(parent, COMSIG_INSTRUMENT_REPEAT, TRUE)
		return
	stop_playing(TRUE)

/datum/song/proc/load_song_cues(list/document)
	if(!islist(document) || document["version"] != 1 || document["audio_hash"] != file_track_hash)
		return FALSE
	var/list/cues = document["cues"]
	var/spacing = document["spacing_seconds"]
	if(isnull(spacing))
		spacing = 5
	if(!isnum(spacing) || spacing < 0.1 || spacing > 120)
		return FALSE
	if(!islist(cues) || length(cues) > 200)
		return FALSE
	var/list/validated = list()
	var/previous_time = -1
	for(var/list/cue as anything in cues)
		if(!islist(cue) || !isnum(cue["time"]) || !istext(cue["text"]))
			return FALSE
		if(cue["time"] < previous_time || cue["time"] < 0 || cue["time"] > file_track_length / (1 SECONDS) || length_char(cue["text"]) > 300)
			return FALSE
		previous_time = cue["time"]
		validated += list(list("time" = cue["time"], "text" = trim(cue["text"])))
	song_cues = validated
	cue_spacing = spacing
	for(var/list/track as anything in loaded_file_tracks)
		if(track["hash"] == file_track_hash)
			track["cues"] = song_cues
			track["spacing"] = cue_spacing
	next_cue = 1
	return TRUE

/datum/song/proc/process_song_cues()
	if(!isliving(music_player))
		return
	var/mob/living/singer = music_player
	var/elapsed = (world.time - playback_started_at) / (1 SECONDS)
	var/emitted = 0
	while(next_cue <= length(song_cues))
		var/list/cue = song_cues[next_cue]
		if(cue["time"] > elapsed)
			break
		next_cue++
		if(!auto_sing || emitted >= 2 || elapsed - cue["time"] > 2 || !(parent in singer.held_items) || singer.incapacitated)
			continue
		emitted++
		INVOKE_ASYNC(src, PROC_REF(emit_song_cue), singer, cue["text"], singing_tts)

/datum/song/proc/emit_song_cue(mob/living/singer, text, use_tts)
	if(!QDELETED(singer) && can_use_advanced_music(singer) && playing && (parent in singer.held_items) && !singer.incapacitated)
		singer.say(text, forced = "instrument auto song", message_mods = list("music_no_tts" = !use_tts))

/// Retain an uploaded track in the instrument's library.
/datum/song/proc/store_loaded_file_track(track_name, track_file, track_length)
	for(var/list/track as anything in loaded_file_tracks)
		if(track["name"] == track_name)
			track["file"] = track_file
			track["length"] = track_length
			return
	loaded_file_tracks += list(list(
		"name" = track_name,
		"file" = track_file,
		"length" = track_length,
	))


/// Update the selected OGG duration within the existing bounds.
/datum/song/proc/set_file_track_length(new_length)
	new_length = round(text2num("[new_length]"))
	if(!isnum(new_length))
		return FALSE
	file_track_length = clamp(new_length, 1 SECONDS, 30 MINUTES)
	for(var/list/track as anything in loaded_file_tracks)
		if(track["name"] == file_track_name)
			track["length"] = file_track_length
			break
	if(playing && playback_mode == "file")
		file_track_finish_time = playback_started_at + file_track_length
	return TRUE


/// Set the shared loop flag.
/datum/song/proc/set_auto_repeat(new_auto_repeat)
	auto_repeat = !!new_auto_repeat


/// Stop and clear the selected OGG and its cue sheet.
/datum/song/proc/clear_file_track()
	if(playing && playback_mode == "file")
		stop_playing()
	file_track = null
	file_track_name = null
	file_track_length = 0
	file_track_hash = null
	cue_spacing = 5
	song_cues = list()
	next_cue = 1
	if(playback_mode == "file")
		playback_mode = "midi"

