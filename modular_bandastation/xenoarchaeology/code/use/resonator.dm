/**
 * # Anomalous resonator
 *
 * A belt that holds one exotic battery. Worn on the belt with a charged battery, it gives its wearer a
 * passive by the battery's energy kind (free) and active abilities (paid in charge): one by a small
 * source; a large find gives its own effect and a second ability by energy kind, hitting harder. A battery from a core or field artefact is a small source: half the charge and a weaker passive.
 * The power is keyed to the resonance binding implant; without it the belt still works but hurts its
 * wearer, and every ability use may break their mind or blow their head off.
 */
/obj/item/anomaly_resonator
	name = "аномальный резонатор"
	desc = "Пояс с гнездом для экзотической батареи. Надетый с заряженной батареей, через несколько секунд настройки даёт носителю силу её энергии. Используйте в руке, чтобы вынуть батарею."
	icon = 'modular_bandastation/xenoarchaeology/icons/resonator.dmi'
	icon_state = "resonator_empty"
	inhand_icon_state = "resonator_empty"
	lefthand_file = 'modular_bandastation/xenoarchaeology/icons/resonator_left.dmi'
	righthand_file = 'modular_bandastation/xenoarchaeology/icons/resonator_right.dmi'
	worn_icon = 'modular_bandastation/xenoarchaeology/icons/resonator_worn.dmi'
	worn_icon_state = "resonator_empty"
	slot_flags = ITEM_SLOT_BELT
	w_class = WEIGHT_CLASS_BULKY
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/silver = SHEET_MATERIAL_AMOUNT, /datum/material/plasma = SHEET_MATERIAL_AMOUNT)
	/// The battery in its socket.
	var/obj/item/anomaly_battery/battery
	/// Who wears it on the belt now.
	var/mob/living/wearer
	/// Passive applied to the wearer: an energy kind key or RESONANCE_PASSIVE_FLIGHT, null if none.
	var/applied_passive
	/// Strength of the applied passive: 1 for a large source, 0.5 for a small one.
	var/applied_strength = 0
	/// The abilities it grants now.
	var/list/datum/action/cooldown/resonance/abilities = list()
	/// When its wearer put it on without the binding; the longer, the worse.
	var/unbound_since = 0
	/// Whether it has attuned to its wearer and battery; lost when either goes.
	var/attuned = FALSE
	/// Timer finishing the attunement in progress, if any.
	var/attune_timer
	/// Crackle drawn on the wearer while attuning.
	var/mutable_appearance/attune_overlay
	/// Ability type -> world.time its cooldown ends, so a battery swap or a re-wear does not reset it.
	var/list/cooldown_ends = list()
	COOLDOWN_DECLARE(punish_cooldown)

/obj/item/anomaly_resonator/Destroy()
	release_wearer()
	battery?.forceMove(drop_location())
	return ..()

/obj/item/anomaly_resonator/examine(mob/user)
	. = ..()
	. += battery ? span_notice("В гнезде [battery.name], заряд [battery.stored_charge] из [battery.capacity].") : span_notice("Гнездо пусто.")

/obj/item/anomaly_resonator/update_icon_state()
	icon_state = !battery ? "resonator_empty" : (battery.stored_charge > 0 ? "resonator_active" : "resonator_loaded")
	inhand_icon_state = icon_state
	worn_icon_state = icon_state
	return ..()

/obj/item/anomaly_resonator/update_overlays()
	. = ..()
	. += anomaly_core_overlays(src, "resonator_core", battery?.lit_kind(), battery?.charge_fraction() || 0)

/obj/item/anomaly_resonator/worn_overlays(mutable_appearance/standing, isinhands, icon_file, bodyshape = NONE)
	. = ..()
	var/datum/artifact_energy_kind/kind = battery?.lit_kind()
	if(!kind)
		return
	var/core_alpha = round(110 + 145 * battery.charge_fraction())
	var/mutable_appearance/core = mutable_appearance(icon_file, "resonator_core", alpha = core_alpha)
	core.color = kind.color
	. += core
	. += emissive_appearance(icon_file, "resonator_core", src, alpha = round(core_alpha * 0.7))

/obj/item/anomaly_resonator/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == battery)
		battery = null
		refresh()

/obj/item/anomaly_resonator/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/anomaly_battery))
		return NONE
	if(battery)
		balloon_alert(user, "гнездо занято!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "вставляем батарею...")
	if(!do_after(user, RESONANCE_SWAP_TIME, src) || battery || !user.is_holding(tool))
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	battery = tool
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	refresh()
	return ITEM_INTERACT_SUCCESS

/obj/item/anomaly_resonator/attack_self(mob/user, modifiers)
	. = ..()
	if(. || !battery)
		return
	balloon_alert(user, "вынимаем батарею...")
	var/obj/item/anomaly_battery/taken = battery
	if(!do_after(user, RESONANCE_SWAP_TIME, src) || battery != taken)
		return TRUE
	user.put_in_hands(battery)
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	return TRUE

/obj/item/anomaly_resonator/equipped(mob/living/user, slot, initial)
	. = ..()
	if(!(slot & ITEM_SLOT_BELT))
		release_wearer()
		return
	if(wearer == user)
		return
	release_wearer()
	wearer = user
	START_PROCESSING(SSobj, src)
	COOLDOWN_START(src, punish_cooldown, RESONANCE_PUNISH_PERIOD)
	unbound_since = world.time
	if(!is_resonance_bound(user))
		to_chat(user, span_userdanger("Ошибка: имплант резонансной привязки не найден."))
	refresh()

/obj/item/anomaly_resonator/dropped(mob/user, silent)
	. = ..()
	release_wearer()

/obj/item/anomaly_resonator/proc/release_wearer()
	if(!wearer)
		return
	clear_power()
	stop_attunement()
	attuned = FALSE
	STOP_PROCESSING(SSobj, src)
	wearer = null

/// Whether a charged battery powers it for its wearer now.
/obj/item/anomaly_resonator/proc/powered()
	return wearer && battery?.held_effect && battery.stored_charge > 0

/// Puts the passive and ability in step with the battery.
/obj/item/anomaly_resonator/proc/refresh()
	clear_power()
	update_appearance(UPDATE_ICON)
	update_slot_icon()
	if(!powered())
		stop_attunement()
		attuned = FALSE
		return
	if(!attuned)
		start_attunement()
		return
	applied_strength = battery.small_source ? 0.5 : 1
	applied_passive = GLOB.resonance_passive_by_source[battery.source_type] || battery.held_effect.energy_kind
	apply_passive(TRUE)
	var/list/ability_types
	if(battery.source_type)
		ability_types = list(GLOB.resonance_ability_by_source[battery.source_type])
	else
		ability_types = list(/datum/action/cooldown/resonance/artifact_release, GLOB.resonance_second_by_kind[battery.held_effect.energy_kind])
	for(var/ability_type in ability_types)
		if(!ability_type)
			continue
		var/datum/action/cooldown/resonance/ability = new ability_type(src)
		if(!battery.small_source)
			ability.power = RESONANCE_LARGE_POWER
			ability.chain = TRUE
		abilities += ability
		ability.Grant(wearer)
		if(cooldown_ends[ability_type] > world.time)
			ability.StartCooldown(cooldown_ends[ability_type] - world.time)

/// Starts attuning to the wearer and battery: a few seconds of crackling and a racing heartbeat before the power comes.
/obj/item/anomaly_resonator/proc/start_attunement()
	if(attune_timer)
		return
	attune_overlay = mutable_appearance('icons/effects/effects.dmi', "electricity", ABOVE_MOB_LAYER)
	attune_overlay.color = "#a060ff"
	wearer.add_overlay(attune_overlay)
	playsound(wearer, 'sound/effects/health/fastbeat.ogg', 60)
	playsound(wearer, 'sound/effects/sparks/sparks4.ogg', 50, TRUE)
	wearer.visible_message(span_warning("По [wearer] пробегают фиолетовые разряды."), span_notice("Резонатор настраивается: сердце сбивается с ритма, по коже бегут разряды..."))
	attune_timer = addtimer(CALLBACK(src, PROC_REF(finish_attunement)), RESONANCE_ATTUNE_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// Ends the attunement: the power comes if the battery and wearer are still there.
/obj/item/anomaly_resonator/proc/finish_attunement()
	stop_attunement()
	if(!powered())
		return
	attuned = TRUE
	playsound(wearer, 'sound/effects/magic/charge.ogg', 40, TRUE)
	to_chat(wearer, span_notice("Резонанс установлен."))
	refresh()

/// Stops an attunement in progress and takes its crackle off the wearer.
/obj/item/anomaly_resonator/proc/stop_attunement()
	if(attune_timer)
		deltimer(attune_timer)
		attune_timer = null
	if(attune_overlay)
		wearer?.cut_overlay(attune_overlay)
		attune_overlay = null

/obj/item/anomaly_resonator/proc/clear_power()
	if(applied_passive)
		apply_passive(FALSE)
		applied_passive = null
	for(var/datum/action/cooldown/resonance/ability as anything in abilities)
		if(ability.next_use_time > world.time)
			cooldown_ends[ability.type] = ability.next_use_time
	QDEL_LIST(abilities)

/// Applies (or with `on` FALSE takes off) the state the passive changes on its wearer.
/obj/item/anomaly_resonator/proc/apply_passive(on)
	var/trait_source = REF(src)
	var/factor = 1 - 0.5 * applied_strength
	switch(applied_passive)
		if(RESONANCE_PASSIVE_FLIGHT)
			if(on)
				wearer.add_traits(list(TRAIT_MOVE_FLOATING, TRAIT_PASSTABLE), trait_source)
			else
				wearer.remove_traits(list(TRAIT_MOVE_FLOATING, TRAIT_PASSTABLE), trait_source)
		if(RESONANCE_PASSIVE_THERMAL)
			if(on)
				ADD_TRAIT(wearer, TRAIT_THERMAL_VISION, trait_source)
			else
				REMOVE_TRAIT(wearer, TRAIT_THERMAL_VISION, trait_source)
			wearer.update_sight()
		if(ARTIFACT_ENERGY_ELECTROMAGNETIC)
			MODIFY_PHYSIOLOGY(wearer, PHYS_COEFF_ELEC_CONDUCTIVITY, on ? factor : 1 / factor)
		if(ARTIFACT_ENERGY_CONCENTRATED)
			MODIFY_PHYSIOLOGY(wearer, BURN, on ? factor : 1 / factor)
		if(ARTIFACT_ENERGY_PARTICLE)
			if(applied_strength >= 1)
				if(on)
					ADD_TRAIT(wearer, TRAIT_RADIMMUNE, trait_source)
				else
					REMOVE_TRAIT(wearer, TRAIT_RADIMMUNE, trait_source)
			else
				MODIFY_PHYSIOLOGY(wearer, TOX, on ? 0.75 : 1 / 0.75)
		if(ARTIFACT_ENERGY_SYNTHESIS)
			var/synthesis_trait = applied_strength >= 1 ? TRAIT_RESISTLOWPRESSURE : TRAIT_RESISTCOLD
			if(on)
				ADD_TRAIT(wearer, synthesis_trait, trait_source)
			else
				REMOVE_TRAIT(wearer, synthesis_trait, trait_source)

/// FIELD_ARTEFACT_* protections its passive gives against anomaly fields; a small source holds half the time.
/obj/item/anomaly_resonator/proc/field_protection()
	if(!applied_passive || (applied_strength < 1 && prob(50)))
		return NONE
	switch(applied_passive)
		if(ARTIFACT_ENERGY_PSIONIC)
			return FIELD_ARTEFACT_BLINDPROOF
		if(ARTIFACT_ENERGY_BLUESPACE)
			return FIELD_ARTEFACT_ANCHOR
	return NONE

/obj/item/anomaly_resonator/process(seconds_per_tick)
	if(!wearer)
		return PROCESS_KILL
	if(length(abilities) && !powered())
		refresh()
	switch(applied_passive)
		if(ARTIFACT_ENERGY_ORGANIC)
			if(wearer.blood_volume < BLOOD_VOLUME_NORMAL)
				wearer.adjust_blood_volume(2 * applied_strength * seconds_per_tick, maximum = BLOOD_VOLUME_NORMAL)
			wearer.heal_overall_damage(brute = 0.5 * applied_strength * seconds_per_tick, burn = 0.5 * applied_strength * seconds_per_tick)
		if(ARTIFACT_ENERGY_PSIONIC)
			wearer.adjust_hallucinations(-2 SECONDS * applied_strength * seconds_per_tick)
			if(applied_strength >= 1 || prob(50))
				wearer.remove_status_effect(/datum/status_effect/confusion)
	if(!is_resonance_bound(wearer) && COOLDOWN_FINISHED(src, punish_cooldown))
		COOLDOWN_START(src, punish_cooldown, RESONANCE_PUNISH_PERIOD)
		punish_wear()

/// Spends `amount` charge for an ability. Returns FALSE if the battery cannot pay.
/obj/item/anomaly_resonator/proc/spend(amount)
	if(!powered() || battery.stored_charge < amount)
		balloon_alert(wearer, "мало заряда!")
		return FALSE
	battery.use_charge(amount)
	update_appearance(UPDATE_ICON)
	update_slot_icon()
	if(!is_resonance_bound(wearer))
		punish_use()
	if(battery?.stored_charge <= 0)
		addtimer(CALLBACK(src, PROC_REF(refresh)), 0)
	return TRUE

/// Every RESONANCE_PUNISH_PERIOD worn without the binding: a fit of pain that gets worse the longer it is worn.
/obj/item/anomaly_resonator/proc/punish_wear()
	var/worn_for = world.time - unbound_since
	wearer.visible_message(span_danger("[wearer] хватается за голову и корчится!"), span_userdanger("Резонатор вгрызается в нервы: боль раскалывает голову и сводит всё тело!"))
	INVOKE_ASYNC(wearer, TYPE_PROC_REF(/mob, emote), "scream")
	wearer.apply_damage(6, BRUTE, spread_damage = TRUE)
	wearer.adjust_stamina_loss(30)
	wearer.adjust_organ_loss(ORGAN_SLOT_BRAIN, 4)
	if(prob(30))
		wearer.adjust_hallucinations(30 SECONDS)
	if(prob(5))
		wearer.adjust_temp_blindness(15 SECONDS)
	var/mob/living/carbon/carbon = wearer
	if(!istype(carbon))
		return
	if(prob(35))
		carbon.vomit(VOMIT_CATEGORY_BLOOD, lost_nutrition = 10)
		carbon.apply_damage(5, BRUTE, BODY_ZONE_CHEST)
	if(worn_for >= 3 MINUTES && prob(3))
		var/obj/item/organ/stomach/stomach = carbon.get_organ_slot(ORGAN_SLOT_STOMACH)
		if(stomach)
			carbon.visible_message(span_danger("[carbon] выблёвывает собственный желудок!"), span_userdanger("Вы выблёвываете собственный желудок!"))
			stomach.Remove(carbon)
			stomach.forceMove(get_turf(carbon))
			carbon.vomit(VOMIT_CATEGORY_BLOOD, lost_nutrition = 0)
	if(worn_for >= 7 MINUTES && prob(5))
		carbon.gain_trauma_type(BRAIN_TRAUMA_SEVERE, TRAUMA_RESILIENCE_BASIC)
	else if(worn_for >= 5 MINUTES && prob(10))
		carbon.gain_trauma_type(BRAIN_TRAUMA_MILD, TRAUMA_RESILIENCE_BASIC)
	if(worn_for >= 7 MINUTES && prob(0.5))
		blow_head(carbon)

/// An ability used without the binding: the backlash hits the brain and the body.
/obj/item/anomaly_resonator/proc/punish_use()
	to_chat(wearer, span_userdanger("Непривязанный резонатор бьёт обратной волной прямо в мозг!"))
	INVOKE_ASYNC(wearer, TYPE_PROC_REF(/mob, emote), "scream")
	wearer.apply_damage(15, BRUTE, spread_damage = TRUE)
	wearer.adjust_stamina_loss(40)
	wearer.adjust_organ_loss(ORGAN_SLOT_BRAIN, rand(8, 15))
	var/mob/living/carbon/carbon = wearer
	if(!istype(carbon))
		return
	if(prob(1))
		blow_head(carbon)
		return
	if(prob(3))
		carbon.gain_trauma_type(BRAIN_TRAUMA_SEVERE, TRAUMA_RESILIENCE_BASIC)
	else if(prob(15))
		carbon.gain_trauma_type(BRAIN_TRAUMA_MILD, TRAUMA_RESILIENCE_BASIC)

/// The worst a resonator does to an unbound wearer.
/obj/item/anomaly_resonator/proc/blow_head(mob/living/carbon/victim)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(!head)
		return
	log_combat(victim, victim, "had their head blown off by an unbound [src]")
	victim.visible_message(span_danger("Голова [victim] взрывается!"))
	new /obj/effect/gibspawner/generic(get_turf(victim))
	head.dismember()
	qdel(head)

/// Passive of the resonator `user` wears, or null.
/proc/resonance_passive_of(mob/living/user)
	var/obj/item/anomaly_resonator/resonator = locate() in user?.get_equipped_items()
	return resonator?.applied_passive

// ===== Binding implant =====

/// Whether `user` carries the resonance binding implant.
/proc/is_resonance_bound(mob/living/user)
	return !!(locate(/obj/item/implant/resonance) in user?.implants)

/**
 * Keys an anomalous resonator to its host and shields their mind from the static anomaly.
 * The corps gets it at the start of a shift; spares lie in a lockbox in the captain's locker.
 */
/obj/item/implant/resonance
	name = "имплант резонансной привязки"
	desc = "Привязывает носителя к аномальному резонатору и защищает разум от нейроинтерферентной аномалии."
	actions_types = null
	implant_info = "Активируется при установке. Позволяет безопасно пользоваться аномальным резонатором и защищает от нейроинтерферентной аномалии."

/obj/item/implant/resonance/on_implant(mob/living/target, mob/user, silent = FALSE, force = FALSE)
	. = ..()
	// A duplicate may be deleted instead of installed, so check where it ended up.
	if(. && imp_in == target)
		schedule_echo()

/// Plans the next echo: on average about once an hour, so a couple of times a round.
/obj/item/implant/resonance/proc/schedule_echo()
	addtimer(CALLBACK(src, PROC_REF(echo)), rand(RESONANCE_ECHO_MIN, RESONANCE_ECHO_MAX), TIMER_UNIQUE | TIMER_OVERRIDE)

/// The binding now and then lets the static through: hallucinations as near a supermatter.
/obj/item/implant/resonance/proc/echo()
	if(!imp_in)
		return
	schedule_echo()
	if(!cybernetic_rejection && imp_in.stat != DEAD)
		imp_in.adjust_hallucinations_up_to(RESONANCE_ECHO_DURATION, RESONANCE_ECHO_DURATION)

/obj/item/implanter/resonance
	name = "импланттер (резонансная привязка)"
	imp_type = /obj/item/implant/resonance

/obj/item/implantcase/resonance
	name = "кейс импланта — «Резонансная привязка»"
	desc = "Стеклянный кейс с имплантом резонансной привязки."
	imp_type = /obj/item/implant/resonance

/obj/item/storage/lockbox/resonance
	name = "защищённый кейс имплантов резонансной привязки"
	req_access = list(ACCESS_CAPTAIN)

/obj/item/storage/lockbox/resonance/PopulateContents()
	for(var/i in 1 to 3)
		new /obj/item/implantcase/resonance(src)
	new /obj/item/implanter/resonance(src)

/obj/structure/closet/secure_closet/captains/PopulateContents()
	. = ..()
	new /obj/item/storage/lockbox/resonance(src)

/datum/design/anomaly_resonator
	name = "Аномальный резонатор"
	desc = "Пояс, дающий носителю силу экзотической батареи."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/silver = SHEET_MATERIAL_AMOUNT, /datum/material/plasma = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/anomaly_resonator
	category = list(RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_SCIENCE)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO
