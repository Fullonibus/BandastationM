/** Disk player and concert transmitter, adapted from BandaStation PR #2251. */
/obj/machinery/concert_player
	name = "concert player"
	desc = "A concert controller with a rewritable disk drive and an integrated-circuit shell."
	icon = 'modular_bandastation/music/icons/concert.dmi'
	icon_state = "concertmaster"
	density = TRUE
	anchored = TRUE
	max_integrity = 250
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.1
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 0.1
	processing_flags = START_PROCESSING_MANUALLY
	/// Playback engine owns channels, but never the disk's backing files.
	var/datum/song/concert/song
	/// Physical medium currently providing the track library.
	var/obj/item/concert_disk/inserted_disk
	/// Borrowed recording; cleared before ejecting or destroying its disk.
	var/datum/track/concert_recording/selected_track
	/// Installed circuit component supplying the stage's remote and receivers.
	var/obj/item/circuit_component/concert_master/master_component
	/// Prevent parallel file chooser dialogs from this player.
	var/upload_pending = FALSE
	/// Throttle repeated start/stop circuit signals without delaying stop.
	var/next_start = 0

/obj/machinery/concert_player/Initialize(mapload, obj/item/integrated_circuit/transferred_circuit)
	. = ..()
	song = new(src)
	AddComponent(/datum/component/shell, list(), SHELL_CAPACITY_SMALL, NONE, transferred_circuit)
	RegisterSignal(src, COMSIG_INSTRUMENT_START, PROC_REF(on_playback_changed))
	RegisterSignal(src, COMSIG_INSTRUMENT_END, PROC_REF(on_playback_changed))

/obj/machinery/concert_player/Destroy()
	QDEL_NULL(song)
	master_component?.disconnect_player()
	master_component = null
	eject_disk()
	return ..()

/obj/machinery/concert_player/examine(mob/user)
	. = ..()
	. += span_notice("Insert a music disk. Use a concert remote to link speakers; crowbar the controller off when it is unfastened.")

/** Physical UI boundary shared by writes and public playback controls. */
/obj/machinery/concert_player/proc/can_use(mob/user)
	return !QDELETED(src) && !QDELETED(user) && isliving(user) && user.Adjacent(src) && user.can_perform_action(src, NEED_DEXTERITY) && anchored && is_operational

/** A disk is required; no config tracks or fallback music are loaded. */
/obj/machinery/concert_player/proc/can_play()
	return anchored && is_operational && !QDELETED(inserted_disk) && inserted_disk.loc == src && (selected_track in inserted_disk.tracks)

/** Only a master installed in this player's circuit may provide external sources. */
/obj/machinery/concert_player/proc/get_receivers()
	var/obj/item/concert_remote/remote = master_component?.remote
	if(remote?.get_player() == src)
		return remote.receivers
	return list()

/** Public start entry point, also used by circuits; it cannot write media. */
/obj/machinery/concert_player/proc/play_music()
	if(!can_play() || song.playing || world.time < next_start)
		return FALSE
	next_start = world.time + 1 SECONDS
	song.start_playing(src)
	return song.playing

/** Stop and release the allocated channel, including before an eject. */
/obj/machinery/concert_player/proc/stop_music()
	song?.stop_playing()

/obj/machinery/concert_player/proc/on_playback_changed()
	SIGNAL_HANDLER
	update_use_power(song?.playing ? ACTIVE_POWER_USE : IDLE_POWER_USE)
	update_appearance()
	SStgui.update_uis(src)

/obj/machinery/concert_player/update_overlays()
	. = ..()
	if(song?.playing)
		. += mutable_appearance(icon, "song_act1")
		. += mutable_appearance(icon, "song_act2")
		. += mutable_appearance(icon, "song_act3b")
	. += mutable_appearance(icon, inserted_disk ? "playing" : "standby")
	. += mutable_appearance(icon, master_component ? "synced" : "asynced")

/obj/machinery/concert_player/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		stop_music()

/obj/machinery/concert_player/wrench_act(mob/living/user, obj/item/tool)
	var/result = default_unfasten_wrench(user, tool)
	if(result == SUCCESSFUL_UNFASTEN)
		if(!anchored)
			stop_music()
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/concert_player/crowbar_act(mob/living/user, obj/item/tool)
	if(anchored)
		return ITEM_INTERACT_BLOCKING
	stop_music()
	eject_disk(user)
	var/datum/component/shell/shell = GetComponent(/datum/component/shell)
	var/obj/item/integrated_circuit/board = shell.attached_circuit
	if(board)
		shell.remove_circuit()
	var/obj/structure/concertspeaker/speaker = new(drop_location(), board)
	speaker.setDir(dir)
	new /obj/item/concert_master(drop_location())
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/concert_player/attackby(obj/item/item, mob/user, list/modifiers)
	if(istype(item, /obj/item/concert_disk))
		insert_disk(item, user)
		return TRUE
	return ..()

/obj/machinery/concert_player/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return
	if(user.Adjacent(src) && user.can_perform_action(src, NEED_DEXTERITY))
		eject_disk(user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/** Transfer only a disk the actor can actually release, preserving item restrictions. */
/obj/machinery/concert_player/proc/insert_disk(obj/item/concert_disk/disk, mob/user)
	if(!can_use(user) || inserted_disk || QDELETED(disk) || !user.transferItemToLoc(disk, src))
		return FALSE
	inserted_disk = disk
	selected_track = length(disk.tracks) ? disk.tracks[1] : null
	RegisterSignal(disk, COMSIG_MOVABLE_MOVED, PROC_REF(on_disk_removed))
	RegisterSignal(disk, COMSIG_QDELETING, PROC_REF(on_disk_removed))
	update_appearance()
	SStgui.update_uis(src)
	return TRUE

/obj/machinery/concert_player/proc/on_disk_removed(datum/source)
	SIGNAL_HANDLER
	if(QDELETED(source) || inserted_disk?.loc != src)
		eject_disk()

/** Release borrowed data before moving the medium; a forced removal does not teleport it. */
/obj/machinery/concert_player/proc/eject_disk(mob/user)
	if(!inserted_disk)
		return
	stop_music()
	var/obj/item/concert_disk/disk = inserted_disk
	UnregisterSignal(disk, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	inserted_disk = null
	selected_track = null
	if(song)
		song.clear_file_track()
	if(!QDELETED(disk) && disk.loc == src && (!user || !user.put_in_active_hand(disk)))
		disk.forceMove(drop_location())
	if(!QDELING(src))
		update_appearance()
		SStgui.update_uis(src)

/obj/machinery/concert_player/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ConcertPlayer220", name)
		ui.open()

/obj/machinery/concert_player/ui_data(mob/user)
	var/list/track_data = list()
	for(var/datum/track/concert_recording/track as anything in inserted_disk?.tracks)
		track_data += list(list("ref" = REF(track), "name" = track.song_name, "duration" = round(track.song_length / (1 SECONDS), 0.01), "selected" = selected_track == track))
	var/list/receiver_data = list()
	for(var/obj/item/circuit_component/concert_listener/receiver as anything in get_receivers())
		receiver_data += list(list("ref" = REF(receiver), "name" = receiver.receiver_shell?.name, "volume" = receiver.gain.value, "active" = !!receiver.get_source()))
	return list(
		"disk" = inserted_disk?.name,
		"tracks" = track_data,
		"used_mib" = round((inserted_disk?.used_bytes || 0) / (1024 * 1024), 0.01),
		"can_write" = inserted_disk?.can_write(user, src),
		"busy" = upload_pending || inserted_disk?.recording,
		"upload_cooldown" = max(0, ceil(((inserted_disk?.next_upload || 0) - world.time) / (1 SECONDS))),
		"playing" = song.playing,
		"volume" = song.volume,
		"loop" = song.auto_repeat,
		"receivers" = receiver_data,
		"operational" = is_operational && anchored,
	)

/obj/machinery/concert_player/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!can_use(user))
		return FALSE
	switch(action)
		if("play")
			if(song.playing)
				stop_music()
			else
				play_music()
		if("eject")
			eject_disk(user)
		if("volume")
			if(!isnum(params["value"]))
				return FALSE
			song.set_volume(params["value"])
		if("loop")
			song.set_auto_repeat(!song.auto_repeat)
		if("receiver_volume")
			var/obj/item/circuit_component/concert_listener/receiver = locate(params["ref"]) in get_receivers()
			if(!receiver || !isnum(params["value"]))
				return FALSE
			receiver.gain.set_input(clamp(round(params["value"]), 0, 100))
			refresh_sources()
		if("select")
			var/datum/track/concert_recording/track = locate(params["ref"]) in inserted_disk?.tracks
			if(!track)
				return FALSE
			stop_music()
			selected_track = track
		if("upload")
			if(upload_pending || !inserted_disk?.can_write(user, src))
				return FALSE
			var/obj/item/concert_disk/disk = inserted_disk
			upload_pending = TRUE
			var/upload = input(user, "Select an OGG to record on the inserted disk.", name) as sound|null
			if(!QDELETED(src))
				upload_pending = FALSE
			if(!QDELETED(disk) && disk.can_write(user, src))
				disk.record_track(upload, user, src)
		if("rename", "remove", "move")
			var/datum/track/concert_recording/track = locate(params["ref"]) in inserted_disk?.tracks
			return inserted_disk?.edit_track(action, track, params["value"], user, src)
		else
			return FALSE
	return TRUE
