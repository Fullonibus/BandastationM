/datum/ipc_os_program/pda
	/// One internal PDA retains messages while stopped, and is destroyed on uninstall.
	var/obj/item/modular_computer/pda/ipc_os/device

/datum/ipc_os_program/pda/Destroy()
	QDEL_NULL(device)
	return ..()

/datum/ipc_os_program/pda/start()
	if(!..())
		return FALSE
	os.capture_pda_job(os.host.mind?.assigned_role)
	if(!device)
		device = new(os.core, os)
	device.forceMove(os.host)
	device.enabled = TRUE
	device.imprint_id(os.host.real_name, os.pda_job_title || "КПБ")
	return TRUE

/datum/ipc_os_program/pda/stop()
	if(running && device)
		SStgui.close_uis(device)
		device.shutdown_computer(loud = FALSE)
		var/datum/computer_file/program/messenger/messenger = locate() in device.stored_files
		remove_messenger(messenger)
		device.forceMove(os.core)
	return ..()

/datum/ipc_os_program/pda/on_uninstall()
	QDEL_NULL(device)

/// Narrow human-compatible embedded PDA: reuse applications without IDs, money, pAI or a second cell.
/obj/item/modular_computer/pda/ipc_os
	name = "Digital PDA"
	icon = 'icons/obj/devices/modular_pda.dmi'
	icon_state = "pda-silicon-human"
	post_init_icon_state = null
	base_icon_state = "pda-silicon-human"
	greyscale_config = null
	greyscale_colors = null
	has_light = FALSE
	inserted_item = null
	internal_cell = null
	has_pda_programs = FALSE
	max_capacity = 64
	looping_sound = FALSE
	starting_programs = list(/datum/computer_file/program/messenger, /datum/computer_file/program/notepad, /datum/computer_file/program/crew_manifest, /datum/computer_file/program/ntnetdownload/ipc_os, /datum/computer_file/program/filemanager)
	/// Owning core's OS, never derived from the person trying to interact.
	var/datum/ipc_os/os

/obj/item/modular_computer/pda/ipc_os/Initialize(mapload, datum/ipc_os/os)
	src.os = os
	return ..()

/obj/item/modular_computer/pda/ipc_os/Destroy()
	os = null
	return ..()

/obj/item/modular_computer/pda/ipc_os/add_shell_component(capacity)
	return

/obj/item/modular_computer/pda/ipc_os/GetAccess()
	return os?.pda_job_access.Copy() || list()

/// Apply the exclusion policy at storage too, so forged downloads and file copies cannot bypass it.
/obj/item/modular_computer/pda/ipc_os/can_store_file(datum/computer_file/file)
	if(istype(file, /datum/computer_file/program))
		var/datum/computer_file/program/program = file
		if(!allowed_program(program) || !program.can_run(access = GetAccess(), downloading = TRUE))
			return FALSE
	return ..()

/obj/item/modular_computer/pda/ipc_os/proc/allowed_program(datum/computer_file/program/program)
	var/static/list/blocked = typecacheof(list(
		/datum/computer_file/program/faxbond,
		/datum/computer_file/program/nt_pay,
		/datum/computer_file/program/raptordex,
		/datum/computer_file/program/card_mod,
		/datum/computer_file/program/signal_commander,
		/datum/computer_file/program/betting,
		/datum/computer_file/program/secureye,
		/datum/computer_file/program/power_monitor,
		/datum/computer_file/program/bounty_board,
		/datum/computer_file/program/coupon,
		/datum/computer_file/program/shipping,
		/datum/computer_file/program/ai_restorer,
	))
	return program && !is_type_in_typecache(program, blocked) && program.is_supported_by_hardware(hardware_flag = hardware_flag, loud = FALSE)

/// Same native downloader UI and network transfer, scoped to this device's software policy.
/datum/computer_file/program/ntnetdownload/ipc_os

/datum/computer_file/program/ntnetdownload/ipc_os/check_compatibility(datum/computer_file/program/program_to_check)
	var/obj/item/modular_computer/pda/ipc_os/device = computer
	return istype(device) && device.allowed_program(program_to_check) && ..()

/datum/computer_file/program/ntnetdownload/ipc_os/begin_file_download(filename, mob/user)
	var/datum/computer_file/program/program = SSmodular_computers.find_ntnet_file_by_name(filename)
	if(!program || !(program in SSmodular_computers.available_station_software) || !check_compatibility(program) || !program.can_run(user, downloading = TRUE, access = computer.GetAccess()))
		return FALSE
	return ..()

/datum/computer_file/program/ntnetdownload/ipc_os/ui_data(mob/user)
	. = ..()
	var/list/visible_programs = list()
	for(var/list/row as anything in .["programs"])
		var/datum/computer_file/program/program = SSmodular_computers.find_ntnet_file_by_name(row["filename"])
		if((program in SSmodular_computers.available_station_software) && check_compatibility(program))
			visible_programs += list(row)
	.["programs"] = visible_programs

/obj/item/modular_computer/pda/ipc_os/check_power_override(amount)
	var/datum/ipc_os_program/program = os?.programs["pda"]
	return os?.is_operational() && program?.running

/obj/item/modular_computer/pda/ipc_os/ui_state(mob/user)
	return GLOB.deep_inventory_state

/obj/item/modular_computer/pda/ipc_os/ui_status(mob/user, datum/ui_state/state)
	var/datum/ipc_os_program/program = os?.programs["pda"]
	if(!os?.can_use(user) || !program?.running)
		return UI_CLOSE
	return ..()

/obj/item/modular_computer/pda/ipc_os/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(ui_status(ui.user, state) != UI_INTERACTIVE)
		return FALSE
	// These physical-device actions must not create a second identity or expose nonexistent hardware.
	if(action in list("PC_Imprint_ID", "PC_Eject_Disk", "PC_Pai_Interact", "PC_toggle_light", "PC_light_color"))
		return FALSE
	return ..()

/obj/item/modular_computer/pda/ipc_os/ui_static_data(mob/user)
	. = ..()
	.["show_imprint"] = FALSE

/obj/item/modular_computer/pda/ipc_os/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	return ITEM_INTERACT_BLOCKING
