/** Concert playback borrows disk resources and uses the instrument channel allocator. */
/datum/song/concert
	allowed_instrument_ids = list()
	playback_mode = "file"
	min_volume = 0
	volume = 75
	max_sound_channels = 1

/datum/song/concert/start_playing(atom/user)
	var/obj/machinery/concert_player/player = parent
	if(playing || !player.can_play() || !player.selected_track)
		return
	playback_mode = "file"
	file_track = player.selected_track.song_path
	file_track_name = player.selected_track.song_name
	file_track_length = player.selected_track.song_length
	start_file_playing(parent)

/datum/song/concert/should_stop_playing(atom/user)
	var/obj/machinery/concert_player/player = parent
	return QDELETED(player) || !player.can_play() ? STOP_PLAYING : NONE

/datum/song/concert/can_use_advanced_music(atom/user)
	// Only the physical player drives this engine; disk writes use is_music_artist().
	return user == parent && !QDELETED(parent)

/datum/song/concert/get_instrument_sources()
	var/obj/machinery/concert_player/player = parent
	var/list/sources = ..()
	for(var/obj/item/circuit_component/concert_listener/receiver as anything in player.get_receivers())
		var/turf/origin = get_turf(receiver.get_source())
		// The local player and then the first receiver win ties at the same location.
		if(origin && !sources[origin])
			sources[origin] = receiver.gain.value / 100
	return sources

/datum/song/concert/get_file_output_volume(base_volume = volume)
	return base_volume

/datum/song/concert/get_sound_falloff_distance()
	return min(CONCERT_STEREO_RADIUS, max(0, instrument_range - 1))

/datum/song/concert/configure_file_sound(sound/track, turf/origin, turf/destination, distance, multiplier, gain = 1)
	if(distance > CONCERT_STEREO_RADIUS)
		return ..()
	track.volume = max(0, get_file_output_volume() * gain * multiplier)
	track.x = 0
	track.y = 0
	track.z = 0
	track.pan = 0
	track.environment = SOUND_ENVIRONMENT_NONE
	return TRUE

/datum/song/concert/get_listener_volume_multiplier(mob/listener)
	return (listener?.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_jukebox) || 0) / 100

/datum/song/concert/ui_interact(mob/user, datum/tgui/ui)
	parent.ui_interact(user)

/datum/song/concert/authorize_music_action(action, list/params, mob/user)
	return FALSE

/** Refresh an active stage after a receiver changes its location or availability. */
/obj/machinery/concert_player/proc/refresh_sources()
	if(song?.playing)
		song.do_hearcheck()
	SStgui.update_uis(src)
