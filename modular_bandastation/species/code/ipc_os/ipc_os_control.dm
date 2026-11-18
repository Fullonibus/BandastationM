/// A reversible use of the existing mind-transfer/backseat pattern, scoped to two IPC cores.
/datum/ipc_os_control
	/// Both cores are reserved for one session, preventing nested or simultaneous controllers.
	var/datum/ipc_os/source_os
	var/datum/ipc_os/target_os
	/// Fixed original bodies; damage is never applied through mind.current.
	var/mob/living/carbon/human/attacker
	var/mob/living/carbon/human/victim
	/// Original personalities, independent of their temporary bodies.
	var/datum/mind/attacker_mind
	var/datum/mind/victim_mind
	/// Native transfer_to clears these; restore them when returning to the original bodies.
	var/datum/weakref/attacker_original
	var/datum/weakref/victim_original
	/// The victim observes their chassis without controlling it.
	var/mob/living/ipc_os_backseat/backseat
	/// Attacker's explicit return action in the controlled chassis.
	var/datum/action/innate/ipc_os_release/release_action
	/// Suppress reactions to this session's own Login/Logout/mind-transfer callbacks.
	var/transferring = FALSE
	/// Teardown is idempotent, including recursive death/Logout callbacks.
	var/ending = FALSE
	/// Five burn per two elapsed seconds, regardless of processing frequency.
	var/burn_elapsed = 0

/datum/ipc_os_control/New(datum/ipc_os/source_os, datum/ipc_os/target_os)
	. = ..()
	src.source_os = source_os
	src.target_os = target_os
	attacker = source_os.host
	victim = target_os.host

/// Validate ownership of a real existing infection before displacing either player's controller.
/datum/ipc_os_control/proc/start()
	if(!source_os.can_use(attacker) || !target_os.is_operational() || !GET_CLIENT(victim) || source_os.control_session || target_os.control_session)
		return FALSE
	if(attacker == victim || !attacker.mind || !victim.mind)
		return FALSE
	var/datum/ipc_os_program/virus_kit/kit = source_os.programs["virus_kit"]
	var/datum/ipc_os_malware/infection = target_os.infections["neural_hijack"]
	if(!kit.installed || !kit.running || infection?.source_core?.resolve() != source_os.core)
		return FALSE
	to_chat(attacker, span_userdanger("NeuralHijack: идёт подключение к целевому КПБ и перехват управления!"))
	to_chat(victim, span_userdanger("NeuralHijack: к вашей Positronic OS подключаются! Происходит перехват управления корпусом!"))
	attacker_mind = attacker.mind
	victim_mind = victim.mind
	attacker_original = attacker_mind.original_character
	victim_original = victim_mind.original_character
	source_os.control_session = src
	target_os.control_session = src
	transferring = TRUE
	source_os.stop_all()
	target_os.stop_all()
	source_os.suspend_malware()
	target_os.suspend_malware()
	SStgui.close_uis(source_os)
	SStgui.close_uis(target_os)
	backseat = new(victim, src)
	for(var/mob/body in list(attacker, victim, backseat))
		RegisterSignals(body, list(COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT, COMSIG_QDELETING), PROC_REF(on_invalidated))
	RegisterSignal(attacker_mind, COMSIG_MIND_TRANSFERRED, PROC_REF(on_mind_transfer))
	RegisterSignal(victim_mind, COMSIG_MIND_TRANSFERRED, PROC_REF(on_mind_transfer))
	RegisterSignal(attacker_mind, COMSIG_QDELETING, PROC_REF(on_mind_deleted))
	RegisterSignal(victim_mind, COMSIG_QDELETING, PROC_REF(on_mind_deleted))
	log_combat(attacker, victim, "began NeuralHijack control")
	victim_mind.transfer_to(backseat)
	if(ending || QDELETED(src))
		return FALSE
	if(attacker_mind.current != attacker || victim_mind.current != backseat)
		end()
		return FALSE
	attacker_mind.transfer_to(victim)
	if(ending || QDELETED(src))
		return FALSE
	if(attacker_mind.current != victim || victim_mind.current != backseat)
		end()
		return FALSE
	transferring = FALSE
	release_action = new(src)
	release_action.Grant(victim)
	START_PROCESSING(SSfastprocess, src)
	return TRUE

/datum/ipc_os_control/process(seconds_per_tick)
	if(ending)
		return PROCESS_KILL
	var/datum/ipc_os_program/virus_kit/kit = source_os.programs["virus_kit"]
	if(!source_os.is_operational() || !target_os.is_operational() || !kit.installed || !target_os.infections["neural_hijack"])
		end()
		return PROCESS_KILL
	if(attacker.mind || attacker_mind.current != victim || victim_mind.current != backseat || !GET_CLIENT(victim) || !GET_CLIENT(backseat))
		end()
		return PROCESS_KILL
	burn_elapsed += seconds_per_tick
	while(burn_elapsed >= 2 && !ending)
		burn_elapsed -= 2
		attacker.adjust_fire_loss(5)
	return ending ? PROCESS_KILL : null

/datum/ipc_os_control/proc/on_invalidated(mob/source)
	SIGNAL_HANDLER
	if(!transferring || QDELING(source) || source.stat == DEAD)
		end()

/datum/ipc_os_control/proc/on_mind_transfer()
	SIGNAL_HANDLER
	if(!transferring)
		end()

/datum/ipc_os_control/proc/on_mind_deleted()
	SIGNAL_HANDLER
	end()

/// Restore control without displacing an unrelated mind that entered either chassis.
/datum/ipc_os_control/proc/restore_mind(datum/mind/mind, mob/living/expected, mob/living/destination, datum/weakref/original, datum/mind/temporary_occupant)
	if(QDELETED(mind) || mind.current != expected)
		return
	var/datum/mind/occupant = destination?.mind
	if(!QDELETED(destination) && (!occupant || occupant == mind || occupant == temporary_occupant))
		mind.transfer_to(destination)
		mind.original_character = original
	else if(!QDELETED(expected) && expected.mind == mind)
		expected.ghostize(can_reenter_corpse = FALSE)

/// Every exit route uses the same restoration and ownership cleanup.
/datum/ipc_os_control/proc/end()
	if(ending)
		return
	ending = TRUE
	transferring = TRUE
	STOP_PROCESSING(SSfastprocess, src)
	QDEL_NULL(release_action)
	for(var/mob/body in list(attacker, victim, backseat))
		if(body)
			UnregisterSignal(body, list(COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT, COMSIG_QDELETING))
	if(attacker_mind)
		UnregisterSignal(attacker_mind, list(COMSIG_MIND_TRANSFERRED, COMSIG_QDELETING))
	if(victim_mind)
		UnregisterSignal(victim_mind, list(COMSIG_MIND_TRANSFERRED, COMSIG_QDELETING))
	restore_mind(attacker_mind, victim, attacker, attacker_original)
	// The attacker's mind can still be in the victim when its original body is unavailable.
	restore_mind(victim_mind, backseat, victim, victim_original, attacker_mind)
	if(source_os?.control_session == src)
		source_os.control_session = null
	if(target_os?.control_session == src)
		target_os.control_session = null
	QDEL_NULL(backseat)
	source_os?.resume_passives()
	target_os?.resume_passives()
	if(!QDELING(src))
		qdel(src)

/datum/ipc_os_control/Destroy()
	if(!ending)
		end()
	source_os = null
	target_os = null
	attacker = null
	victim = null
	attacker_mind = null
	victim_mind = null
	attacker_original = null
	victim_original = null
	return ..()

/// A non-interactive living backseat lets the existing mind API preserve the victim's personality.
/mob/living/ipc_os_backseat
	name = "изолированное сознание"
	density = FALSE
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// The session owns this mob and ends before deleting it.
	var/datum/ipc_os_control/session

/mob/living/ipc_os_backseat/Initialize(mapload, datum/ipc_os_control/session)
	src.session = session
	return ..()

/mob/living/ipc_os_backseat/Destroy()
	if(mind?.current == src)
		ghostize(can_reenter_corpse = FALSE)
	session = null
	return ..()

/mob/living/ipc_os_backseat/Login()
	. = ..()
	if(. && session)
		reset_perspective(session.victim)
		to_chat(src, span_userdanger("NeuralHijack перехватил управление корпусом. Вы наблюдаете из изолированного сознания."))

/mob/living/ipc_os_backseat/Life(seconds_per_tick = SSMOBS_DT)
	if(session && client)
		reset_perspective(session.victim)

/mob/living/ipc_os_backseat/Move()
	return FALSE

/mob/living/ipc_os_backseat/try_speak(message, ignore_spam, forced, filterproof)
	SHOULD_CALL_PARENT(FALSE)
	return FALSE

/// Only the controlling attacker receives this action, independent of OS window state or stun.
/datum/action/innate/ipc_os_release
	name = "Завершить NeuralHijack"
	desc = "Вернуть управление обоим игрокам. Заражение остаётся до нейронной отладки."
	button_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "pai_holoform"
	check_flags = NONE
	/// One session, cleared when the session removes this action.
	var/datum/ipc_os_control/session

/datum/action/innate/ipc_os_release/New(datum/ipc_os_control/session)
	. = ..()
	src.session = session

/datum/action/innate/ipc_os_release/Destroy()
	session = null
	return ..()

/datum/action/innate/ipc_os_release/IsAvailable(feedback = FALSE)
	return session && !session.ending && owner == session.victim && owner.mind == session.attacker_mind

/datum/action/innate/ipc_os_release/Activate()
	if(IsAvailable())
		session.end()
