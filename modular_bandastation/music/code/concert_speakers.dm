/** Portable stage speaker with an editable receiver circuit. */
/obj/structure/concertspeaker
	name = "concert speaker"
	desc = "A stage speaker with an integrated-circuit receiver. Secure it before playback."
	icon = 'modular_bandastation/music/icons/concert.dmi'
	icon_state = "concertspeaker_unanchored"
	anchored = FALSE
	density = FALSE
	max_integrity = 250
	/// Receiver-driven visual state, cleared when the circuit is detached.
	var/active = FALSE
	/// Whether this speaker has a bound transmitter.
	var/is_synced = FALSE

/obj/structure/concertspeaker/Initialize(mapload, obj/item/integrated_circuit/transferred_circuit)
	. = ..()
	AddComponent(/datum/component/shell, list(), SHELL_CAPACITY_SMALL, NONE, transferred_circuit)

/obj/structure/concertspeaker/update_icon_state()
	. = ..()
	icon_state = "concertspeaker[anchored ? "" : "_unanchored"]"

/obj/structure/concertspeaker/update_overlays()
	. = ..()
	if(active && anchored)
		. += mutable_appearance(icon, "song_act1")
		. += mutable_appearance(icon, "song_act2")
		. += mutable_appearance(icon, "song_act3a")
	if(anchored)
		. += mutable_appearance(icon, is_synced ? "synced" : "asynced")

/obj/structure/concertspeaker/wrench_act(mob/living/user, obj/item/tool)
	var/result = default_unfasten_wrench(user, tool)
	if(result == SUCCESSFUL_UNFASTEN)
		density = anchored
		update_appearance()
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/structure/concertspeaker/attackby(obj/item/item, mob/user, list/modifiers)
	if(!istype(item, /obj/item/concert_master))
		return ..()
	if(!anchored || !user.transferItemToLoc(item, src))
		return TRUE
	var/datum/component/shell/shell = GetComponent(/datum/component/shell)
	var/obj/item/integrated_circuit/board = shell.attached_circuit
	if(board)
		shell.remove_circuit()
	var/obj/machinery/concert_player/player = new(drop_location(), board)
	player.setDir(dir)
	qdel(item)
	qdel(src)
	return TRUE

/** Upgrade module returned when a concert player is disassembled. */
/obj/item/concert_master
	name = "concert controller module"
	desc = "Fits onto a secured concert speaker to build a disk player."
	icon = 'modular_bandastation/music/icons/concert.dmi'
	icon_state = "djstance"
	w_class = WEIGHT_CLASS_BULKY

/** Flat-packed speaker; unpacking creates the actual shell on the floor. */
/obj/item/packed_concertspeaker
	name = "packed concert speaker"
	desc = "A portable stage speaker ready to unpack."
	icon = 'modular_bandastation/music/icons/concert.dmi'
	icon_state = "concertspeaker"
	w_class = WEIGHT_CLASS_BULKY

/obj/item/packed_concertspeaker/attack_self(mob/user)
	if(!isturf(user.loc) || !user.can_perform_action(src, NEED_DEXTERITY))
		return
	var/obj/structure/concertspeaker/speaker = new(user.loc)
	speaker.setDir(user.dir)
	qdel(src)

/** The source PR sells speakers separately from the controller module and circuit. */
/datum/supply_pack/goody/concert_speaker
	name = "Concert Speaker"
	desc = "One packed concert speaker."
	access = NONE
	group = "Imports"
	cost = CARGO_CRATE_VALUE * 0.5
	crate_name = "concert speaker crate"
	discountable = SUPPLY_PACK_NOT_DISCOUNTABLE
	contains = list(/obj/item/packed_concertspeaker)

/datum/supply_pack/goody/concert_controller
	name = "Concert Controller"
	desc = "A controller upgrade and its master component with a linking remote."
	access = NONE
	group = "Imports"
	cost = CARGO_CRATE_VALUE * 1.5
	crate_name = "concert controller crate"
	discountable = SUPPLY_PACK_NOT_DISCOUNTABLE
	contains = list(/obj/item/concert_master, /obj/item/circuit_component/concert_master, /obj/item/packed_concertspeaker)

/datum/supply_pack/service/concert_disks
	name = "Blank Music Disks"
	desc = "Three empty rewritable disks. Recording requires a Musician."
	cost = CARGO_CRATE_VALUE * 1
	crate_name = "blank music disk crate"
	contains = list(/obj/item/concert_disk, /obj/item/concert_disk, /obj/item/concert_disk)
