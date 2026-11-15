#define AUTO_UNISON_RADIUS 5

/datum/song
	var/auto_unison_enabled = FALSE
	var/last_unison_check = 0
	var/list/multi_tracks = list()
	var/multi_sync_enabled = FALSE
	var/ignore_play_checks = FALSE
	var/sync_starting = FALSE
	var/list/sync_timers = list()

/datum/song/proc/ds_per_beat()
	return max(1, round(600 / max(1, bpm)))

/datum/song/proc/force_start_playing()
	var/atom/player = find_sync_player()
	if(!player)
		return
	sync_starting = TRUE
	start_playing(player)
	sync_starting = FALSE

/datum/song/proc/transmit_song_to(datum/song/other)
	if(!istype(other))
		return

	other.lines = islist(lines) ? lines.Copy() : list()
	other.tempo = tempo
	other.bpm = bpm
	other.max_repeats = max_repeats
	other.compile_chords()

/datum/song/proc/receive_song_from(datum/song/master)
	if(!istype(master))
		return

	lines = islist(master.lines) ? master.lines.Copy() : list()
	tempo = master.tempo
	bpm = master.bpm
	max_repeats = master.max_repeats
	compile_chords()

/datum/song/proc/songs_by_id(target_id as text, require_in_view = TRUE)
	var/list/out = list()
	if(!istext(target_id) || !length(target_id))
		return out

	for(var/datum/song/S as anything in SSinstruments.songs)
		if(S == src)
			continue
		if(S.id != target_id)
			continue
		if(require_in_view)
			var/atom/other_player = S.find_sync_player()
			if(isnull(other_player) || !(other_player in view(get_turf(parent))))
				continue
		out += S
	return out

/datum/song/proc/try_auto_unison_once()
	if(playing || playback_mode == "file")
		return

	var/turf/src_turf = get_turf(parent)
	if(!src_turf)
		return

	var/datum/song/master

	for(var/datum/song/S as anything in SSinstruments.songs)
		if(S == src)
			continue
		if(!S.playing)
			continue
		if(S.playback_mode != playback_mode || S.sequence_master)
			continue
		if(S.auto_unison_enabled)
			continue
		var/turf/obj_turf = get_turf(S.parent)
		if(!obj_turf || obj_turf.z != src_turf.z)
			continue
		if(get_dist(src_turf, obj_turf) > AUTO_UNISON_RADIUS)
			continue
		master = S
		break

	if(!master)
		return
	master.start_sync_target(WEAKREF(src), TRUE)

/datum/song/handheld/should_stop_playing(atom/player)
	if(ignore_play_checks)
		return NONE

	. = ..()

	if(. == STOP_PLAYING || . == IGNORE_INSTRUMENT_CHECKS)
		return

	var/obj/item/instrument/I = parent
	return I.can_play(player) ? NONE : STOP_PLAYING

/datum/song/stationary/should_stop_playing(atom/player)
	if(ignore_play_checks)
		return NONE

	. = ..()

	if(. == STOP_PLAYING || . == IGNORE_INSTRUMENT_CHECKS)
		return TRUE

	var/obj/structure/musician/M = parent
	return M.can_play(player) ? NONE : STOP_PLAYING

/datum/song/ui_data(mob/user)
	var/list/data = ..()
	data["id"] = id
	data["auto_unison_enabled"] = auto_unison_enabled
	data["multi_sync_enabled"] = multi_sync_enabled
	var/list/out = list()
	for(var/i in 1 to multi_tracks.len)
		var/list/T = multi_tracks[i]
		out += list(list("target_id" = T["target_id"], "delay_beats" = T["delay_beats"]))

	data["multi_tracks"] = out
	return music_ui_data(data, user)

/datum/song/ui_act(action, list/params)
	if(!authorize_music_action(action, params, usr))
		return TRUE
	if(handle_music_action(action, params, usr))
		return TRUE
	switch(action)
		if("toggle_auto_unison")
			auto_unison_enabled = !auto_unison_enabled
			if(auto_unison_enabled)
				START_PROCESSING(SSinstruments, src)
			return TRUE
		if("toggle_multi_sync")
			multi_sync_enabled = !multi_sync_enabled
			return TRUE
		if("ms_add")
			if(length(multi_tracks) >= 16)
				return TRUE
			multi_tracks += list(list("target_id"=null, "delay_beats"=0))
			return TRUE
		if("ms_del")
			var/idx = max(1, round(text2num("[params["idx"]]")))
			if(idx <= multi_tracks.len)
				multi_tracks.Cut(idx, idx+1)
			return TRUE
		if("ms_set")
			var/idx2 = max(1, round(text2num("[params["idx"]]")))
			if(idx2 > multi_tracks.len) return FALSE
			var/list/T = multi_tracks[idx2]
			var/field = "[params["field"]]"
			if(field == "target_id")
				var/t = isnull(params["value"]) ? "" : "[params["value"]]"
				T["target_id"] = length(t) ? t : null
				return TRUE
			if(field == "delay_beats")
				T["delay_beats"] = clamp(round(text2num("[params["value"]]")), 0, 120)
				return TRUE
			return FALSE

		if("set_instrument_id")
			var/new_id = "[params["id"]]"
			new_id = trim(new_id)
			id = copytext_char(new_id, 1, 21)
			return TRUE

	. = ..()
	if(. && action == "import_song")
		set_playback_mode("midi")

/datum/song/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "InstrumentEditor220", parent.name) // BANDASTATION EDIT - New Instrument Synchronisation
		ui.open()

/// Delayed starts are owned by the initiating song, not by the target item.
/datum/song/proc/cancel_sync_timers()
	for(var/timer in sync_timers)
		deltimer(timer)
	sync_timers.Cut()

/datum/song/sync_play()
	cancel_sync_timers()
	if(playback_mode == "file")
		if(!auto_unison_enabled)
			return
		for(var/datum/song/other as anything in SSinstruments.songs)
			if(other != src && other.auto_unison_enabled && other.playback_mode == "file")
				start_sync_target(WEAKREF(other), TRUE)
		return
	if(!multi_sync_enabled)
		for(var/datum/song/other as anything in songs_by_id(id, TRUE))
			start_sync_target(WEAKREF(other), TRUE)
		return
	for(var/list/track as anything in multi_tracks)
		var/target = track["target_id"]
		if(!istext(target) || !length(target))
			continue
		for(var/datum/song/other as anything in songs_by_id(target, TRUE))
			sync_timers += addtimer(CALLBACK(src, PROC_REF(start_sync_target), WEAKREF(other), FALSE), clamp(track["delay_beats"], 0, 120) * (60 SECONDS) / max(1, bpm), TIMER_STOPPABLE)

/datum/song/proc/start_sync_target(datum/weakref/target_ref, unison)
	var/datum/song/target = target_ref.resolve()
	if(!playing || QDELETED(target) || target == src || target.playing || target.midi_start_timer)
		return
	var/turf/here = get_turf(parent)
	var/turf/there = get_turf(target.parent)
	var/atom/player = target.find_sync_player()
	if(!here || !there || here.z != there.z || !player || !(player in view(here)))
		return
	if(playback_mode == "file")
		if(!auto_unison_enabled || !target.auto_unison_enabled || target.playback_mode != "file" || get_dist(here, there) > AUTO_UNISON_RADIUS)
			return
	else if(target.playback_mode != playback_mode)
		return
	if(unison)
		if(playback_mode == "sequence")
			if(!target.can_use_advanced_music(player))
				return
			target.set_playback_mode("sequence")
			target.sequence_master = src
			sequence_followers |= target
		else if(playback_mode == "midi")
			target.set_playback_mode("midi")
			transmit_song_to(target)
			target.ignore_midi_start_delay = TRUE
	target.force_start_playing()
	if(target.sequence_master == src && !target.playing)
		sequence_followers -= target
		target.sequence_master = null
	if(unison && playback_mode == "midi" && target.playing)
		target.current_chord = clamp(current_chord, 1, length(target.compiled_chords))
		target.next_chord_time = next_chord_time
	if(target.playing)
		target.update_static_data_for_all_viewers()
		target.piano_roll?.update_static_data_for_all_viewers()
