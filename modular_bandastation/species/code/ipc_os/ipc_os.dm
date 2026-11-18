/// Software belongs to the existing personality core, not its replaceable chassis.
/datum/ipc_os
	/// The one existing core which owns this OS.
	var/obj/item/organ/brain/core
	/// Current compatible chassis; cleared before organ removal.
	var/mob/living/carbon/human/host
	/// Catalog instances are private to this core. Installation never duplicates a program.
	var/list/datum/ipc_os_program/programs = list()
	/// Full unlock is separate from the limited software license.
	var/emag_unlocked = FALSE
	/// The market license grants three programs without extra capacity.
	var/limited_unlocked = FALSE
	/// UI action owned by this OS.
	var/datum/action/innate/ipc_os/open_action
	/// Last server rejection, displayed even if a client submits a stale action.
	var/error_message
	/// Unique persistent infections, keyed by the closed virus identifier.
	var/list/datum/ipc_os_malware/infections = list()
	/// The same session reserves both participating personality cores.
	var/datum/ipc_os_control/control_session
	/// One native processing reservation for an unfinished NET download.
	var/datum/ipc_os_program/downloading
	/// Elapsed seconds at one GB per second, with a two-second minimum download.
	var/download_elapsed = 0
	/// Initial profession is independent of subsequent ID swaps, spoofing and promotions.
	var/pda_job_title
	/// Private copy of native job-trim access, usable only by internal PDA applications.
	var/list/pda_job_access = list()
	/// Core-owned so reinstalling NeuralCrack cannot bypass recovery time.
	COOLDOWN_DECLARE(neural_crack_cooldown)
	/// Refresh the HUD when recovery ends; canceled if this core's OS is deleted.
	var/neural_crack_timer

/datum/ipc_os/New(obj/item/organ/brain/core)
	. = ..()
	src.core = core
	for(var/program_type in subtypesof(/datum/ipc_os_program))
		var/datum/ipc_os_program/program = new program_type(src)
		programs[program.id] = program

/datum/ipc_os/Destroy()
	if(neural_crack_timer)
		deltimer(neural_crack_timer)
		neural_crack_timer = null
	unbind()
	for(var/id in infections)
		qdel(infections[id])
	infections = null
	for(var/id in programs)
		qdel(programs[id])
	programs = null
	core = null
	return ..()

/datum/ipc_os/proc/on_job_spawn(datum/source, datum/job/job, mob/spawned)
	SIGNAL_HANDLER
	if(spawned == host)
		capture_pda_job(job)

/// Reuse the same configured trim as a normal job-issued ID without creating an ID item.
/datum/ipc_os/proc/capture_pda_job(datum/job/job)
	if(pda_job_title || !job || istype(job, /datum/job/unassigned))
		return
	pda_job_title = job.title
	UnregisterSignal(SSdcs, COMSIG_GLOB_JOB_AFTER_SPAWN)
	var/datum/outfit/job_outfit = job.outfit
	if(!job_outfit || !job_outfit::id_trim)
		return
	var/datum/id_trim/trim = SSid_access.trim_singletons_by_path[job_outfit::id_trim]
	if(trim)
		pda_job_access = trim.access | trim.wildcard_access

/// Bind only to the core's actual IPC owner, including after transplantation.
/datum/ipc_os/proc/bind(mob/living/carbon/human/new_host)
	if(!istype(new_host) || !is_species(new_host, /datum/species/ipc) || core.owner != new_host)
		return
	if(host == new_host)
		return
	unbind()
	host = new_host
	if(!pda_job_title)
		RegisterSignal(SSdcs, COMSIG_GLOB_JOB_AFTER_SPAWN, PROC_REF(on_job_spawn))
	open_action = new(src)
	open_action.Grant(host)
	RegisterSignal(host, COMSIG_LIVING_LIFE, PROC_REF(on_life))
	RegisterSignals(host, list(COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT), PROC_REF(on_shutdown))
	RegisterSignals(host, list(COMSIG_LIVING_REVIVE, COMSIG_MOB_LOGIN), PROC_REF(on_startup))
	RegisterSignal(host, COMSIG_SPECIES_LOSS, PROC_REF(on_species_loss))
	resume_passives()

/// Stop effects before detaching from a body; preserve installed software and licenses.
/datum/ipc_os/proc/unbind()
	control_session?.end()
	suspend_malware()
	stop_all()
	SStgui.close_uis(src)
	if(host)
		UnregisterSignal(SSdcs, COMSIG_GLOB_JOB_AFTER_SPAWN)
		UnregisterSignal(host, list(COMSIG_LIVING_LIFE, COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT, COMSIG_LIVING_REVIVE, COMSIG_MOB_LOGIN, COMSIG_SPECIES_LOSS))
	QDEL_NULL(open_action)
	host = null

/// Contact infection can reach an OS-disabled core, but never a dead or incompatible chassis.
/datum/ipc_os/proc/has_valid_chassis()
	return !QDELETED(core) && !QDELETED(host) && core.owner == host && is_species(host, /datum/species/ipc) && host.stat != DEAD && !(core.organ_flags & (ORGAN_FAILING|ORGAN_EMP)) && working_battery()

/// CoreRot disables software, independently of the original physical IPC charging/revival mechanics.
/datum/ipc_os/proc/is_operational()
	return has_valid_chassis() && !infections["core_rot"]

/// Reuse the one nutrition-backed microbattery, including its existing failure semantics.
/datum/ipc_os/proc/working_battery()
	var/obj/item/organ/heart/ipc/battery = host?.get_organ_slot(ORGAN_SLOT_HEART)
	if(!istype(battery) || (battery.organ_flags & (ORGAN_FAILING|ORGAN_EMP)) || host.nutrition <= 0)
		return null
	return battery

/// All UI commands must pass this check, independently of disabled frontend buttons.
/datum/ipc_os/proc/can_use(mob/user)
	return can_view(user) && !host.incapacitated

/// An incapacitated but conscious owner can view diagnostics and activate only NeuralCrack.
/datum/ipc_os/proc/can_view(mob/user)
	return user == host && is_operational() && !control_session && !IS_UNCONSCIOUS_OR_CRIT(host) && GET_CLIENT(host)

/// Reserve one catalog item before yielding; the final install still revalidates capacity and ownership.
/datum/ipc_os/proc/begin_download(id)
	if(!istext(id) || downloading || !can_use(host))
		return FALSE
	var/datum/ipc_os_program/program = programs[id]
	if(!program || program.installed || !program.available() || used_storage() + program.size > capacity())
		error_message = "Загрузка невозможна: проверьте доступ и свободное место."
		return FALSE
	downloading = program
	download_elapsed = 0
	START_PROCESSING(SSfastprocess, src)
	return TRUE

/// Logout, death, core extraction and shutdown discard only the partial download.
/datum/ipc_os/proc/cancel_download()
	if(!downloading)
		return
	STOP_PROCESSING(SSfastprocess, src)
	downloading = null
	download_elapsed = 0

/datum/ipc_os/process(seconds_per_tick)
	if(!downloading || !is_operational() || control_session || !GET_CLIENT(host))
		cancel_download()
		return PROCESS_KILL
	download_elapsed += seconds_per_tick
	if(download_elapsed >= max(2, downloading.size))
		var/id = downloading.id
		cancel_download()
		install(id)
		return PROCESS_KILL

/// Installed space is derived from trusted catalog sizes; running state never affects it.
/datum/ipc_os/proc/used_storage()
	var/used = 0
	for(var/id in programs)
		var/datum/ipc_os_program/program = programs[id]
		if(program.installed)
			used += program.size
	return used

/// EMAG increases capacity exactly once, regardless of license application order.
/datum/ipc_os/proc/capacity()
	return emag_unlocked ? 32 : 24

/// Catalog access grants no installation and cannot downgrade a prior unlock.
/datum/ipc_os/proc/unlock(full = FALSE)
	if(full)
		if(emag_unlocked)
			return FALSE
		emag_unlocked = TRUE
		return TRUE
	if(limited_unlocked || emag_unlocked)
		return FALSE
	limited_unlocked = TRUE
	return TRUE

/// One non-yielding transaction validates a catalog entry and reserves its exact size.
/datum/ipc_os/proc/install(id)
	if(!istext(id))
		return FALSE
	var/datum/ipc_os_program/program = programs[id]
	if(!program || program.installed || !program.available() || used_storage() + program.size > capacity())
		error_message = "Установка невозможна: проверьте доступ и свободное место."
		return FALSE
	program.installed = TRUE
	if(program.passive && is_operational() && GET_CLIENT(host))
		program.start()
	return TRUE

/// Removal always releases effects before freeing storage.
/datum/ipc_os/proc/uninstall(id)
	if(!istext(id))
		return FALSE
	var/datum/ipc_os_program/program = programs[id]
	if(!program?.installed)
		return FALSE
	program.stop()
	program.on_uninstall()
	program.installed = FALSE
	return TRUE

/// Disabling the OS must use every program's normal cleanup path.
/datum/ipc_os/proc/stop_all()
	cancel_download()
	for(var/id in infections)
		var/datum/ipc_os_malware/infection = infections[id]
		infection.cancel_cleaning()
	for(var/id in programs)
		var/datum/ipc_os_program/program = programs[id]
		if(program.running)
			program.stop()

/// Passive applications resume after a valid boot; toggles require manual reactivation.
/datum/ipc_os/proc/resume_passives()
	if(!is_operational() || control_session || !GET_CLIENT(host))
		return
	for(var/id in programs)
		var/datum/ipc_os_program/program = programs[id]
		if(program.installed && program.passive && !program.running)
			program.start()

/datum/ipc_os/proc/on_life(mob/source, seconds_per_tick)
	SIGNAL_HANDLER
	if(!has_valid_chassis() || !GET_CLIENT(host))
		suspend_malware()
		// The attacker's original chassis is intentionally uncliented during a valid remote session.
		if(control_session)
			return
		stop_all()
		return
	for(var/id in infections)
		var/datum/ipc_os_malware/infection = infections[id]
		infection.tick(seconds_per_tick)
	if(control_session)
		return
	if(!is_operational())
		stop_all()
		return
	resume_passives()
	for(var/id in programs)
		var/datum/ipc_os_program/program = programs[id]
		if(program.running)
			program.tick(seconds_per_tick)

/datum/ipc_os/proc/on_shutdown(mob/source)
	SIGNAL_HANDLER
	if(control_session)
		if(!control_session.transferring || source.stat == DEAD || QDELING(source))
			control_session.end()
		return
	suspend_malware()
	stop_all()
	SStgui.close_uis(src)

/datum/ipc_os/proc/on_startup()
	SIGNAL_HANDLER
	resume_passives()

/datum/ipc_os/proc/on_species_loss()
	SIGNAL_HANDLER
	unbind()

/// Dedicated action avoids requiring an item, organ or console to open the desktop.
/datum/action/innate/ipc_os
	name = "Positronic OS"
	desc = "Рабочий стол и NET позитронной операционной системы."
	button_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "pai_holoform"
	check_flags = AB_CHECK_CONSCIOUS
	/// Owner of the interface, independent of the action button's current mob.
	var/datum/ipc_os/os

/datum/action/innate/ipc_os/New(datum/ipc_os/os)
	. = ..()
	src.os = os

/datum/action/innate/ipc_os/Destroy()
	os = null
	return ..()

/datum/action/innate/ipc_os/IsAvailable(feedback = FALSE)
	return ..() && os?.can_view(owner)

/datum/action/innate/ipc_os/Activate()
	if(IsAvailable())
		os.ui_interact(owner)

/// Fixed software definitions; no filesystem, executable uploads or arbitrary typepaths.
/datum/ipc_os_program
	/// Server identifier, never a client-provided typepath.
	var/id
	/// Desktop label.
	var/name
	/// Gameplay description shown before installation.
	var/description
	/// Existing TGUI icon name.
	var/icon = "microchip"
	/// Installed size, in GB.
	var/size = 0
	/// Black Wall membership.
	var/illegal = FALSE
	/// Whether the limited market license covers this program.
	var/limited = FALSE
	/// Installed passives activate on boot.
	var/passive = FALSE
	/// Incremental implementations cannot advertise nonfunctional controls.
	var/ready = FALSE
	/// Storage and execution are distinct states.
	var/installed = FALSE
	/// Whether effects are currently applied.
	var/running = FALSE
	/// Pending connector actions must not survive a stop/uninstall followed by a fast restart.
	var/activation_id = 0
	/// Core-owned OS, cleared on deletion.
	var/datum/ipc_os/os

/datum/ipc_os_program/New(datum/ipc_os/os)
	. = ..()
	src.os = os

/datum/ipc_os_program/Destroy()
	stop()
	os = null
	return ..()

/// Availability is always calculated from persistent unlock state.
/datum/ipc_os_program/proc/available()
	return !illegal || os.emag_unlocked || (limited && os.limited_unlocked)

/// All activation paths recheck installation and physical validity.
/datum/ipc_os_program/proc/start()
	if(running || !installed || !ready || !available() || !os.is_operational())
		return FALSE
	running = TRUE
	activation_id++
	return TRUE

/// Subtypes remove only effects they own.
/datum/ipc_os_program/proc/stop()
	if(running)
		activation_id++
	running = FALSE

/// Some applications retain local data while stopped, but release it on removal.
/datum/ipc_os_program/proc/on_uninstall()
	return

/// Life intervals are elapsed seconds, not an assumed subsystem tick frequency.
/datum/ipc_os_program/proc/tick(seconds_per_tick)
	return

/datum/ipc_os_program/power_save
	id = "power_save"
	name = "PowerSave 3.0"
	description = "Снижает базовый расход микробатареи на 30% и скорость передвижения на 15%. Можно включать и выключать."
	icon = "battery-half"
	size = 9
	ready = TRUE

/datum/ipc_os_program/signal_boost
	id = "signal_boost"
	name = "SignalBoost"
	description = "Встроенный сигналлер: отправка по частоте и коду."
	icon = "satellite-dish"
	size = 5
	ready = TRUE

/datum/ipc_os_program/defrag
	id = "defrag"
	name = "DefragMaster"
	description = "Восстанавливает 2 brute каждые 25 секунд; базовый расход питания +35%."
	icon = "screwdriver-wrench"
	size = 10
	ready = TRUE

/datum/ipc_os_program/firewall
	id = "firewall"
	name = "Firewall+"
	description = "50% шанс блокировать завершённую передачу нового вируса. Не лечит заражение."
	icon = "shield-halved"
	size = 6
	passive = TRUE
	ready = TRUE

/datum/ipc_os_program/pda
	id = "pda"
	name = "Digital PDA"
	description = "Встроенный КПК: сообщения, заметки и манифест."
	icon = "tablet"
	size = 7
	ready = TRUE

/datum/ipc_os_program/virus_kit
	id = "virus_kit"
	name = "VirusKit"
	description = "Выбор и передача одного из четырёх вирусов через штатный кабель питания за 10 секунд."
	icon = "virus"
	size = 2
	illegal = TRUE
	limited = TRUE

/datum/ipc_os_program/overclock
	id = "overclock"
	name = "OverClock.exe"
	description = "Ускоряет бег на 25%. Нагревает физическое тело до опасной температуры."
	icon = "fire"
	size = 4
	illegal = TRUE

/datum/ipc_os_program/wall_breaker
	id = "wall_breaker"
	name = "WallBreaker"
	description = "Взлом шлюза штатным кабелем за 13 секунд. Повреждает электронику шлюза."
	icon = "door-open"
	size = 2
	illegal = TRUE

/datum/ipc_os_program/id_spoof
	id = "id_spoof"
	name = "ID_Spoof v3"
	description = "Подмена отображаемого имени на 15 минут. Не меняет ID, доступы или банковский счёт."
	icon = "id-card"
	size = 1
	illegal = TRUE
	limited = TRUE

/datum/ipc_os_program/ghost_mode
	id = "ghost_mode"
	name = "GhostMode"
	description = "Цифровая маскировка от ИИ. Увеличивает базовый расход питания на 30%."
	icon = "ghost"
	size = 1
	illegal = TRUE
	limited = TRUE

/datum/ipc_os_program/neural_crack
	id = "neural_crack"
	name = "NeuralCrack"
	description = "Снимает Stun, паралич и stamina-крит за 30 урона мозгу и 15 ожогов торсу. Откат 30 секунд. Не снимает сон."
	icon = "bolt"
	size = 4
	illegal = TRUE
