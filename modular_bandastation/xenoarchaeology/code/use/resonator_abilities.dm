/**
 * # Resonator abilities
 *
 * One active ability per battery source, granted by an anomalous resonator worn on the belt and paid in
 * battery charge: RESONANCE_COST_LIGHT for light ones, RESONANCE_COST_HEAVY for heavy ones. Targeted ones
 * reach RESONANCE_REACH tiles.
 */
/datum/action/cooldown/resonance
	name = "Резонанс"
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "spell_default"
	background_icon_state = "bg_tech"
	overlay_icon_state = "bg_tech_border"
	cooldown_time = 10 SECONDS
	/// Battery charge one use costs.
	var/cost = RESONANCE_COST_LIGHT
	/// Beam drawn from the user to a target, if any.
	var/beam_state
	/// Sound played on use.
	var/fire_sound
	/// Colour of a ring spreading from the user on use, if any.
	var/wave_color
	/// Damage multiplier: a large find's abilities hit harder.
	var/power = 1
	/// A large find's shock and fire jump on to more targets.
	var/chain = FALSE
	/// Only a living target other than the user will do.
	var/needs_living = FALSE

/datum/action/cooldown/resonance/New(Target, original)
	. = ..()
	desc = "[desc] Стоит [cost] заряда."

/datum/action/cooldown/resonance/IsAvailable(feedback)
	. = ..()
	if(!.)
		return FALSE
	var/obj/item/anomaly_resonator/resonator = target
	return istype(resonator) && resonator.powered()

/datum/action/cooldown/resonance/Activate(atom/target_atom)
	var/obj/item/anomaly_resonator/resonator = target
	if(click_to_activate && (!target_atom || get_dist(owner, target_atom) > RESONANCE_REACH || !(target_atom in view(RESONANCE_REACH, owner))))
		owner.balloon_alert(owner, "слишком далеко!")
		return FALSE
	if(!valid_target(target_atom))
		return FALSE
	if(!resonator.spend(cost))
		return FALSE
	feedback(target_atom)
	fire(target_atom)
	StartCooldown()
	return TRUE

/// The look and sound of a use.
/datum/action/cooldown/resonance/proc/feedback(atom/target_atom)
	if(fire_sound)
		playsound(owner, fire_sound, 50, TRUE)
	if(beam_state && target_atom && target_atom != owner)
		owner.Beam(target_atom, icon_state = beam_state, time = 0.5 SECONDS)
	if(wave_color)
		new /obj/effect/temp_visual/circle_wave/anomaly_pulse(get_turf(owner), wave_color, 3.5)

/// Living within `reach` of `from` this ability may still hit: not its user, not already hit.
/datum/action/cooldown/resonance/proc/next_in_chain(atom/from, list/hit, reach = 3)
	for(var/mob/living/candidate in view(reach, get_turf(from)))
		if(candidate != owner && !(candidate in hit) && candidate.stat != DEAD)
			return candidate
	return null

/// Whether something the target carries keeps it on its feet.
/datum/action/cooldown/resonance/proc/anchored_target(mob/living/victim)
	return field_artefact_protection(victim) & FIELD_ARTEFACT_ANCHOR

/// Whether the ability can act on `target_atom`; checked before any charge is spent.
/datum/action/cooldown/resonance/proc/valid_target(atom/target_atom)
	return !needs_living || living_target(target_atom)

/// What the ability does once paid for.
/datum/action/cooldown/resonance/proc/fire(atom/target_atom)
	return

/// Tiles a beam from the owner crosses towards `target_atom`, up to the first wall, without the owner's own tile.
/datum/action/cooldown/resonance/proc/beam_line(atom/target_atom)
	. = list()
	var/turf/start = get_turf(owner)
	for(var/turf/spot as anything in get_line(start, get_turf(target_atom)))
		if(spot == start)
			continue
		if(spot.density)
			break
		. += spot

/// A living target the ability can act on, or null with a balloon.
/datum/action/cooldown/resonance/proc/living_target(atom/target_atom)
	if(isliving(target_atom) && target_atom != owner)
		return target_atom
	owner.balloon_alert(owner, "нужна живая цель")
	return null

// ===== Light =====

/datum/action/cooldown/resonance/shock_bolt
	name = "Разряд"
	desc = "Бьёт током выбранную цель."
	button_icon_state = "zap"
	click_to_activate = TRUE
	needs_living = TRUE

/datum/action/cooldown/resonance/shock_bolt/fire(atom/target_atom)
	var/mob/living/victim = target_atom
	owner.Beam(victim, icon_state = "lightning[rand(1, 12)]", time = 0.5 SECONDS)
	playsound(victim, 'sound/effects/magic/lightningbolt.ogg', 50, TRUE)
	victim.electrocute_act(20 * power, owner, 1, SHOCK_NOGLOVES)
	if(!chain)
		return
	var/list/hit = list(victim)
	var/mob/living/last = victim
	for(var/i in 1 to 2)
		var/mob/living/next = next_in_chain(last, hit)
		if(!next)
			return
		last.Beam(next, icon_state = "lightning[rand(1, 12)]", time = 0.5 SECONDS)
		next.electrocute_act(15 * power, owner, 1, SHOCK_NOGLOVES)
		hit += next
		last = next

/datum/action/cooldown/resonance/haste
	name = "Ускорение"
	desc = "Ненадолго ускоряет вас."
	button_icon_state = "time"
	cooldown_time = 15 SECONDS
	fire_sound = 'sound/effects/magic/tail_swing.ogg'
	wave_color = LIGHT_COLOR_LIGHT_CYAN

/datum/action/cooldown/resonance/haste/fire(atom/target_atom)
	var/mob/living/runner = owner
	runner.apply_status_effect(/datum/status_effect/artifact/sprint, 10 SECONDS)

/datum/action/cooldown/resonance/haste/strong
	name = "Ускорение времени"
	desc = "На полминуты вы выпадаете из времени: двигаетесь и работаете гораздо быстрее, оставляя за собой проекции."
	cooldown_time = 45 SECONDS
	cost = RESONANCE_COST_HEAVY
	fire_sound = 'sound/effects/magic/timeparadox2.ogg'
	wave_color = LIGHT_COLOR_LIGHT_CYAN

/datum/action/cooldown/resonance/haste/strong/fire(atom/target_atom)
	var/mob/living/runner = owner
	runner.apply_status_effect(/datum/status_effect/artifact/sprint, 30 SECONDS)
	runner.adjust_timed_status_effect(30 SECONDS, /datum/status_effect/accelerando, 30 SECONDS)

/datum/action/cooldown/resonance/rad_burst
	name = "Радиационный выброс"
	desc = "Облучает выбранное место."
	button_icon_state = "bonechill"
	click_to_activate = TRUE
	beam_state = "g_beam"
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/rad_burst/fire(atom/target_atom)
	var/turf/spot = get_turf(target_atom)
	new /obj/effect/temp_visual/circle_wave/anomaly_pulse(spot, "#7fdd58", 3.5)
	playsound(spot, 'sound/effects/health/slowbeat.ogg', 80)
	radiation_pulse(spot, max_range = 3, threshold = RAD_LIGHT_INSULATION)
	if(isliving(target_atom) && target_atom != owner)
		var/mob/living/victim = target_atom
		victim.apply_damage(15 * power, TOX)

/datum/action/cooldown/resonance/static_jam
	name = "Помехи"
	desc = "Забивает голову цели помехами: спутанность и белый шум."
	button_icon_state = "telepathy"
	click_to_activate = TRUE
	beam_state = "sendbeam"
	needs_living = TRUE

/datum/action/cooldown/resonance/static_jam/fire(atom/target_atom)
	var/mob/living/victim = target_atom
	if(resonance_passive_of(victim) == ARTIFACT_ENERGY_PSIONIC)
		return
	victim.flash_act(intensity = 2, visual = TRUE, type = /atom/movable/screen/fullscreen/flash/static)
	victim.adjust_confusion(5 SECONDS)
	SEND_SOUND(victim, 'sound/items/radiostatic.ogg')

/datum/action/cooldown/resonance/flash_cone
	name = "Вспышка"
	desc = "Слепит всех вокруг, кроме вас."
	button_icon_state = "blind"
	fire_sound = 'sound/effects/magic/blind.ogg'
	wave_color = COLOR_WHITE

/datum/action/cooldown/resonance/flash_cone/fire(atom/target_atom)
	playsound(owner, 'sound/items/weapons/flash.ogg', 60, TRUE)
	for(var/mob/living/victim in view(3, owner))
		if(victim != owner)
			victim.flash_act(affect_silicon = TRUE)

/datum/action/cooldown/resonance/hallucinate
	name = "Наваждение"
	desc = "Насылает галлюцинации на цель."
	button_icon_state = "terrify"
	click_to_activate = TRUE
	needs_living = TRUE
	cooldown_time = 25 SECONDS
	beam_state = "curse0"
	fire_sound = 'sound/effects/magic/curse.ogg'

/datum/action/cooldown/resonance/hallucinate/fire(atom/target_atom)
	var/mob/living/victim = target_atom
	victim.adjust_hallucinations(30 SECONDS)
	victim.adjust_confusion(10 SECONDS)
	victim.cause_hallucination(pick(/datum/hallucination/delusion/preset/demon, /datum/hallucination/delusion/preset/skeleton, /datum/hallucination/delusion/preset/zombie, /datum/hallucination/delusion/preset/carp), "аномальный резонатор")

/datum/action/cooldown/resonance/transmute
	name = "Пространственный сдвиг"
	desc = "Перекраивает пол, стены и вещи вокруг выбранного места в другой материал."
	button_icon_state = "spacetime"
	click_to_activate = TRUE
	beam_state = "cosmic_beam"
	fire_sound = 'sound/effects/magic/cosmic_expansion.ogg'

/datum/action/cooldown/resonance/transmute/fire(atom/target_atom)
	var/datum/dimension_theme/theme = SSmaterials.dimensional_themes[pick(subtypesof(/datum/dimension_theme))]
	for(var/turf/spot as anything in spiral_range_turfs(3, get_turf(target_atom)))
		if(theme.can_convert(spot))
			theme.apply_theme(spot, show_effect = TRUE)

/datum/action/cooldown/resonance/fog
	name = "Туман"
	desc = "Окутывает вас облаком тумана."
	button_icon_state = "smoke"
	fire_sound = 'sound/effects/magic/smoke.ogg'

/datum/action/cooldown/resonance/fog/fire(atom/target_atom)
	do_smoke(range = 4, holder = owner, location = get_turf(owner))

// ===== Heavy =====

/datum/action/cooldown/resonance/emp_burst
	name = "Электромагнитный импульс"
	desc = "ЭМИ по всему вокруг вас; вас и ваши вещи не задевает."
	button_icon_state = "emp"
	cooldown_time = 25 SECONDS
	wave_color = LIGHT_COLOR_BLUE
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/emp_burst/fire(atom/target_atom)
	var/list/spared = owner.get_all_contents()
	new /obj/effect/temp_visual/emp/pulse(get_turf(owner))
	playsound(owner, 'sound/effects/magic/disable_tech.ogg', 60, TRUE)
	for(var/atom/movable/thing in range(3, owner))
		if(!(thing in spared))
			thing.emp_act(EMP_HEAVY)

/datum/action/cooldown/resonance/fire_beam
	name = "Огненный луч"
	desc = "Выжигает линию огня до выбранной точки."
	button_icon_state = "firebeam"
	click_to_activate = TRUE
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/fire_beam/fire(atom/target_atom)
	playsound(owner, 'sound/effects/magic/fireball.ogg', 60, TRUE)
	var/list/hit = list()
	var/list/line = beam_line(target_atom)
	for(var/turf/spot as anything in line)
		new /obj/effect/hotspot(spot)
		spot.hotspot_expose(700, 50, 1)
		for(var/mob/living/victim in spot)
			burn_target(victim)
			hit += victim
	if(length(line))
		owner.Beam(line[length(line)], icon_state = "solar_beam", time = 0.5 SECONDS)
	if(!chain)
		return
	var/atom/last = get_turf(target_atom)
	for(var/i in 1 to 2)
		var/mob/living/next = next_in_chain(last, hit)
		if(!next)
			return
		last.Beam(next, icon_state = "solar_beam", beam_type = /obj/effect/ebeam/reacting/fire, time = 0.5 SECONDS)
		burn_target(next)
		hit += next
		last = next

/datum/action/cooldown/resonance/fire_beam/proc/burn_target(mob/living/victim)
	victim.apply_damage(15 * power, BURN)
	victim.adjust_fire_stacks(2)
	victim.ignite_mob()

/datum/action/cooldown/resonance/fireball
	name = "Огненный шар"
	desc = "Огненный шар в выбранную точку: небольшой взрыв, цель загорается."
	button_icon_state = "fireball"
	click_to_activate = TRUE
	fire_sound = 'sound/effects/magic/fireball.ogg'
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/fireball/fire(atom/target_atom)
	var/obj/projectile/magic/fireball/resonance/ball = new(get_turf(owner))
	ball.damage *= power
	ball.firer = owner
	ball.aim_projectile(target_atom, owner)
	ball.fire()

/// A melter core's fireball: a small blast that sets its target alight.
/obj/projectile/magic/fireball/resonance
	damage = 15
	exp_light = 1
	exp_fire = 2
	exp_flash = 1

/obj/projectile/magic/fireball/resonance/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/mob/living/victim = target
	if(istype(victim))
		victim.adjust_fire_stacks(3)
		victim.ignite_mob()

/datum/action/cooldown/resonance/telekinesis
	name = "Телекинез"
	desc = "Швыряет выбранную цель прочь от вас, будь то предмет или человек."
	button_icon_state = "repulse"
	click_to_activate = TRUE
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY
	beam_state = "kinesis"
	fire_sound = 'sound/effects/magic/repulse.ogg'

/datum/action/cooldown/resonance/telekinesis/valid_target(atom/target_atom)
	var/atom/movable/thrown = target_atom
	if(istype(thrown) && !thrown.anchored && thrown != owner)
		return TRUE
	owner.balloon_alert(owner, "не сдвинуть")
	return FALSE

/datum/action/cooldown/resonance/telekinesis/fire(atom/target_atom)
	var/atom/movable/thrown = target_atom
	if(isliving(thrown))
		var/mob/living/victim = thrown
		if(anchored_target(victim))
			return
		victim.Knockdown(2 SECONDS)
	new /obj/effect/temp_visual/gravpush(get_turf(thrown))
	var/turf/away = get_ranged_target_turf(thrown, get_dir(owner, thrown), 6)
	thrown.throw_at(away, 6, 3, owner)

/datum/action/cooldown/resonance/rust_beam
	name = "Токсичный луч"
	desc = "Луч, разъедающий ржавчиной всё на пути и отравляющий того, в кого попадёт."
	button_icon_state = "ash"
	click_to_activate = TRUE
	fire_sound = 'sound/effects/magic/disintegrate.ogg'
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/rust_beam/fire(atom/target_atom)
	owner.Beam(get_turf(target_atom), icon_state = "drainbeam", time = 0.5 SECONDS)
	for(var/turf/spot as anything in get_line(get_turf(owner), get_turf(target_atom)))
		if(spot == get_turf(owner))
			continue
		spot.rust_heretic_act(1)
		for(var/mob/living/victim in spot)
			victim.reagents?.add_reagent(/datum/reagent/toxin/plasma, 5)
			victim.apply_damage(15 * power, TOX)

/datum/action/cooldown/resonance/vampirism
	name = "Вампиризм"
	desc = "Вытягивает кровь и жизнь цели, залечивая ваши раны."
	button_icon_state = "exsanguinating_strike"
	click_to_activate = TRUE
	needs_living = TRUE
	fire_sound = 'sound/effects/magic/enter_blood.ogg'
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/vampirism/fire(atom/target_atom)
	var/mob/living/victim = target_atom
	owner.Beam(victim, icon_state = "blood", time = 0.5 SECONDS)
	victim.apply_damage(15 * power, BRUTE)
	victim.bleed(30)
	new /obj/effect/temp_visual/dir_setting/bloodsplatter(get_turf(victim), get_dir(owner, victim))
	new /obj/effect/temp_visual/heal(get_turf(owner), "#b74561")
	var/mob/living/drinker = owner
	drinker.heal_overall_damage(brute = 10, burn = 10)
	drinker.adjust_blood_volume(30)

/datum/action/cooldown/resonance/gut_rip
	name = "Вырвать нутро"
	desc = "Дважды рвёт плоть цели, выбрасывая кровь и потроха."
	button_icon_state = "scream_for_me"
	click_to_activate = TRUE
	needs_living = TRUE
	beam_state = "blood_beam"
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/gut_rip/fire(atom/target_atom)
	var/mob/living/victim = target_atom
	rip(victim)
	addtimer(CALLBACK(src, PROC_REF(rip), victim), 0.5 SECONDS)

/datum/action/cooldown/resonance/gut_rip/proc/rip(mob/living/victim)
	if(QDELETED(victim))
		return
	playsound(victim, 'sound/effects/splat.ogg', 60, TRUE)
	victim.apply_damage(15 * power, BRUTE)
	victim.bleed(25)
	new /obj/effect/gibspawner/generic(get_turf(victim))

/datum/action/cooldown/resonance/gravity_slam
	name = "Гравитационный удар"
	desc = "Отбрасывает всё и всех вокруг вас."
	button_icon_state = "repulse"
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY
	wave_color = "#a070ff"

/datum/action/cooldown/resonance/gravity_slam/fire(atom/target_atom)
	playsound(owner, 'sound/effects/magic/repulse.ogg', 60, TRUE)
	for(var/atom/movable/thing in orange(3, owner))
		if(thing.anchored || !(isliving(thing) || isitem(thing)))
			continue
		if(isliving(thing))
			var/mob/living/victim = thing
			if(anchored_target(victim))
				continue
			victim.Knockdown(2 SECONDS)
		thing.throw_at(get_ranged_target_turf(thing, get_dir(owner, thing), 4), 4, 2, owner)

/datum/action/cooldown/resonance/blink
	name = "Блюспейс-рывок"
	desc = "Мгновенно переносит вас в выбранную точку."
	button_icon_state = "blink"
	click_to_activate = TRUE
	fire_sound = 'sound/effects/magic/blink.ogg'
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/blink/valid_target(atom/target_atom)
	var/turf/spot = get_turf(target_atom)
	if(spot && !spot.is_blocked_turf(exclude_mobs = TRUE))
		return TRUE
	owner.balloon_alert(owner, "место занято")
	return FALSE

/datum/action/cooldown/resonance/blink/fire(atom/target_atom)
	var/turf/spot = get_turf(target_atom)
	var/turf/departure = get_turf(owner)
	if(do_teleport(owner, spot, asoundout = 'sound/effects/magic/teleport_app.ogg', channel = TELEPORT_CHANNEL_BLUESPACE))
		new /obj/effect/temp_visual/dir_setting/ninja/phase/out(departure, owner.dir)
		new /obj/effect/temp_visual/dir_setting/ninja/phase(get_turf(owner), owner.dir)

/datum/action/cooldown/resonance/mutate
	name = "Искажение плоти"
	desc = "Перекраивает конечность и орган цели, раня её; зверя разрывает на части, мегафауну лишь ранит."
	button_icon_state = "mutate"
	click_to_activate = TRUE
	beam_state = "lichbeam"
	fire_sound = 'sound/effects/magic/mutate.ogg'
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY

/datum/action/cooldown/resonance/mutate/valid_target(atom/target_atom)
	if(target_atom != owner && (iscarbon(target_atom) || isanimal_or_basicmob(target_atom)))
		return TRUE
	owner.balloon_alert(owner, "эту плоть не исказить")
	return FALSE

/// Rescrambles a person's limbs and organs, tearing them a little; a beast, simpler flesh, comes apart entirely,
/// while megafauna is too much flesh to warp and only gets hurt.
/datum/action/cooldown/resonance/mutate/fire(atom/target_atom)
	if(iscarbon(target_atom))
		var/mob/living/carbon/person = target_atom
		person.bioscramble(owner)
		person.apply_damage(10 * power, BRUTE)
		return
	var/mob/living/beast = target_atom
	if(ismegafauna(beast))
		beast.apply_damage(15 * power, BRUTE)
		return
	beast.visible_message(span_danger("Плоть [beast] выворачивается наизнанку и разлетается ошмётками!"))
	log_combat(owner, beast, "gibbed with a resonator flesh warp")
	beast.gib()

/datum/action/cooldown/resonance/vortex_pull
	name = "Стяжка"
	desc = "Стягивает всех живых вокруг к вам и сбивает с ног. Предметы не трогает."
	button_icon_state = "void_magnet"
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY
	wave_color = COLOR_GRAY

/datum/action/cooldown/resonance/vortex_pull/fire(atom/target_atom)
	playsound(owner, 'sound/effects/magic/voidblink.ogg', 60, TRUE)
	for(var/mob/living/victim in orange(4, owner))
		if(anchored_target(victim))
			continue
		owner.Beam(victim, icon_state = "chain", time = 0.5 SECONDS)
		victim.Knockdown(3 SECONDS)
		for(var/i in 1 to 3)
			step_towards(victim, owner)

/datum/action/cooldown/resonance/energy_shield
	name = "Энергетический щит"
	desc = "На полминуты окружает вас щитом, принимающим три попадания."
	button_icon_state = "shield"
	cooldown_time = 60 SECONDS
	cost = RESONANCE_COST_HEAVY
	fire_sound = 'sound/effects/magic/forcewall.ogg'
	wave_color = LIGHT_COLOR_LIGHT_CYAN

/datum/action/cooldown/resonance/energy_shield/fire(atom/target_atom)
	var/obj/item/anomaly_resonator/resonator = target
	if(resonator.GetComponent(/datum/component/shielded))
		return
	var/datum/component/shielded/shield = resonator.AddComponent(/datum/component/shielded, max_charges = 3, recharge_start_delay = 0, charge_increment_delay = 0, charge_recovery = 0, starting_charges = 3, show_charge_as_alpha = TRUE)
	QDEL_IN(shield, 30 SECONDS)

/**
 * A large find's own effect: a touch effect strikes the chosen target, an aura or pulse effect bursts
 * at the chosen spot instead of around the wearer.
 */
/datum/action/cooldown/resonance/artifact_release
	name = "Высвобождение"
	desc = "Высвобождает эффект крупной находки в выбранную цель или точку."
	button_icon_state = "arcane_barrage"
	click_to_activate = TRUE
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY
	beam_state = "light_beam"
	fire_sound = 'sound/effects/magic/charge.ogg'

/datum/action/cooldown/resonance/artifact_release/fire(atom/target_atom)
	var/obj/item/anomaly_resonator/resonator = target
	var/datum/artifact_effect/effect = resonator.battery?.held_effect
	if(!effect)
		return
	var/datum/artifact_energy_kind/kind = artifact_energy_kind(effect.energy_kind)
	var/turf/spot = get_turf(target_atom)
	to_chat(owner, span_notice("Высвобождено: <b>[effect.label_name]</b>."))
	new /obj/effect/temp_visual/circle_wave/anomaly_pulse(spot, kind.color, max(effect.range, 1) + 0.5)
	if(effect.release_method == ARTIFACT_RELEASE_TOUCH && isliving(target_atom))
		effect.do_effect_touch(target_atom)
	else
		var/atom/old_holder = effect.holder
		effect.holder = spot
		effect.do_effect_pulse(effect.maximum_charges)
		effect.holder = old_holder
	for(var/mob/living/victim in range(max(effect.range, 1), spot))
		if(victim == owner)
			continue
		resonance_kind_hit(victim, effect.energy_kind, 20 * power, owner)
		if(istype(effect, /datum/artifact_effect/temperature/cold))
			victim.adjust_bodytemperature(-150, min_temp = TCMB)
			victim.apply_damage(10 * power, BURN)
			if(prob(20))
				victim.apply_status_effect(/datum/status_effect/freon, 5 SECONDS)
		else if(istype(effect, /datum/artifact_effect/temperature/heat))
			victim.adjust_bodytemperature(150)
			victim.adjust_fire_stacks(3)
			victim.ignite_mob()

/// Ice beam: frost burns and chills everyone on the line, and may freeze them solid.
/datum/action/cooldown/resonance/ice_beam
	name = "Ледяной луч"
	desc = "Луч стужи до выбранной точки: обмораживает и может вморозить в лёд."
	button_icon_state = "icebeam"
	click_to_activate = TRUE
	cooldown_time = 25 SECONDS
	cost = RESONANCE_COST_HEAVY
	fire_sound = 'sound/effects/magic/fleshtostone.ogg'

/datum/action/cooldown/resonance/ice_beam/fire(atom/target_atom)
	var/list/line = beam_line(target_atom)
	for(var/turf/spot as anything in line)
		for(var/mob/living/victim in spot)
			victim.apply_damage(15 * power, BURN)
			victim.adjust_bodytemperature(-120, min_temp = TCMB)
			if(prob(20))
				victim.apply_status_effect(/datum/status_effect/freon, 5 SECONDS)
	if(length(line))
		var/turf/endpoint = line[length(line)]
		owner.Beam(endpoint, icon_state = "b_beam", time = 0.5 SECONDS)
		new /obj/effect/temp_visual/circle_wave/anomaly_pulse(endpoint, LIGHT_COLOR_LIGHT_CYAN, 0.8)

/// Damage of energy `kind` dealt by a released large find, `amount` of it.
/proc/resonance_kind_hit(mob/living/victim, kind, amount, mob/living/user)
	switch(kind)
		if(ARTIFACT_ENERGY_ELECTROMAGNETIC)
			victim.electrocute_act(amount, user, 1, SHOCK_NOGLOVES)
		if(ARTIFACT_ENERGY_CONCENTRATED)
			victim.apply_damage(amount, BURN)
			victim.adjust_fire_stacks(2)
			victim.ignite_mob()
		if(ARTIFACT_ENERGY_PARTICLE)
			victim.apply_damage(amount, TOX)
		if(ARTIFACT_ENERGY_ORGANIC)
			victim.apply_damage(amount, BRUTE)
			victim.bleed(amount)
		if(ARTIFACT_ENERGY_PSIONIC)
			victim.adjust_organ_loss(ORGAN_SLOT_BRAIN, amount / 2)
			victim.adjust_stamina_loss(amount)
			victim.adjust_confusion(5 SECONDS)
		if(ARTIFACT_ENERGY_BLUESPACE)
			victim.apply_damage(amount, BRUTE)
			if(user)
				victim.throw_at(get_ranged_target_turf(victim, get_dir(user, victim), 2), 2, 2, user)
		if(ARTIFACT_ENERGY_SYNTHESIS)
			victim.apply_damage(amount, BURN)
			victim.acid_act(10, 10)

/// Energy kind of a large find -> the second ability a resonator grants for it.
GLOBAL_LIST_INIT(resonance_second_by_kind, list(
	ARTIFACT_ENERGY_ELECTROMAGNETIC = /datum/action/cooldown/resonance/shock_bolt,
	ARTIFACT_ENERGY_CONCENTRATED = /datum/action/cooldown/resonance/fire_beam,
	ARTIFACT_ENERGY_PARTICLE = /datum/action/cooldown/resonance/rad_burst,
	ARTIFACT_ENERGY_ORGANIC = /datum/action/cooldown/resonance/vampirism,
	ARTIFACT_ENERGY_PSIONIC = /datum/action/cooldown/resonance/hallucinate,
	ARTIFACT_ENERGY_BLUESPACE = /datum/action/cooldown/resonance/blink,
	ARTIFACT_ENERGY_SYNTHESIS = /datum/action/cooldown/resonance/ice_beam,
))

/// Battery source -> a passive a resonator gives instead of its energy kind's.
GLOBAL_LIST_INIT(resonance_passive_by_source, list(
	/obj/item/field_artefact/flyer = RESONANCE_PASSIVE_FLIGHT,
	/obj/item/assembly/signaler/anomaly/planetary/melter = RESONANCE_PASSIVE_THERMAL,
))

/// Battery source -> the ability a resonator grants for it.
GLOBAL_LIST_INIT(resonance_ability_by_source, list(
	/obj/item/field_artefact/pruzhina = /datum/action/cooldown/resonance/shock_bolt,
	/obj/item/assembly/signaler/anomaly/planetary/sparkler = /datum/action/cooldown/resonance/shock_bolt,
	/obj/item/assembly/signaler/anomaly/planetary/pulsar = /datum/action/cooldown/resonance/emp_burst,
	/obj/item/field_artefact/zjar = /datum/action/cooldown/resonance/fire_beam,
	/obj/item/assembly/signaler/anomaly/planetary/melter = /datum/action/cooldown/resonance/fireball,
	/obj/item/assembly/signaler/anomaly/pyro = /datum/action/cooldown/resonance/fire_beam,
	/obj/item/assembly/signaler/anomaly/planetary/phantom = /datum/action/cooldown/resonance/telekinesis,
	/obj/item/assembly/signaler/anomaly/ectoplasm = /datum/action/cooldown/resonance/telekinesis,
	/obj/item/assembly/signaler/anomaly/planetary/plasmasoul = /datum/action/cooldown/resonance/rust_beam,
	/obj/item/field_artefact/flyer = /datum/action/cooldown/resonance/haste,
	/obj/item/assembly/signaler/anomaly/planetary/chrono = /datum/action/cooldown/resonance/haste/strong,
	/obj/item/assembly/signaler/anomaly/planetary/transfusion = /datum/action/cooldown/resonance/vampirism,
	/obj/item/assembly/signaler/anomaly/planetary/veins = /datum/action/cooldown/resonance/gut_rip,
	/obj/item/assembly/signaler/anomaly/planetary/heartbeat = /datum/action/cooldown/resonance/rad_burst,
	/obj/item/assembly/signaler/anomaly/planetary/tvstatic = /datum/action/cooldown/resonance/static_jam,
	/obj/item/field_artefact/gravi = /datum/action/cooldown/resonance/gravity_slam,
	/obj/item/assembly/signaler/anomaly/grav = /datum/action/cooldown/resonance/gravity_slam,
	/obj/item/field_artefact/svetlyak = /datum/action/cooldown/resonance/flash_cone,
	/obj/item/assembly/signaler/anomaly/bluespace = /datum/action/cooldown/resonance/blink,
	/obj/item/assembly/signaler/anomaly/hallucination = /datum/action/cooldown/resonance/hallucinate,
	/obj/item/assembly/signaler/anomaly/bioscrambler = /datum/action/cooldown/resonance/mutate,
	/obj/item/assembly/signaler/anomaly/dimensional = /datum/action/cooldown/resonance/transmute,
	/obj/item/assembly/signaler/anomaly/weather = /datum/action/cooldown/resonance/fog,
	/obj/item/assembly/signaler/anomaly/vortex = /datum/action/cooldown/resonance/vortex_pull,
	/obj/item/assembly/signaler/anomaly/flux = /datum/action/cooldown/resonance/energy_shield,
))
