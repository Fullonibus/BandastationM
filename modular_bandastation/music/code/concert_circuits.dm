/** A manually installed master owns the remote and the stage's transport interface. */
/obj/item/circuit_component/concert_master
	display_name = "Concert Master"
	desc = "Controls a concert player's recorded disk and reports playback state."
	category = "Action"
	circuit_flags = CIRCUIT_NO_DUPLICATES|CIRCUIT_FLAG_REFUSE_MODULE
	required_shells = list(/obj/machinery/concert_player)
	/// Physical linking remote supplied inside this component.
	var/obj/item/concert_remote/remote
	/// Explicit transport inputs, separate from volume and selection updates.
	var/datum/port/input/start
	var/datum/port/input/stop
	/// One-based recording index on the inserted disk.
	var/datum/port/input/track_number
	/// Gain bounded to the same range as the manual controls.
	var/datum/port/input/volume
	/// Current title and transport state for other stage circuits.
	var/datum/port/output/track_name
	var/datum/port/output/is_playing
	var/datum/port/output/started_playing
	var/datum/port/output/stopped_playing
	/// Player hosting this component, valid only while the circuit is installed.
	var/obj/machinery/concert_player/player
	/// Signal source retained until unregister_shell, even during component deletion.
	var/obj/item/integrated_circuit/registered_circuit
	/// COMSIG_CIRCUIT_SET_ON precedes assignment to the circuit's on field.
	var/circuit_enabled = FALSE

/obj/item/circuit_component/concert_master/Initialize(mapload)
	. = ..()
	remote = new(src, src)

/obj/item/circuit_component/concert_master/Destroy()
	disconnect_player()
	QDEL_NULL(remote)
	return ..()

/obj/item/circuit_component/concert_master/attack_self(mob/user)
	if(QDELETED(remote) || remote.loc != src)
		balloon_alert(user, "remote already removed")
		return
	if(!user.put_in_active_hand(remote))
		remote.forceMove(drop_location())

/obj/item/circuit_component/concert_master/attackby(obj/item/item, mob/user, list/modifiers)
	if(!istype(item, /obj/item/concert_remote))
		return ..()
	if(item != remote)
		balloon_alert(user, "wrong remote")
		return TRUE
	user.transferItemToLoc(item, src)
	return TRUE

/obj/item/circuit_component/concert_master/populate_ports()
	start = add_input_port("Play", PORT_TYPE_SIGNAL)
	stop = add_input_port("Stop", PORT_TYPE_SIGNAL)
	track_number = add_input_port("Track", PORT_TYPE_NUMBER, default = 1)
	volume = add_input_port("Volume", PORT_TYPE_NUMBER, default = 75)
	track_name = add_output_port("Track Name", PORT_TYPE_STRING)
	is_playing = add_output_port("Is Playing", PORT_TYPE_BOOLEAN)
	started_playing = add_output_port("Started Playing", PORT_TYPE_SIGNAL)
	stopped_playing = add_output_port("Stopped Playing", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/concert_master/register_shell(atom/movable/shell)
	. = ..()
	if(!istype(shell, /obj/machinery/concert_player))
		return
	var/obj/machinery/concert_player/new_player = shell
	if(new_player.master_component && new_player.master_component != src)
		return
	player = new_player
	player.master_component = src
	registered_circuit = parent
	circuit_enabled = parent.on
	RegisterSignal(registered_circuit, COMSIG_CIRCUIT_SET_ON, PROC_REF(on_power_changed))
	RegisterSignal(player, COMSIG_INSTRUMENT_START, PROC_REF(on_started))
	RegisterSignal(player, COMSIG_INSTRUMENT_END, PROC_REF(on_stopped))
	update_outputs()
	remote?.refresh_receivers()
	player.update_appearance()

/obj/item/circuit_component/concert_master/unregister_shell(atom/movable/shell)
	disconnect_player()
	return ..()

/** Drop external sources before releasing the master; remote bindings stay on the remote. */
/obj/item/circuit_component/concert_master/proc/disconnect_player()
	if(registered_circuit)
		UnregisterSignal(registered_circuit, COMSIG_CIRCUIT_SET_ON)
	registered_circuit = null
	circuit_enabled = FALSE
	var/obj/machinery/concert_player/old_player = player
	if(player)
		UnregisterSignal(player, list(COMSIG_INSTRUMENT_START, COMSIG_INSTRUMENT_END))
		if(player.master_component == src)
			player.master_component = null
	player = null
	remote?.refresh_receivers()
	update_outputs()
	if(!QDELETED(old_player))
		old_player.refresh_sources()
		old_player.update_appearance()

/obj/item/circuit_component/concert_master/input_received(datum/port/input/port)
	if(QDELETED(player))
		return
	if(COMPONENT_TRIGGERED_BY(stop, port))
		player.stop_music()
		return
	if(CONFIG_GET(flag/disallow_circuit_sounds))
		return
	if(port == volume && isnum(volume.value))
		player.song.set_volume(volume.value)
	if(port == track_number && isnum(track_number.value))
		var/index = round(track_number.value)
		if(index >= 1 && index <= length(player.inserted_disk?.tracks))
			player.stop_music()
			player.selected_track = player.inserted_disk.tracks[index]
	if(COMPONENT_TRIGGERED_BY(start, port))
		player.play_music()
	update_outputs()

/obj/item/circuit_component/concert_master/proc/on_power_changed(datum/source, new_value)
	SIGNAL_HANDLER
	circuit_enabled = new_value
	remote?.refresh_receivers()

/obj/item/circuit_component/concert_master/proc/on_started()
	SIGNAL_HANDLER
	update_outputs()
	remote?.refresh_receivers()
	started_playing.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/concert_master/proc/on_stopped()
	SIGNAL_HANDLER
	update_outputs()
	remote?.refresh_receivers()
	stopped_playing.set_output(COMPONENT_SIGNAL)

/** Publish state without restarting or mutating the recording. */
/obj/item/circuit_component/concert_master/proc/update_outputs()
	track_name.set_output(player?.selected_track?.song_name)
	is_playing.set_output(!!player?.song?.playing)

/** A receiver created by its remote in an editable integrated circuit. */
/obj/item/circuit_component/concert_listener
	display_name = "Concert Speaker Receiver"
	desc = "Receives a linked concert player's audio and transport signals."
	category = "Action"
	circuit_flags = CIRCUIT_NO_DUPLICATES|CIRCUIT_FLAG_REFUSE_MODULE
	/// Per-source attenuation, never amplification above transmitter volume.
	var/datum/port/input/gain
	/// Playback state and transport edges for stage lighting.
	var/datum/port/output/is_playing
	var/datum/port/output/started_playing
	var/datum/port/output/stopped_playing
	/// Remote owning this link, whether or not its master is currently installed.
	var/datum/weakref/remote_ref
	/// Shell reference valid only between register_shell and unregister_shell.
	var/atom/movable/receiver_shell
	/// Registered signal source; parent can be cleared before unregister_shell on deletion.
	var/obj/item/integrated_circuit/registered_circuit
	/// Cached circuit state because the power signal precedes field assignment.
	var/circuit_enabled = FALSE
	/// Last published playback state.
	var/playing = FALSE

/obj/item/circuit_component/concert_listener/populate_ports()
	gain = add_input_port("Volume", PORT_TYPE_NUMBER, default = 100)
	is_playing = add_output_port("Is Playing", PORT_TYPE_BOOLEAN)
	started_playing = add_output_port("Started Playing", PORT_TYPE_SIGNAL)
	stopped_playing = add_output_port("Stopped Playing", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/concert_listener/register_shell(atom/movable/shell)
	. = ..()
	receiver_shell = shell
	registered_circuit = parent
	circuit_enabled = parent.on
	RegisterSignal(registered_circuit, COMSIG_CIRCUIT_SET_ON, PROC_REF(on_power_changed))
	RegisterSignal(shell, COMSIG_MOVABLE_MOVED, PROC_REF(on_source_changed))
	RegisterSignal(shell, COMSIG_MOVABLE_SET_ANCHORED, PROC_REF(on_source_changed))
	on_source_changed()

/obj/item/circuit_component/concert_listener/unregister_shell(atom/movable/shell)
	UnregisterSignal(registered_circuit, COMSIG_CIRCUIT_SET_ON)
	UnregisterSignal(shell, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_SET_ANCHORED))
	if(istype(receiver_shell, /obj/structure/concertspeaker))
		var/obj/structure/concertspeaker/speaker = receiver_shell
		speaker.active = FALSE
		speaker.is_synced = FALSE
		speaker.update_appearance()
	registered_circuit = null
	receiver_shell = null
	circuit_enabled = FALSE
	on_source_changed()
	return ..()

/obj/item/circuit_component/concert_listener/removed_from(obj/item/integrated_circuit/removed_from)
	set_remote(null)
	return ..()

/obj/item/circuit_component/concert_listener/Destroy()
	set_remote(null)
	return ..()

/obj/item/circuit_component/concert_listener/pre_input_received(datum/port/input/port)
	gain.set_value(isnum(gain.value) ? clamp(round(gain.value), 0, 100) : 0)

/obj/item/circuit_component/concert_listener/input_received(datum/port/input/port)
	on_source_changed()

/** Resolve the transmitter through the owning remote and its installed master. */
/obj/item/circuit_component/concert_listener/proc/get_source()
	var/obj/item/concert_remote/remote = remote_ref?.resolve()
	var/obj/machinery/concert_player/player = remote?.get_player()
	if(!player || QDELETED(receiver_shell) || !circuit_enabled || parent?.shell != receiver_shell || gain.value <= 0)
		return null
	if(istype(receiver_shell, /obj/structure/concertspeaker) && !receiver_shell.anchored)
		return null
	if(isitem(receiver_shell) && !isturf(receiver_shell.loc))
		var/mob/living/holder = receiver_shell.loc
		if(!istype(holder) || !holder.is_holding(receiver_shell))
			return null
	if(!get_turf(player) || !get_turf(receiver_shell))
		return null
	return receiver_shell

/** Rebind without retaining the previous remote or bypassing the receiver limit. */
/obj/item/circuit_component/concert_listener/proc/set_remote(obj/item/concert_remote/new_remote)
	var/obj/item/concert_remote/old_remote = remote_ref?.resolve()
	if(new_remote && new_remote == old_remote)
		return TRUE
	if(new_remote && (QDELETED(new_remote) || length(new_remote.receivers) >= CONCERT_MAX_RECEIVERS))
		return FALSE
	var/obj/machinery/concert_player/old_player = old_remote?.get_player()
	if(old_remote)
		old_remote.receivers -= src
	remote_ref = new_remote ? WEAKREF(new_remote) : null
	if(new_remote)
		new_remote.receivers |= src
	update_state()
	if(!QDELETED(old_player))
		old_player.refresh_sources()
	var/obj/machinery/concert_player/new_player = new_remote?.get_player()
	if(new_player && new_player != old_player)
		new_player.refresh_sources()
	return TRUE

/obj/item/circuit_component/concert_listener/proc/on_power_changed(datum/source, new_value)
	SIGNAL_HANDLER
	circuit_enabled = new_value
	on_source_changed()

/obj/item/circuit_component/concert_listener/proc/on_source_changed()
	SIGNAL_HANDLER
	update_state()
	var/obj/item/concert_remote/remote = remote_ref?.resolve()
	var/obj/machinery/concert_player/player = remote?.get_player()
	player?.refresh_sources()

/** Update shell visuals and emit only actual transport transitions. */
/obj/item/circuit_component/concert_listener/proc/update_state()
	var/obj/item/concert_remote/remote = remote_ref?.resolve()
	var/obj/machinery/concert_player/player = remote?.get_player()
	var/new_state = !!player?.song?.playing && !!get_source()
	if(playing != new_state)
		playing = new_state
		is_playing.set_output(playing)
		if(playing)
			started_playing.set_output(COMPONENT_SIGNAL)
		else
			stopped_playing.set_output(COMPONENT_SIGNAL)
	if(istype(receiver_shell, /obj/structure/concertspeaker))
		var/obj/structure/concertspeaker/speaker = receiver_shell
		speaker.active = playing
		speaker.is_synced = !!player
		speaker.update_appearance()

/** Physical remote owned by one master component, as in the source concert system. */
/obj/item/concert_remote
	name = "concert linking remote"
	desc = "A linking remote belonging to a concert master component."
	icon = 'icons/obj/devices/remote.dmi'
	icon_state = "shuttleremote"
	/// Component which supplied this remote; never changed by clicking another player.
	var/datum/weakref/owner_ref
	/// Receivers created and bound using this remote.
	var/list/obj/item/circuit_component/concert_listener/receivers = list()

/obj/item/concert_remote/Initialize(mapload, obj/item/circuit_component/concert_master/owner)
	. = ..()
	if(owner)
		owner_ref = WEAKREF(owner)

/obj/item/concert_remote/Destroy()
	for(var/obj/item/circuit_component/concert_listener/receiver as anything in receivers.Copy())
		receiver.set_remote(null)
	receivers.Cut()
	var/obj/item/circuit_component/concert_master/owner = owner_ref?.resolve()
	if(owner?.remote == src)
		owner.remote = null
	owner?.player?.refresh_sources()
	owner_ref = null
	return ..()

/** A loose or powered-off master cannot relay, but it retains its saved receiver links. */
/obj/item/concert_remote/proc/get_player()
	var/obj/item/circuit_component/concert_master/owner = owner_ref?.resolve()
	var/obj/machinery/concert_player/player = owner?.player
	if(QDELETED(src) || QDELETED(owner) || owner.remote != src || QDELETED(player))
		return null
	if(player.master_component != owner || owner.registered_circuit?.shell != player || !owner.circuit_enabled)
		return null
	return player

/** Push transport state to receivers and immediately refresh the player's audible sources. */
/obj/item/concert_remote/proc/refresh_receivers()
	for(var/obj/item/circuit_component/concert_listener/receiver as anything in receivers)
		receiver.update_state()
	var/obj/item/circuit_component/concert_master/owner = owner_ref?.resolve()
	owner?.player?.refresh_sources()

/obj/item/concert_remote/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	if(istype(target, /obj/item/circuit_component/concert_master))
		return NONE
	if(!user.Adjacent(target) || !user.can_perform_action(src, NEED_DEXTERITY))
		return ITEM_INTERACT_BLOCKING
	var/obj/item/circuit_component/concert_master/owner = owner_ref?.resolve()
	if(QDELETED(owner) || owner.remote != src)
		balloon_alert(user, "no master component")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/integrated_circuit/circuit
	if(istype(target, /obj/item/integrated_circuit))
		circuit = target
	else
		var/datum/component/shell/shell = target.GetComponent(/datum/component/shell)
		circuit = shell?.attached_circuit
	if(!circuit || circuit.locked)
		balloon_alert(user, "no unlocked circuit")
		return ITEM_INTERACT_BLOCKING
	for(var/obj/item/circuit_component/concert_listener/existing in circuit.attached_components)
		if(!existing.removable)
			return ITEM_INTERACT_BLOCKING
		circuit.remove_component(existing)
		qdel(existing)
		balloon_alert(user, "unlinked")
		return ITEM_INTERACT_SUCCESS
	if(length(receivers) >= CONCERT_MAX_RECEIVERS)
		balloon_alert(user, "receiver limit")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/circuit_component/concert_listener/receiver = new
	if(!circuit.add_component_manually(receiver))
		qdel(receiver)
		return ITEM_INTERACT_BLOCKING
	receiver.set_remote(src)
	balloon_alert(user, "linked")
	return ITEM_INTERACT_SUCCESS
