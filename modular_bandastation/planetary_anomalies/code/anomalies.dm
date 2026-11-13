/**
 * # Pulsing anomalies
 *
 * Ten living anomalies of Shiptest (shiptest-ss13/Shiptest `code/game/objects/effects/anomalies`), moved
 * onto our TG anomaly: each pulses on its own cooldown over its reach, and the solid ones answer a touch.
 * They glow in their own colour, give off their own particles, send a ring out with each slow pulse and
 * drift about, never further than ANOMALY_LEASH from where they appeared. On planets they never die;
 * neutralizing one still yields its core.
 */
/obj/effect/anomaly/pulsing
	abstract_type = /obj/effect/anomaly/pulsing
	icon = 'modular_bandastation/planetary_anomalies/icons/anomalies.dmi'
	move_chance = 10
	/// Reach of its pulses, in tiles.
	var/effect_range = 3
	/// Time between its pulses.
	var/pulse_delay = 5 SECONDS
	/// Particles it gives off.
	var/particles_type
	/// Their colour, if not their own.
	var/particles_color
	/// Where it appeared; it drifts no further than ANOMALY_LEASH from here.
	var/turf/home
	/// Corps journal protocol, opened when it is first read off the station.
	var/datum/expedition_record/xenoarch_find/journal_record
	COOLDOWN_DECLARE(pulse_cooldown)
	COOLDOWN_DECLARE(touch_cooldown)

/// How far a living anomaly drifts from where it appeared.
#define ANOMALY_LEASH 5

/obj/effect/anomaly/pulsing/Initialize(mapload, new_lifespan, drops_core)
	. = ..()
	home = get_turf(src)
	if(particles_type)
		particles = new particles_type
		if(particles_color)
			particles.color = particles_color

/obj/effect/anomaly/pulsing/Destroy()
	home = null
	journal_record = null
	QDEL_NULL(particles)
	return ..()

/// Writes a fact to its protocol, opening one first; only off the station, where the corps works.
/obj/effect/anomaly/pulsing/proc/journal_note(mob/user, text)
	var/turf/here = get_turf(src)
	if(!here || is_station_level(here.z))
		return
	journal_record ||= new(xenoarch_new_serial(), src)
	journal_record.log_observation(user, src, text)

/obj/effect/anomaly/pulsing/anomalyNeutralize()
	journal_note(ismob(usr) ? usr : null, "Аномалия «[name]» нейтрализована.")
	var/obj/item/assembly/signaler/anomaly/planetary/core = anomaly_core
	if(istype(core))
		core.journal_record = journal_record
	var/turf/spot = get_turf(src)
	. = ..()
	// Over the core cap the core never drops and goes with the anomaly.
	if(istype(core) && !QDELETED(core) && isturf(core.loc))
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_FIND_RECOVERED, core, ismob(usr) ? usr : null, spot)

/obj/effect/anomaly/pulsing/move_anomaly()
	var/turf/next = get_step(src, pick(GLOB.alldirs))
	if(next && (!home || get_dist(next, home) <= ANOMALY_LEASH))
		Move(next, get_dir(src, next))

/obj/effect/anomaly/pulsing/anomalyEffect(seconds_per_tick)
	. = ..()
	if(!COOLDOWN_FINISHED(src, pulse_cooldown))
		return
	COOLDOWN_START(src, pulse_cooldown, pulse_delay)
	if(pulse_delay >= 2 SECONDS)
		new /obj/effect/temp_visual/circle_wave/anomaly_pulse(loc, light_color, effect_range + 0.5)
	pulse()

/obj/effect/anomaly/pulsing/Bumped(atom/movable/bumper)
	. = ..()
	if(!COOLDOWN_FINISHED(src, touch_cooldown))
		return
	COOLDOWN_START(src, touch_cooldown, 1 SECONDS)
	touched(bumper)

/// One pulse over its reach.
/obj/effect/anomaly/pulsing/proc/pulse()
	return

/// Something walked into it.
/obj/effect/anomaly/pulsing/proc/touched(atom/movable/bumper)
	return

/// A random tile up to `reach` away, or null off the map.
/obj/effect/anomaly/pulsing/proc/random_spot(reach)
	return locate(x + rand(-reach, reach), y + rand(-reach, reach), z)

/// Makes `anomaly` a planet fixture: it never dies.
/proc/settle_planetary_anomaly(obj/effect/anomaly/anomaly)
	anomaly.immortal = TRUE
	anomaly.countdown?.stop()

/// A ring spreading over an anomaly's reach as it pulses.
/obj/effect/temp_visual/circle_wave/anomaly_pulse
	duration = 1 SECONDS
	max_alpha = 160

/obj/effect/temp_visual/circle_wave/anomaly_pulse/Initialize(mapload, color, scale)
	amount_to_scale = scale
	return ..(mapload, color)

// ===== Chronograph =====

/// Speeds up everyone around it; the closer, the longer it lasts.
/obj/effect/anomaly/pulsing/chronograph
	name = "темпоральная аномалия"
	desc = "Время бьётся вперёд всё быстрее и быстрее. Ускорение жизни постоянно, и здесь оно движет реальностью."
	icon_state = "chronograph"
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/chrono
	effect_range = 6
	pulse_delay = 1 SECONDS
	light_range = 6
	light_color = LIGHT_COLOR_LIGHT_CYAN
	particles_type = /particles/grav_field_float
	particles_color = LIGHT_COLOR_LIGHT_CYAN

/obj/effect/anomaly/pulsing/chronograph/pulse()
	for(var/mob/living/victim in orange(effect_range, src))
		var/power = effect_range - get_dist(victim, src)
		if(power <= 0)
			continue
		victim.adjust_timed_status_effect(power * 1 SECONDS, /datum/status_effect/accelerando, power * 30 SECONDS)
		if(prob(10))
			to_chat(victim, span_warning(pick("Время утекает сквозь пальцы.", "Мир вокруг становится медленнее.", "Никто больше не будет так быстр, как вы.", "Секунды тянутся часами.", "Каждый миг — вечность.")))
		do_sparks(2, TRUE, victim, spark_type = /datum/effect_system/basic/spark_spread/quantum)

// ===== Heartbeat =====

/// Throbs with radiation; now and then it scorches a spot nearby.
/obj/effect/anomaly/pulsing/heartbeat
	name = "радиационная пульсирующая аномалия"
	desc = "Пульсирующая вершина, разносящая по миру вокруг себя опухоль."
	icon_state = "heartbeat"
	density = TRUE
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/heartbeat
	pulse_delay = 6 SECONDS
	light_color = LIGHT_COLOR_GREEN
	particles_type = /particles/embers
	particles_color = LIGHT_COLOR_GREEN
	/// Pulses since the last scorch.
	var/beats = 0

/obj/effect/anomaly/pulsing/heartbeat/pulse()
	playsound(src, 'sound/effects/health/slowbeat.ogg', 100)
	radiation_pulse(src, max_range = 2, threshold = RAD_LIGHT_INSULATION)
	if(++beats < 4)
		return
	beats = 0
	var/turf/spot = random_spot(effect_range)
	if(!spot)
		return
	playsound(spot, 'sound/effects/health/slowbeat.ogg', 100)
	radiation_pulse(spot, max_range = effect_range, threshold = RAD_LIGHT_INSULATION)
	for(var/mob/living/carbon/victim in range(effect_range, spot))
		victim.apply_damage(10, BURN)
		to_chat(victim, span_warning("На коже вскрываются радиационные ожоги."))

/obj/effect/anomaly/pulsing/heartbeat/touched(atom/movable/bumper)
	var/turf/spot = random_spot(effect_range)
	if(!spot)
		return
	playsound(spot, 'sound/effects/health/slowbeat.ogg', 100)
	radiation_pulse(spot, max_range = effect_range, threshold = RAD_LIGHT_INSULATION)

// ===== Melter =====

/// Eats away worn gear and loose items around it with acid.
/obj/effect/anomaly/pulsing/melter
	name = "коррозионная аномалия"
	desc = "Вечно горящее зелёное пламя, готовое хлестнуть по всему, что подойдёт слишком близко."
	icon_state = "melter"
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/melter
	effect_range = 2
	pulse_delay = 10 SECONDS
	light_color = "#7cfc00"
	particles_type = /particles/acid

/obj/effect/anomaly/pulsing/melter/pulse()
	for(var/mob/living/carbon/victim in range(effect_range, src))
		for(var/obj/item/worn as anything in victim.get_equipped_items())
			worn.acid_act(20, 20)
	for(var/obj/item/loose in range(effect_range, src))
		loose.acid_act(20, 10)

// ===== Phantom =====

/// Sends grasping hands at everyone alive around it.
/obj/effect/anomaly/pulsing/phantom
	name = "психокинетическая аномалия"
	desc = "Знакомый силуэт. Он зовёт к себе. Он кричит вам."
	icon_state = "phantom"
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/phantom
	pulse_delay = 2 SECONDS
	move_chance = 25
	light_color = "#9aa0c8"
	particles_type = /particles/echo

/obj/effect/anomaly/pulsing/phantom/pulse()
	for(var/mob/living/carbon/victim in range(effect_range, src))
		if(victim.stat != DEAD)
			fire_curse_hand(victim, projectile_type = /obj/projectile/curse_hand/phantom)

/obj/projectile/curse_hand/phantom
	name = "психокинетический сгусток"
	damage = 15
	paralyze = 0.5 SECONDS

// ===== Plasma soul =====

/// Seeps plasma into the blood of those around it and scorches machines; a touch vents plasma.
/obj/effect/anomaly/pulsing/plasmasoul
	name = "плазмогенная аномалия"
	desc = "Плазменная лужа. Вокруг неё растут мелкие кристаллы, прорастая в землю."
	icon_state = "plasmasoul"
	density = TRUE
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/plasmasoul
	pulse_delay = 6 SECONDS
	light_color = LIGHT_COLOR_PURPLE
	particles_type = /particles/smoke/steam
	particles_color = "#c070ff"
	COOLDOWN_DECLARE(vent_cooldown)

/obj/effect/anomaly/pulsing/plasmasoul/pulse()
	for(var/mob/living/carbon/human/victim in range(effect_range, src))
		if(!(victim.mob_biotypes & MOB_ORGANIC))
			victim.apply_damage(20, BURN)
			to_chat(victim, span_warning("Под обшивкой что-то шипит и пузырится..."))
			playsound(victim, 'sound/items/tools/welder.ogg', 100)
			continue
		victim.reagents?.add_reagent(/datum/reagent/toxin/plasma, 5)
		to_chat(victim, span_warning("Кровь густеет..."))
		playsound(victim, 'sound/effects/bubbles/bubbles.ogg', 50)

/obj/effect/anomaly/pulsing/plasmasoul/touched(atom/movable/bumper)
	if(!COOLDOWN_FINISHED(src, vent_cooldown))
		return
	COOLDOWN_START(src, vent_cooldown, 10 SECONDS)
	pulse()
	var/turf/open/spot = random_spot(effect_range)
	if(istype(spot))
		// Shiptest vented 300 moles a touch, enough to flood a room; a small puff warns without drowning anyone.
		spot.atmos_spawn_air("[GAS_PLASMA]=20;[TURF_TEMPERATURE(200)]")

// ===== Pulsar =====

/// Throws an EMP somewhere close every so often, and at whoever touches it.
/obj/effect/anomaly/pulsing/pulsar
	name = "электромагнитная импульсная аномалия"
	desc = "Почти прозрачная парящая оболочка, внутри которой не стихает электромагнитная буря."
	icon_state = "pulsar"
	density = TRUE
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/pulsar
	effect_range = 4
	pulse_delay = 15 SECONDS
	light_color = LIGHT_COLOR_BLUE
	particles_type = /particles/grav_field_up
	particles_color = LIGHT_COLOR_BLUE

/obj/effect/anomaly/pulsing/pulsar/pulse()
	var/turf/spot = random_spot(effect_range / 2)
	if(spot)
		empulse(spot, effect_range / 2, effect_range)

/obj/effect/anomaly/pulsing/pulsar/touched(atom/movable/bumper)
	empulse(loc, effect_range / 2, effect_range)

// ===== Sparkler =====

/// Sprays sparks around; a touch shocks and throws lightning.
/obj/effect/anomaly/pulsing/sparkler
	name = "электродуговая аномалия"
	desc = "Рой мерцающих искр, мечущихся туда-сюда. Они пытаются разлететься, но не могут."
	icon_state = "tesla"
	density = TRUE
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/sparkler
	effect_range = 4
	pulse_delay = 1 SECONDS
	light_color = "#fff27a"
	particles_type = /particles/embers
	particles_color = "#fff27a"
	COOLDOWN_DECLARE(zap_cooldown)

/obj/effect/anomaly/pulsing/sparkler/pulse()
	var/turf/spot = random_spot(effect_range)
	if(!spot)
		return
	do_sparks(3, TRUE, spot)
	if(!prob(30))
		return
	Beam(spot, icon_state = "electra_long", icon = 'modular_bandastation/anomaly_fields/icons/fields.dmi', time = 0.3 SECONDS)
	playsound(spot, 'modular_bandastation/anomaly_fields/sound/electra_blast.ogg', 50, FALSE)
	for(var/mob/living/victim in spot)
		victim.electrocute_act(15, src, flags = SHOCK_NOGLOVES)

/obj/effect/anomaly/pulsing/sparkler/touched(atom/movable/bumper)
	if(isliving(bumper))
		var/mob/living/victim = bumper
		victim.electrocute_act(20, src, flags = SHOCK_NOGLOVES)
	if(!COOLDOWN_FINISHED(src, zap_cooldown))
		return
	COOLDOWN_START(src, zap_cooldown, 5 SECONDS)
	tesla_zap(src, 2, 5000, zap_flags = ZAP_FUSION_FLAGS)

// ===== Static =====

/// Lines the static mutters while it holds someone.
GLOBAL_LIST_INIT(tvstatic_sayings, list(
	"...помогите...",
	"...мне надо выбраться...",
	"...нет надежды...",
	"...отпустите...",
	"...побудь со мной...",
	"...только не так...",
	"...пожалуйста, не уходи...",
	"...не забывай меня...",
	"...ты здесь?..",
	"...больно...",
	"...глаза...",
	"...надо бежать...",
	"...здесь кто-нибудь есть?..",
))

/**
 * Burns into the minds of everyone around it. Someone whose mind it has burnt through may be taken:
 * they die and a new static grows over them, holding the body until it is neutralized. Mindshields,
 * resonance binding implants, deafness and research scanners keep it out.
 */
/obj/effect/anomaly/pulsing/tvstatic
	name = "нейроинтерферентная аномалия"
	desc = "Дыра в мире, из которой не смолкает гул. Она что-то прячет."
	icon_state = "static"
	density = TRUE
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/tvstatic
	effect_range = 4
	pulse_delay = 4 SECONDS
	light_color = "#c8c8c8"
	particles_type = /particles/echo
	particles_color = "#c8c8c8"
	verb_say = "умоляет"
	verb_ask = "просит"
	verb_exclaim = "кричит"
	verb_whisper = "хнычет"
	verb_yell = "кричит"
	speech_span = SPAN_ITALICS
	/// The body it holds.
	var/mob/living/carbon/stored_mob

/obj/effect/anomaly/pulsing/tvstatic/Destroy()
	release_body()
	return ..()

/obj/effect/anomaly/pulsing/tvstatic/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == stored_mob)
		stored_mob = null

/// Takes `victim`'s body in.
/obj/effect/anomaly/pulsing/tvstatic/proc/hold_body(mob/living/carbon/victim)
	stored_mob = victim
	victim.forceMove(src)

/// Lets the held body fall out, if any. It must never vanish with the static.
/obj/effect/anomaly/pulsing/tvstatic/proc/release_body()
	stored_mob?.forceMove(drop_location())

/obj/effect/anomaly/pulsing/tvstatic/examine(mob/user)
	. = ..()
	if(!iscarbon(user) || HAS_TRAIT(user, TRAIT_RESEARCH_SCANNER) || is_resonance_bound(user) || resonance_passive_of(user) == ARTIFACT_ENERGY_PSIONIC)
		return
	var/mob/living/carbon/viewer = user
	to_chat(viewer, span_userdanger("Голова раскалывается, пока вы смотрите на [src]!"))
	viewer.flash_act(intensity = 3, visual = TRUE, type = /atom/movable/screen/fullscreen/flash/static)
	SEND_SOUND(viewer, 'sound/items/radiostatic.ogg')
	viewer.adjust_organ_loss(ORGAN_SLOT_BRAIN, 5, 100)

/obj/effect/anomaly/pulsing/tvstatic/anomalyEffect(seconds_per_tick)
	. = ..()
	var/turf/spot = random_spot(effect_range)
	if(spot)
		new /obj/effect/temp_visual/static_blob(spot)

/obj/effect/anomaly/pulsing/tvstatic/pulse()
	for(var/mob/living/carbon/human/looking in range(effect_range, src))
		playsound(src, 'sound/items/radiostatic.ogg', 50)
		if(stored_mob && looking.stat != DEAD && prob(25))
			say(pick(GLOB.tvstatic_sayings))
		if(looking.stat == DEAD || HAS_TRAIT(looking, TRAIT_MINDSHIELD) || HAS_TRAIT(looking, TRAIT_RESEARCH_SCANNER) || HAS_TRAIT(looking, TRAIT_DEAF) || is_resonance_bound(looking))
			continue
		looking.adjust_organ_loss(ORGAN_SLOT_BRAIN, 10, 200)
		if(resonance_passive_of(looking) != ARTIFACT_ENERGY_PSIONIC)
			looking.flash_act(intensity = 2, visual = TRUE, type = /atom/movable/screen/fullscreen/flash/static)
		if(looking.get_organ_loss(ORGAN_SLOT_BRAIN) >= 150 && prob(20))
			var/obj/effect/anomaly/pulsing/tvstatic/expansion = new(get_turf(looking))
			settle_planetary_anomaly(expansion)
			visible_message(span_warning("[src] поглощает [looking], и на его месте возникает [expansion]!"))
			looking.death()
			expansion.hold_body(looking)

/obj/effect/anomaly/pulsing/tvstatic/touched(atom/movable/bumper)
	new /obj/effect/temp_visual/static_blob(get_turf(bumper))

/obj/effect/anomaly/pulsing/tvstatic/anomalyNeutralize()
	if(stored_mob)
		visible_message(span_warning("[src] выплёвывает [stored_mob]!"))
	release_body()
	return ..()

/// A clot of static that flickers and hisses for a moment.
/obj/effect/temp_visual/static_blob
	name = "интерферентный сгусток"
	icon = 'modular_bandastation/planetary_anomalies/icons/anomalies.dmi'
	icon_state = "static"
	duration = 2 SECONDS

/obj/effect/temp_visual/static_blob/Initialize(mapload)
	. = ..()
	playsound(src, 'sound/items/radiostatic.ogg', 30, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)

// ===== Transfusion =====

/// Draws blood from those with plenty and gives it to those running short; a touch drains a lot.
/obj/effect/anomaly/pulsing/transfusion
	name = "гемофагическая аномалия"
	desc = "Пульсирующее поле в воздухе, внутри парит багровая взвесь."
	icon_state = "transfusion"
	density = TRUE
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/transfusion
	light_color = LIGHT_COLOR_BLOOD_MAGIC
	particles_type = /particles/droplets
	particles_color = LIGHT_COLOR_BLOOD_MAGIC
	/// Blood it holds.
	var/blood_stored = 0
	/// Blood it can hold before it throws it up.
	var/blood_max

/obj/effect/anomaly/pulsing/transfusion/Initialize(mapload, new_lifespan, drops_core)
	. = ..()
	blood_max = rand(400, 1200)

/obj/effect/anomaly/pulsing/transfusion/pulse()
	for(var/mob/living/carbon/victim in range(effect_range, src))
		if(blood_stored > blood_max)
			new /obj/effect/temp_visual/dir_setting/bloodsplatter(loc, rand(1, 8))
			visible_message(span_boldwarning("[src] извергает кровь, словно насытившись!"))
			blood_stored = blood_max
			return
		if(victim.blood_volume > BLOOD_VOLUME_SAFE)
			var/drawn = rand(10, 30)
			victim.bleed(drawn)
			victim.spray_blood(get_dir(victim, src), splatter_strength = 1)
			visible_message(span_boldwarning("Из [victim] в [src] течёт кровь!"))
			blood_stored += drawn
			return
		if(victim.blood_volume < BLOOD_VOLUME_SAFE && blood_stored > blood_max / 2)
			var/given = rand(blood_stored / 10, blood_stored / 2)
			visible_message(span_boldwarning("Сгустки крови летят из [src] в [victim]!"))
			blood_stored -= given
			victim.adjust_blood_volume(given)
			return

/obj/effect/anomaly/pulsing/transfusion/touched(atom/movable/bumper)
	if(!iscarbon(bumper))
		return
	var/mob/living/carbon/victim = bumper
	visible_message(span_boldwarning("[victim] касается [src], и кровь утекает из него!"))
	var/drawn = rand(50, 200)
	victim.bleed(drawn)
	blood_stored += drawn

// ===== Veins =====

/// Pulls blood out of the poorly armoured around it; a touch sprays gore.
/obj/effect/anomaly/pulsing/veins
	name = "гемогенная аномалия"
	desc = "Пульсирующие лиловые вены, обнажённая артерия мира. Она сочится в мир вокруг."
	icon_state = "veins"
	density = TRUE
	anomaly_core = /obj/item/assembly/signaler/anomaly/planetary/veins
	pulse_delay = 4 SECONDS
	light_color = "#a020f0"
	particles_type = /particles/droplets
	particles_color = "#8b0000"

/obj/effect/anomaly/pulsing/veins/pulse()
	for(var/mob/living/carbon/victim in range(effect_range, src))
		if(victim.run_armor_check(attack_flag = MELEE, silent = TRUE) > 40)
			continue
		victim.bleed(20)
		victim.apply_damage(5, BRUTE)
		visible_message(span_warning("Кровь срывается с [victim] и летит к [src]!"))

/obj/effect/anomaly/pulsing/veins/touched(atom/movable/bumper)
	pulse()
	var/turf/spot = random_spot(effect_range / 2)
	if(!spot)
		return
	var/gibs = pick(/obj/effect/gibspawner/human, /obj/effect/gibspawner/xeno, /obj/effect/gibspawner/generic/animal)
	new gibs(spot)

#undef ANOMALY_LEASH
