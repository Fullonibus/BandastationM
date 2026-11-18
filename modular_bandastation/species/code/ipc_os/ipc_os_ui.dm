/datum/ipc_os/ui_state(mob/user)
	return GLOB.conscious_state

/datum/ipc_os/ui_host(mob/user)
	return host

/datum/ipc_os/ui_status(mob/user, datum/ui_state/state)
	return can_view(user) ? UI_INTERACTIVE : UI_CLOSE

/datum/ipc_os/ui_interact(mob/user, datum/tgui/ui)
	if(!can_view(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "IpcOS", "Positronic OS")
		ui.open()

/datum/ipc_os/ui_data(mob/user)
	var/list/catalog = list()
	for(var/id in programs)
		var/datum/ipc_os_program/program = programs[id]
		if(!program.available())
			continue
		catalog += list(list("id" = id, "name" = program.name, "description" = program.description, "icon" = program.icon, "size" = program.size, "illegal" = program.illegal, "installed" = program.installed, "running" = program.running, "passive" = program.passive, "ready" = program.ready))
	var/datum/ipc_os_program/signal_boost/signaler = programs["signal_boost"]
	var/datum/ipc_os_program/id_spoof/spoofer = programs["id_spoof"]
	var/list/data = list("programs" = catalog, "used" = used_storage(), "capacity" = capacity(), "charge" = round(100 * host.nutrition / NUTRITION_LEVEL_FULL, 0.1), "temperature" = round(host.coretemperature - T0C, 0.1), "error" = error_message, "frequency" = signaler.frequency, "code" = signaler.code, "minFrequency" = MIN_FREE_FREQ, "maxFrequency" = MAX_FREE_FREQ, "spoof_name" = spoofer.spoof_name, "spoof_job" = spoofer.spoof_job, "stunned" = !!host.IsStun())
	data["malware"] = list()
	data["can_manage"] = !!can_use(user)
	data["neural_available"] = !!can_neural_crack()
	data["neural_cooldown"] = ceil(COOLDOWN_TIMELEFT(src, neural_crack_cooldown) / (1 SECONDS))
	data["download_id"] = downloading?.id
	data["download_progress"] = downloading ? min(1, download_elapsed / max(2, downloading.size)) : 0
	for(var/id in infections)
		var/datum/ipc_os_malware/infection = infections[id]
		data["malware"] += list(list("id" = id, "name" = infection.name, "os_curable" = infection.os_curable, "treatments" = infection.treatments, "cleaning" = !!infection.clean_timer, "clean_seconds" = infection.clean_timer ? ceil(max(0, infection.clean_started_at + infection.clean_duration - world.time) / (1 SECONDS)) : 0, "clean_duration" = infection.clean_duration / (1 SECONDS)))
	var/datum/ipc_os_program/virus_kit/kit = programs["virus_kit"]
	data["selected_virus"] = kit.selected_virus
	data["armed"] = kit.armed
	data["virus_choices"] = list(list("id" = "display_glitch", "name" = "DisplayGlitch.v2"), list("id" = "sensor_noise", "name" = "SensorNoise.worm"), list("id" = "core_rot", "name" = "CoreRot.rootkit"), list("id" = "neural_hijack", "name" = "NeuralHijack.exploit"))
	data["hijack_targets"] = list()
	for(var/datum/weakref/target_ref as anything in kit.hijack_targets.Copy())
		var/obj/item/organ/brain/target_core = target_ref.resolve()
		if(!target_core)
			kit.hijack_targets -= target_ref
			continue
		var/datum/ipc_os/target_os = target_core.operating_system
		if(!target_os)
			kit.hijack_targets -= target_ref
			continue
		var/datum/ipc_os_malware/infection = target_os.infections["neural_hijack"]
		if(!target_os.host || infection?.source_core?.resolve() != core)
			continue
		var/can_control = target_os.is_operational() && GET_CLIENT(target_os.host) && !target_os.control_session
		data["hijack_targets"] += list(list("ref" = REF(target_core), "name" = target_os.host.name, "can_control" = !!can_control))
	return data

/datum/ipc_os/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "neural_crack")
		return can_view(ui.user) && neural_crack()
	if(!can_use(ui.user))
		return FALSE
	error_message = null
	switch(action)
		if("install")
			begin_download(params["id"])
		if("cancel_download")
			cancel_download()
		if("uninstall")
			uninstall(params["id"])
		if("toggle")
			if(!istext(params["id"]))
				return FALSE
			var/datum/ipc_os_program/program = programs[params["id"]]
			if(!program?.installed || program.passive || !program.ready)
				return FALSE
			if(program.running)
				program.stop()
			else if(!program.start())
				error_message = "Программа не может быть запущена."
		if("signal_freq", "signal_code", "signal_send")
			var/datum/ipc_os_program/signal_boost/signaler = programs["signal_boost"]
			signaler.command(action, params)
		if("pda_open")
			var/datum/ipc_os_program/pda/pda = programs["pda"]
			if(pda.running)
				pda.device.ui_interact(ui.user)
		if("spoof_text")
			var/datum/ipc_os_program/id_spoof/spoofer = programs["id_spoof"]
			if(!spoofer.installed || !istext(params["value"]))
				return FALSE
			var/value = strip_html(trim(copytext_char(params["value"], 1, MAX_NAME_LEN + 1)))
			if(params["field"] == "name" && length(value))
				spoofer.spoof_name = value
			else if(params["field"] == "job")
				spoofer.spoof_job = value
			if(spoofer.running)
				host.update_visible_name()
		if("virus_select", "virus_arm", "hijack_start")
			var/datum/ipc_os_program/virus_kit/kit = programs["virus_kit"]
			if(!kit.installed || !kit.running)
				return FALSE
			switch(action)
				if("virus_select")
					if(istext(params["id"]) && virus_type(params["id"]))
						kit.selected_virus = params["id"]
						kit.armed = FALSE
				if("virus_arm")
					kit.armed = !kit.armed
				if("hijack_start")
					for(var/datum/weakref/target_ref as anything in kit.hijack_targets)
						var/obj/item/organ/brain/target_core = target_ref.resolve()
						if(!target_core?.operating_system || REF(target_core) != params["ref"])
							continue
						var/datum/ipc_os_control/session = new(src, target_core.operating_system)
						if(!session.start())
							error_message = "Удалённое управление недоступно: проверьте состояние КПБ."
							qdel(session)
						break
		if("cure_virus")
			if(!begin_cure(params["id"]))
				error_message = "Очистка уже идёт или заражение требует нейронной отладки мультитулом."
	return TRUE
