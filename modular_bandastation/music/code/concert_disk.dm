/** Remove orphaned round-local recordings after a shutdown or crash. */
/datum/modpack/music/initialize()
	. = ..()
	for(var/file_name in flist("data/"))
		if(findtext(file_name, "concert_") == 1 && copytext(file_name, -4) == ".ogg")
			fdel("data/[file_name]")

/** A round-local audio recording owned by a physical disk, never by its player. */
/datum/track/concert_recording
	/// Private backing file removed together with this recording.
	var/upload_path
	/// Size used to enforce the disk's aggregate capacity.
	var/byte_size = 0

/datum/track/concert_recording/Destroy()
	song_path = null
	if(upload_path)
		fdel(upload_path)
		upload_path = null
	return ..()

/** Rewritable concert media; only an active Musician can modify its contents. */
/obj/item/concert_disk
	name = "rewritable music disk"
	desc = "A blank concert disk. A Musician can record OGG tracks using a concert player."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "tape_greyscale"
	w_class = WEIGHT_CLASS_SMALL
	/// Recordings owned by this disk, in playback-menu order.
	var/list/datum/track/concert_recording/tracks = list()
	/// Total committed file bytes.
	var/used_bytes = 0
	/// Serializes uploads while sound-length detection yields.
	var/recording = FALSE
	/// Rate limit applies to the medium, not to one UI session.
	var/next_upload = 0

/obj/item/concert_disk/Destroy()
	QDEL_LIST(tracks)
	return ..()

/obj/item/concert_disk/examine(mob/user)
	. = ..()
	. += span_notice("[length(tracks)]/[CONCERT_DISK_MAX_TRACKS] tracks; [round(used_bytes / (1024 * 1024), 0.01)]/50 MiB. Recordings last for this round.")

/** Revalidate physical custody and profession at each side of an upload yield. */
/obj/item/concert_disk/proc/can_write(mob/user, obj/machinery/concert_player/player)
	return !QDELETED(src) && !QDELETED(player) && is_music_artist(user) && player.can_use(user) && loc == player && player.inserted_disk == src

/** Stage a file, probe it, then commit only if the actor still owns the interaction. */
/obj/item/concert_disk/proc/record_track(upload, mob/user, obj/machinery/concert_player/player)
	if(!can_write(user, player) || recording || world.time < next_upload)
		return FALSE
	if(!is_valid_music_upload(upload) || length(tracks) >= CONCERT_DISK_MAX_TRACKS || used_bytes + length(upload) > CONCERT_DISK_MAX_BYTES)
		to_chat(user, span_warning("Use an OGG up to 10 MiB; a disk holds 12 tracks and 50 MiB total."))
		return FALSE
	recording = TRUE
	next_upload = world.time + 10 SECONDS
	var/datum/track/concert_recording/track = new
	track.upload_path = "data/concert_[REF(track)].ogg"
	if(!fcopy(upload, track.upload_path))
		recording = FALSE
		qdel(track)
		return FALSE
	var/duration = get_music_upload_duration(track.upload_path)
	recording = FALSE
	if(!can_write(user, player) || !is_valid_music_duration(duration))
		if(can_write(user, player))
			to_chat(user, span_warning("The recording has an invalid duration or exceeds 30 minutes."))
		qdel(track)
		return FALSE
	track.song_path = file(track.upload_path)
	track.song_name = SANITIZE_FILENAME("[upload]")
	track.song_length = duration
	track.byte_size = length(upload)
	tracks += track
	used_bytes += track.byte_size
	if(!player.selected_track)
		player.selected_track = track
	log_game("[key_name(user)] recorded [track.song_name] ([track.byte_size] bytes) on [src] at [AREACOORD(player)].")
	SStgui.update_uis(player)
	return TRUE

/** Change only metadata belonging to a recording currently on this disk. */
/obj/item/concert_disk/proc/edit_track(action, datum/track/concert_recording/track, value, mob/user, obj/machinery/concert_player/player)
	if(!can_write(user, player) || recording || !(track in tracks))
		return FALSE
	switch(action)
		if("rename")
			if(!istext(value))
				return FALSE
			var/title = trim(copytext_char(strip_html(value), 1, 81))
			if(!length(title))
				return FALSE
			track.song_name = title
		if("remove")
			if(player.selected_track == track)
				player.song.clear_file_track()
				player.selected_track = null
			tracks -= track
			used_bytes -= track.byte_size
			qdel(track)
			if(!player.selected_track && length(tracks))
				player.selected_track = tracks[1]
		if("move")
			if(!isnum(value) || !(value in list(-1, 1)))
				return FALSE
			var/index = tracks.Find(track)
			var/destination = index + value
			if(destination < 1 || destination > length(tracks))
				return FALSE
			tracks.Swap(index, destination)
		else
			return FALSE
	return TRUE
