/// Check the active profession rather than an item, displayed title, or ID card.
/datum/song/proc/can_use_advanced_music(atom/user)
	var/mob/living/player = user
	return istype(player) && istype(player.mind?.assigned_role, /datum/job/donor/musician)

/// UI actions remain guarded even if a client forges a disabled tab or upload.
/datum/song/proc/authorize_music_action(action, list/params, mob/user)
	var/advanced = (action in list("open_piano_roll", "upload_music_document", "set_sequence_document", "set_song_cues", "sequence_channel", "sequence_seek", "auto_sing", "singing_tts", "import_file_song", "clear_file_song", "select_loaded_file_track", "set_file_track_length", "remove_file_track"))
	if(action in list("select_music_mode", "set_playback_mode", "play_music"))
		advanced = (params["mode"] in list("sequence", "file"))
	if(!advanced || can_use_advanced_music(user))
		return TRUE
	to_chat(user, span_warning("Extended music controls require the Musician profession."))
	return FALSE
