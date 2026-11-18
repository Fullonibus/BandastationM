#define IPC_OS_OVERCLOCK_HEAT_PER_SECOND 12
#define IPC_OS_NEURAL_BRAIN_DAMAGE 30
#define IPC_OS_NEURAL_TORSO_BURN 15
#define IPC_OS_NEURAL_COOLDOWN (30 SECONDS)

/// Return software only for a compatible chassis with its actual existing core.
/mob/living/carbon/human/proc/get_ipc_os()
	if(!is_species(src, /datum/species/ipc))
		return null
	var/obj/item/organ/brain/core = get_organ_slot(ORGAN_SLOT_BRAIN)
	return istype(core) ? core.operating_system : null

/mob/living/carbon/human/emag_act(mob/user, obj/item/card/emag/emag_card)
	var/datum/ipc_os/os = get_ipc_os()
	if(!os)
		return ..()
	if(istype(emag_card, /obj/item/card/emag/doorjack) || !os.unlock(TRUE))
		return FALSE
	to_chat(src, span_warning("Positronic OS: Black Wall разблокирован. Доступно 32 GB."))
	return TRUE

/// A consumed software carrier, never an implant or an organ.
/obj/item/ipc_os_upgrade
	name = "IPC illegal software update"
	desc = "Открывает в NET программы VirusKit, ID_Spoof v3 и GhostMode. Не увеличивает память."
	icon = 'icons/obj/devices/floppy_disks.dmi'
	icon_state = "datadisk3"
	item_flags = NOBLUDGEON

/obj/item/ipc_os_upgrade/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ishuman(interacting_with) || !user.can_perform_action(interacting_with, FORBID_TELEKINESIS_REACH))
		return NONE
	var/mob/living/carbon/human/ipc = interacting_with
	var/datum/ipc_os/os = ipc.get_ipc_os()
	if(!os || !os.unlock())
		balloon_alert(user, "обновление недоступно")
		return ITEM_INTERACT_BLOCKING
	to_chat(ipc, span_warning("Positronic OS: открыт ограниченный каталог Black Wall. Память не изменена."))
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/// Bank-account credits plus the existing market's delivery fee; no traitor TC conversion.
/datum/market_item/ipc_os_upgrade
	name = "Нелегальное обновление КПБ"
	desc = "Открывает VirusKit, ID_Spoof v3 и GhostMode. Установка программ выполняется отдельно в NET."
	category = "Equipment"
	item = /obj/item/ipc_os_upgrade
	price = 200
	stock = 3
	stock_max = 3
	availability_prob = 100

/datum/ipc_os_program/id_spoof
	ready = TRUE
	/// Cosmetic text, never written into an ID, mind or manifest.
	var/spoof_name = "Неизвестный"
	/// Optional visible title, without real job or access effects.
	var/spoof_job = "КПБ"
	/// Editing text does not renew the approved fifteen-minute activation.
	var/expires_at = 0
	/// Only the worn card's rendered examine label is overridden; its actual data is never edited.
	var/obj/item/display_card

/datum/ipc_os_program/id_spoof/start()
	if(!..())
		return FALSE
	expires_at = world.time + 15 MINUTES
	RegisterSignal(os.host, COMSIG_HUMAN_GET_VISIBLE_NAME, PROC_REF(on_visible_name))
	RegisterSignal(os.host, COMSIG_HUMAN_GET_ID_EXAMINE, PROC_REF(on_id_examine))
	RegisterSignals(os.host, list(COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM), PROC_REF(on_equipment_changed))
	sync_card()
	os.host.update_visible_name()
	return TRUE

/datum/ipc_os_program/id_spoof/stop()
	if(running && os.host)
		UnregisterSignal(os.host, COMSIG_HUMAN_GET_VISIBLE_NAME)
		UnregisterSignal(os.host, COMSIG_HUMAN_GET_ID_EXAMINE)
		UnregisterSignal(os.host, list(COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM))
		os.host.update_visible_name()
	clear_card()
	expires_at = 0
	return ..()

/datum/ipc_os_program/id_spoof/tick(seconds_per_tick)
	if(world.time >= expires_at)
		stop()

/datum/ipc_os_program/id_spoof/proc/on_visible_name(datum/source, list/identity)
	SIGNAL_HANDLER
	identity[VISIBLE_NAME_FACE] = spoof_name
	identity[VISIBLE_NAME_ID] = spoof_name
	identity[VISIBLE_NAME_FORCED] = TRUE

/datum/ipc_os_program/id_spoof/proc/on_id_examine(datum/source, obj/item/card/id/card, list/identity)
	SIGNAL_HANDLER
	if(!running || card != os.host?.wear_id?.GetID())
		return
	identity["name"] = spoof_name
	identity["job"] = spoof_job
	identity["holder"] = spoof_name

/datum/ipc_os_program/id_spoof/proc/on_equipment_changed()
	SIGNAL_HANDLER
	sync_card()

/datum/ipc_os_program/id_spoof/proc/clear_card()
	if(display_card)
		UnregisterSignal(display_card, list(COMSIG_ATOM_GET_EXAMINE_NAME, COMSIG_QDELETING))
	display_card = null

/datum/ipc_os_program/id_spoof/proc/sync_card()
	var/obj/item/current = os.host?.wear_id
	if(current == display_card)
		return
	clear_card()
	if(QDELETED(current) || (!current.GetID() && !istype(current, /obj/item/modular_computer)))
		return
	display_card = current
	RegisterSignal(current, COMSIG_ATOM_GET_EXAMINE_NAME, PROC_REF(on_card_name))
	RegisterSignal(current, COMSIG_QDELETING, PROC_REF(on_card_deleted))

/datum/ipc_os_program/id_spoof/proc/on_card_deleted()
	SIGNAL_HANDLER
	clear_card()

/datum/ipc_os_program/id_spoof/proc/on_card_name(obj/item/source, mob/user, list/override)
	SIGNAL_HANDLER
	if(!running || source != os.host?.wear_id)
		return
	var/card_name = istype(source, /obj/item/card/id) ? "ID-карта" : istype(source, /obj/item/modular_computer) ? "КПК" : source.get_visible_name()
	override[EXAMINE_POSITION_ARTICLE] = ""
	override[EXAMINE_POSITION_NAME] = "<em>[card_name] «[spoof_name]»[length(spoof_job) ? " ([spoof_job])" : ""]</em>"

/datum/ipc_os_program/ghost_mode
	ready = TRUE

/datum/ipc_os_program/ghost_mode/start()
	if(!..())
		return FALSE
	os.host.AddElement(/datum/element/digitalcamo, REF(src))
	return TRUE

/datum/ipc_os_program/ghost_mode/stop()
	if(running && os.host)
		os.host.RemoveElement(/datum/element/digitalcamo, REF(src))
	return ..()

/// The modifier returns a raw delay adjustment because Primera scales ordinary TG modifiers.
/datum/movespeed_modifier/ipc_os_overclock
	variable = TRUE
	blacklisted_movetypes = FLYING|FLOATING

/datum/movespeed_modifier/ipc_os_overclock/get_rp_speed()
	return multiplicative_slowdown

/datum/ipc_os_program/overclock
	ready = TRUE
	/// Prevent recursion when updating our own modifier emits MOVESPEED_UPDATED.
	var/syncing_speed = FALSE

/datum/ipc_os_program/overclock/start()
	if(!..())
		return FALSE
	RegisterSignals(os.host, list(COMSIG_MOB_MOVESPEED_UPDATED, COMSIG_MOVE_INTENT_TOGGLED), PROC_REF(sync_speed))
	os.host.add_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock)
	return TRUE

/datum/ipc_os_program/overclock/stop()
	if(running && os.host)
		UnregisterSignal(os.host, list(COMSIG_MOB_MOVESPEED_UPDATED, COMSIG_MOVE_INTENT_TOGGLED))
		os.host.remove_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock)
	return ..()

/datum/ipc_os_program/overclock/proc/sync_speed()
	SIGNAL_HANDLER
	if(syncing_speed || !running)
		return
	var/datum/movespeed_modifier/ipc_os_overclock/modifier = os.host.has_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock)
	if(!modifier)
		return
	syncing_speed = TRUE
	var/base_delay = os.host.cached_multiplicative_slowdown - modifier.get_rp_speed()
	var/adjustment = os.host.move_intent == MOVE_INTENT_RUN && !(os.host.movement_type & (FLYING|FLOATING)) ? -max(base_delay, 0) * 0.2 : 0
	os.host.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock, multiplicative_slowdown = adjustment)
	syncing_speed = FALSE

/datum/ipc_os_program/overclock/tick(seconds_per_tick)
	os.host.adjust_coretemperature(IPC_OS_OVERCLOCK_HEAT_PER_SECOND * seconds_per_tick)
	os.host.adjust_bodytemperature(IPC_OS_OVERCLOCK_HEAT_PER_SECOND * seconds_per_tick)

/datum/ipc_os_program/wall_breaker
	ready = TRUE

/datum/ipc_os_program/neural_crack
	ready = TRUE
	passive = TRUE
	/// A dedicated conscious-only action remains usable when stun blocks the desktop.
	var/datum/action/innate/ipc_os/neural_crack/crack_action

/datum/ipc_os_program/neural_crack/start()
	if(!..())
		return FALSE
	crack_action = new(os)
	crack_action.Grant(os.host)
	return TRUE

/datum/ipc_os_program/neural_crack/stop()
	QDEL_NULL(crack_action)
	return ..()

/// The three approved incapacitating effects; knockdown, sleep and unconsciousness are separate.
/datum/ipc_os/proc/has_crackable_stun()
	return host && (host.IsStun() || host.IsParalyzed() || host.has_status_effect(/datum/status_effect/incapacitating/stamcrit))

/datum/ipc_os/proc/can_neural_crack(require_effect = TRUE)
	var/datum/ipc_os_program/program = programs["neural_crack"]
	return is_operational() && !control_session && !IS_UNCONSCIOUS_OR_CRIT(host) && !host.IsSleeping() && program.installed && program.running && COOLDOWN_FINISHED(src, neural_crack_cooldown) && core.damage + IPC_OS_NEURAL_BRAIN_DAMAGE <= core.maxHealth && host.get_bodypart(BODY_ZONE_CHEST) && (!require_effect || has_crackable_stun())

/// Charge once for removing an actual eligible effect; never wake a sleeping or unconscious owner.
/datum/ipc_os/proc/neural_crack()
	if(!can_neural_crack())
		return FALSE
	var/obj/item/bodypart/chest = host.get_bodypart(BODY_ZONE_CHEST)
	COOLDOWN_START(src, neural_crack_cooldown, IPC_OS_NEURAL_COOLDOWN)
	neural_crack_timer = addtimer(CALLBACK(src, PROC_REF(refresh_neural_crack)), IPC_OS_NEURAL_COOLDOWN, TIMER_STOPPABLE)
	host.remove_status_effect(/datum/status_effect/incapacitating/stun)
	host.remove_status_effect(/datum/status_effect/incapacitating/paralyzed)
	if(host.has_status_effect(/datum/status_effect/incapacitating/stamcrit))
		host.set_stamina_loss(0)
		host.remove_status_effect(/datum/status_effect/incapacitating/stamcrit)
	chest.receive_damage(burn = IPC_OS_NEURAL_TORSO_BURN, wound_bonus = CANT_WOUND)
	core.apply_organ_damage(IPC_OS_NEURAL_BRAIN_DAMAGE)
	refresh_neural_crack_button()
	return TRUE

/// The cooldown is authoritative on the core even while its program is stopped or uninstalled.
/datum/ipc_os/proc/refresh_neural_crack()
	neural_crack_timer = null
	refresh_neural_crack_button()

/datum/ipc_os/proc/refresh_neural_crack_button()
	var/datum/ipc_os_program/neural_crack/program = programs["neural_crack"]
	program.crack_action?.build_all_button_icons(UPDATE_BUTTON_STATUS)

/datum/action/innate/ipc_os/neural_crack
	name = "NeuralCrack"
	desc = "Снять Stun, паралич и stamina-крит за 30 урона мозгу и 15 ожогов торсу. Откат 30 секунд. Сон не снимается."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "emp"

/datum/action/innate/ipc_os/neural_crack/IsAvailable(feedback = FALSE)
	// Keep the conscious HUD action ready before stun arrives; no effect means no cost.
	return !action_disabled && owner == os?.host && os?.can_neural_crack(require_effect = FALSE)

/datum/action/innate/ipc_os/neural_crack/Activate()
	if(IsAvailable())
		if(!os.neural_crack())
			owner.balloon_alert(owner, "нет подходящего оглушения!")

#undef IPC_OS_OVERCLOCK_HEAT_PER_SECOND
#undef IPC_OS_NEURAL_BRAIN_DAMAGE
#undef IPC_OS_NEURAL_TORSO_BURN
#undef IPC_OS_NEURAL_COOLDOWN
