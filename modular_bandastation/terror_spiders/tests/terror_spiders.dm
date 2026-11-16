/datum/unit_test/terror_spider_castes

/datum/unit_test/terror_spider_castes/Run()
	var/mob/living/basic/spider/giant/regular = allocate(/mob/living/basic/spider/giant/guard)
	var/mob/living/basic/spider/giant/terror/red/broodmate = allocate(/mob/living/basic/spider/giant/terror/red)
	var/list/castes = subtypesof(/mob/living/basic/spider/giant/terror)
	var/list/action_states = icon_states('modular_bandastation/terror_spiders/icons/actions.dmi')
	TEST_ASSERT_EQUAL(length(castes), 14, "The Terror Spider roster must contain fourteen castes.")
	for(var/caste in castes)
		var/mob/living/basic/spider/giant/terror/spider = allocate(caste)
		var/list/states = icon_states(spider.icon)
		TEST_ASSERT(spider.icon_living in states, "[caste] has no living icon.")
		TEST_ASSERT(spider.icon_dead in states, "[caste] has no death icon.")
		TEST_ASSERT(spider.faction_check_atom(broodmate), "[caste] is not allied to terror spiders.")
		TEST_ASSERT(!spider.faction_check_atom(regular), "[caste] was allied to ordinary spiders.")
		for(var/datum/action/ability as anything in spider.actions)
			if(ability.button_icon == 'modular_bandastation/terror_spiders/icons/actions.dmi')
				TEST_ASSERT(ability.button_icon_state in action_states, "[ability.type] has no HUD icon.")
				TEST_ASSERT(ability.background_icon_state in action_states, "[ability.type] has no HUD background.")

	var/mob/living/basic/spider/giant/terror/brown/brown = allocate(/mob/living/basic/spider/giant/terror/brown)
	TEST_ASSERT(!HAS_TRAIT(brown, TRAIT_WEB_WEAVER), "The breacher should not spin webs.")
	TEST_ASSERT(HAS_TRAIT(brown, TRAIT_VENTCRAWLER_ALWAYS), "The breacher cannot enter an open vent.")
	var/mob/living/basic/spider/giant/terror/prince/prince = allocate(/mob/living/basic/spider/giant/terror/prince)
	TEST_ASSERT(!HAS_TRAIT(prince, TRAIT_VENTCRAWLER_ALWAYS), "The prince can enter a vent.")
	TEST_ASSERT(locate(/datum/action/cooldown/mob_cooldown/terror_prince_slam) in prince.actions, "The Prince should have his area slam.")
	TEST_ASSERT(!HAS_TRAIT(prince, TRAIT_WEB_WEAVER), "The Prince should not spin webs.")

	var/datum/action/cooldown/mob_cooldown/terror_knight_mode/attack/attack = locate() in broodmate.actions
	var/datum/action/cooldown/mob_cooldown/terror_knight_mode/defense/defense = locate() in broodmate.actions
	TEST_ASSERT_NOTNULL(attack, "The Knight needs an attack stance.")
	TEST_ASSERT_NOTNULL(defense, "The Knight needs a defense stance.")
	TEST_ASSERT(attack.Activate(), "The Knight failed to enter attack stance.")
	TEST_ASSERT_EQUAL(broodmate.melee_damage_lower, 30, "Attack stance did not strengthen the bite.")
	TEST_ASSERT(broodmate.speed < initial(broodmate.speed), "Attack stance did not speed up the Knight.")
	TEST_ASSERT(defense.Activate(), "The Knight failed to switch to defense stance.")
	TEST_ASSERT_EQUAL(broodmate.terror_damage_coefficients[BRUTE], 0.4, "Defense stance did not reduce incoming brute damage.")
	TEST_ASSERT_EQUAL(broodmate.melee_damage_upper, 10, "Defense stance did not weaken the bite.")
	broodmate.reset_terror_stance()
	TEST_ASSERT_EQUAL(broodmate.melee_damage_upper, 15, "The Knight did not return to his normal bite when the stance ended.")
	TEST_ASSERT_EQUAL(broodmate.speed, initial(broodmate.speed), "The Knight did not return to normal speed.")
	var/damage_after_stance = broodmate.apply_damage(100, BRUTE)
	TEST_ASSERT(abs(damage_after_stance - 60) < 0.01, "A hit after the Knight's stance ends must deal 60 brute damage, got [damage_after_stance].")

	var/mob/living/basic/spider/giant/terror/gray/gray = allocate(/mob/living/basic/spider/giant/terror/gray)
	var/obj/structure/spider/stickyweb/terror/transparent/web = allocate(/obj/structure/spider/stickyweb/terror/transparent)
	TEST_ASSERT_EQUAL(gray.icon_state, "terror_gray_cloaked", "A newly spun web did not hide the gray spider.")
	TEST_ASSERT(gray.icon_state in icon_states(gray.icon), "The gray spider has no cloak sprite.")
	var/mob/living/carbon/human/webbed_prey = allocate(/mob/living/carbon/human)
	gray.melee_damage_upper = gray.melee_damage_lower
	gray.melee_attack(webbed_prey, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(webbed_prey.get_brute_loss(), gray.melee_damage_lower * 3, "The Lurker's bite did not triple while standing on a web.")
	qdel(web)
	TEST_ASSERT_EQUAL(gray.icon_state, initial(gray.icon_living), "A removed web still concealed the gray spider.")

	var/mob/living/basic/spider/giant/terror/black/black = allocate(/mob/living/basic/spider/giant/terror/black)
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human)
	black.melee_attack(prey, ignore_cooldown = TRUE)
	black.melee_attack(prey, ignore_cooldown = TRUE)
	TEST_ASSERT_EQUAL(prey.reagents.get_reagent_amount(/datum/reagent/toxin/terror_black_venom), 40, "Two exposed bites did not stack Widow venom.")
	TEST_ASSERT(locate(/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/venom) in black.actions, "The Widow is missing her venom spit.")
	TEST_ASSERT(locate(/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/smoke) in black.actions, "The Widow is missing her smoke spit.")

	var/mob/living/basic/spider/giant/terror/reaper/reaper = allocate(/mob/living/basic/spider/giant/terror/reaper)
	var/blood_before_bite = prey.blood_volume
	reaper.adjust_brute_loss(20, forced = TRUE)
	TEST_ASSERT(reaper.melee_attack(prey, ignore_cooldown = TRUE), "The Reaper failed to bite a living victim.")
	TEST_ASSERT_EQUAL(reaper.get_brute_loss(), 5, "The Reaper's bite did not heal the expected damage.")
	TEST_ASSERT_EQUAL(prey.blood_volume, blood_before_bite - 25, "The Reaper's bite did not draw blood.")
	reaper.Life(2)
	TEST_ASSERT_EQUAL(reaper.get_brute_loss(), 6, "The Reaper did not lose health without feeding.")

	var/mob/living/basic/spider/giant/terror/queen/queen = allocate(/mob/living/basic/spider/giant/terror/queen)
	var/mob/living/basic/spider/giant/terror/purple/purple = allocate(/mob/living/basic/spider/giant/terror/purple)
	purple.terror_queen_ref = WEAKREF(queen)
	purple.queen_separation = 2 MINUTES
	purple.Life(1)
	TEST_ASSERT_EQUAL(purple.queen_separation, 0, "Returning to the queen did not restore the purple spider's bond.")
	queen.moveToNullspace()
	purple.queen_separation = 3 MINUTES - 2 SECONDS
	purple.Life(1)
	TEST_ASSERT_EQUAL(purple.melee_damage_upper, 25, "The Guardian weakened before three minutes apart.")
	purple.Life(1)
	TEST_ASSERT_EQUAL(purple.melee_damage_upper, 10, "The Guardian did not weaken after three minutes apart.")
	TEST_ASSERT(purple.terror_degenerating, "The Guardian did not start degenerating after losing its bond.")
	var/datum/action/cooldown/mob_cooldown/terror_guardian_membrane/membrane = locate() in purple.actions
	TEST_ASSERT_NOTNULL(membrane, "The Guardian needs a membrane ability.")
	TEST_ASSERT(membrane.Activate(), "The Guardian failed to create a membrane.")
	var/obj/effect/forcefield/terror_membrane/barrier = locate() in get_turf(purple)
	TEST_ASSERT_NOTNULL(barrier, "The Guardian's membrane was not created.")
	TEST_ASSERT(barrier.CanAllowThrough(reaper, NORTH), "The membrane blocked a Terror Spider.")
	TEST_ASSERT(!barrier.CanAllowThrough(prey, NORTH), "The membrane admitted a human.")

/datum/unit_test/terror_spider_brood
	normal_floor_required = TRUE

/datum/unit_test/terror_spider_brood/Run()
	var/mob/living/basic/spider/giant/terror/green/green = allocate(/mob/living/basic/spider/giant/terror/green)
	var/datum/action/cooldown/mob_cooldown/lay_eggs/terror/lay = locate() in green.actions
	var/datum/action/cooldown/mob_cooldown/wrap/terror/wrap = locate() in green.actions
	TEST_ASSERT_NOTNULL(lay, "A green spider should be able to lay eggs.")
	TEST_ASSERT_NOTNULL(wrap, "A green spider should be able to wrap corpses.")

	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human)
	TEST_ASSERT(!wrap.Activate(prey), "A living victim must never be wrapped.")
	wrap.wrap_target(prey)
	TEST_ASSERT_EQUAL(green.fed, 0, "A living victim must not grant a meal after the wrap delay.")
	prey.death()
	wrap.wrap_target(prey)
	TEST_ASSERT_EQUAL(green.fed, 1, "Wrapping a corpse must grant one meal.")
	prey.forceMove(run_loc_floor_bottom_left)
	wrap.wrap_target(prey)
	TEST_ASSERT_EQUAL(green.fed, 1, "The same corpse must not grant a second meal.")
	var/mob/living/carbon/human/other_prey = allocate(/mob/living/carbon/human)
	other_prey.death()
	wrap.wrap_target(other_prey)
	TEST_ASSERT(!lay.IsAvailable(), "Two meals should not suffice for a clutch.")
	var/mob/living/carbon/human/third_prey = allocate(/mob/living/carbon/human)
	third_prey.death()
	wrap.wrap_target(third_prey)
	TEST_ASSERT_EQUAL(green.fed, 3, "The Healer must count three distinct meals.")
	TEST_ASSERT(lay.IsAvailable(), "Three distinct corpses should unlock a clutch.")

	var/datum/dynamic_ruleset/midround/spiders/ruleset = allocate(/datum/dynamic_ruleset/midround/spiders)
	var/list/low_population = ruleset.get_founders(31)
	var/list/mid_population = ruleset.get_founders(40)
	var/list/high_population = ruleset.get_founders(50)
	TEST_ASSERT_EQUAL(ruleset.min_pop, 31, "The spider event must start above 30 players.")
	TEST_ASSERT_EQUAL(low_population[/mob/living/basic/spider/giant/terror/white], 2, "Low population should get two Defilers or Princesses.")
	TEST_ASSERT_EQUAL(mid_population[/mob/living/basic/spider/giant/terror/queen/princess], 3, "Mid population should get three Defilers or Princesses.")
	TEST_ASSERT_EQUAL(high_population[/mob/living/basic/spider/giant/terror/queen], 1, "High population should get one Queen or Prince.")
	TEST_ASSERT_EQUAL(high_population[/mob/living/basic/spider/giant/terror/prince], 1, "High population should get one Queen or Prince.")

	var/obj/effect/mob_spawn/ghost_role/spider/terror/clutch = allocate(
		/obj/effect/mob_spawn/ghost_role/spider/terror,
		run_loc_floor_bottom_left,
		/mob/living/basic/spider/giant/terror/green,
		"Guard the nest.",
	)
	TEST_ASSERT_EQUAL(clutch.uses, 1, "A clutch should produce only one spider.")
	TEST_ASSERT_EQUAL(clutch.mob_type, green.type, "The clutch was not configured with the chosen caste.")
	TEST_ASSERT(!clutch.allow_spawn(null, silent = TRUE), "Immature eggs can be claimed.")
	clutch.process(100)
	TEST_ASSERT(clutch.allow_spawn(null, silent = TRUE), "Mature eggs cannot be claimed.")
	var/obj/structure/spider/eggcluster/physical_clutch = clutch.egg
	green.mind_initialize()
	var/datum/antagonist/spider/terror/panel_role = allocate(/datum/antagonist/spider/terror)
	TEST_ASSERT(panel_role.show_in_antagpanel && panel_role.can_be_owned(green.mind), "Traitor Panel should offer the terror spider role.")
	clutch.special(green)
	TEST_ASSERT_EQUAL(green.directive, "Guard the nest.", "The hatched spider did not inherit its directive.")
	var/datum/antagonist/spider/terror/hatched_role = green.mind.has_antag_datum(/datum/antagonist/spider/terror)
	TEST_ASSERT_NOTNULL(hatched_role, "The spawner did not assign the distinct terror spider role.")
	TEST_ASSERT_EQUAL(hatched_role.directive, green.directive, "The antagonist role did not inherit the brood directive.")
	TEST_ASSERT(!panel_role.can_be_owned(green.mind), "Traitor Panel should reject a duplicate terror spider role.")
	TEST_ASSERT(QDELETED(physical_clutch), "Hatched eggs must disappear.")
	TEST_ASSERT(!QDELETED(clutch), "Hatching deleted the spawner before it could send COMSIG_GHOSTROLE_SPAWNED.")

	var/mob/living/basic/spider/giant/terror/queen/princess/princess = allocate(/mob/living/basic/spider/giant/terror/queen/princess)
	var/datum/weakref/princess_ref = WEAKREF(princess)
	var/obj/structure/spider/eggcluster/terror/brood/royal_clutch = allocate(
		/obj/structure/spider/eggcluster/terror/brood,
		run_loc_floor_bottom_left,
		/mob/living/basic/spider/giant/terror/purple,
		"Guard the princess.",
		princess_ref,
		2,
	)
	var/list/brood_counts = count_terror_brood(princess_ref)
	TEST_ASSERT_EQUAL(brood_counts["total"], 2, "Unhatched eggs did not count toward the royal brood cap.")
	royal_clutch.amount_grown = 100
	royal_clutch.process(2)
	TEST_ASSERT(QDELETED(royal_clutch), "A hatched royal clutch did not disappear.")
	brood_counts = count_terror_brood(princess_ref)
	TEST_ASSERT_EQUAL(brood_counts["total"], 2, "A two-egg royal clutch did not produce two linked spiderlings.")
	var/mob/living/basic/spider/growing/spiderling/terror/royal_spiderling = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(royal_spiderling, "The royal clutch did not produce a spiderling.")
	TEST_ASSERT_EQUAL(royal_spiderling.grow_as, /mob/living/basic/spider/giant/terror/purple, "The royal clutch spawned the wrong caste.")
	TEST_ASSERT_EQUAL(royal_spiderling.directive, "Guard the princess.", "The royal spiderling did not inherit its directive.")

/datum/unit_test/terror_spider_wall_breaching
	/// Restore the shared floor even if an assertion aborts the breach.
	var/turf/test_wall

/datum/unit_test/terror_spider_wall_breaching/Destroy()
	test_wall?.ChangeTurf(/turf/open/indestructible)
	test_wall = null
	return ..()

/datum/unit_test/terror_spider_wall_breaching/Run()
	test_wall = run_loc_floor_bottom_left.ChangeTurf(/turf/closed/wall)
	var/turf/spider_turf = get_step(test_wall, EAST)
	var/mob/living/basic/spider/giant/terror/red/knight = allocate(__IMPLIED_TYPE__, spider_turf)
	knight.ai_controller.force_ai_off()
	var/started_at = world.time
	knight.UnarmedAttack(test_wall, proximity_flag = TRUE)
	TEST_ASSERT(test_wall.density, "A Knight broke the wall immediately.")
	TEST_ASSERT_NULL(test_wall.GetComponent(/datum/component/torn_wall), "A Knight damaged the wall without waiting for a strike.")
	UNTIL(test_wall.GetComponent(/datum/component/torn_wall) || world.time >= started_at + 10 SECONDS)
	var/datum/component/torn_wall/cracks = test_wall.GetComponent(/datum/component/torn_wall)
	TEST_ASSERT_NOTNULL(cracks, "A Knight did not crack the wall after the first strike.")
	TEST_ASSERT_EQUAL(cracks.current_stage, 0, "A Knight skipped the first damage stage.")
	TEST_ASSERT(world.time >= started_at + 2 SECONDS, "The first strike took less than two seconds.")
	UNTIL(!test_wall.density || world.time >= started_at + 10 SECONDS)
	TEST_ASSERT(!test_wall.density, "A Knight did not complete the three-strike breach.")
	TEST_ASSERT(world.time >= started_at + 6 SECONDS, "A full breach took less than six seconds.")

	test_wall = test_wall.ChangeTurf(/turf/closed/wall/r_wall)
	knight.UnarmedAttack(test_wall, proximity_flag = TRUE)
	TEST_ASSERT(!DOING_INTERACTION(knight, /datum/element/wall_tearer), "A Knight started breaching a reinforced wall.")
	knight.moveToNullspace()
	var/mob/living/basic/spider/giant/terror/brown/destroyer = allocate(__IMPLIED_TYPE__, spider_turf)
	destroyer.ai_controller.force_ai_off()
	started_at = world.time
	destroyer.melee_attack(test_wall)
	TEST_ASSERT(test_wall.density, "A Destroyer broke the reinforced wall immediately.")
	UNTIL(test_wall.GetComponent(/datum/component/torn_wall) || world.time >= started_at + 10 SECONDS)
	cracks = test_wall.GetComponent(/datum/component/torn_wall)
	TEST_ASSERT_NOTNULL(cracks, "A Destroyer did not crack the reinforced wall.")
	TEST_ASSERT(world.time >= started_at + 4 SECONDS, "The first reinforced strike took less than four seconds.")
	destroyer.forceMove(get_step(spider_turf, EAST))
	UNTIL(!DOING_INTERACTION(destroyer, /datum/element/wall_tearer) || world.time >= started_at + 10 SECONDS)
	TEST_ASSERT(!DOING_INTERACTION(destroyer, /datum/element/wall_tearer), "Movement did not interrupt breaching.")
	TEST_ASSERT(test_wall.density && cracks.current_stage == 0, "The interrupted strike advanced the damage stage.")

/datum/unit_test/terror_spider_heat
	/// Captured before propagation to keep the shared test room free of hotspots.
	var/list/ring_explosion

/datum/unit_test/terror_spider_heat/Run()
	var/mob/living/basic/spider/giant/terror/brown/destroyer = allocate(__IMPLIED_TYPE__)
	var/mob/living/basic/spider/growing/spiderling/terror/spiderling = allocate(__IMPLIED_TYPE__)
	destroyer.terror_regeneration = 0
	for(var/mob/living/basic/spider/spider as anything in list(destroyer, spiderling))
		spider.bodytemperature = 500
		spider.Life(1)
		TEST_ASSERT_EQUAL(spider.health, spider.maxHealth, "[spider.type] took damage from ambient heat.")

		spider.set_fire_stacks(10)
		TEST_ASSERT(spider.ignite_mob(silent = TRUE), "[spider.type] could not catch fire.")
		var/datum/status_effect/fire_handler/fire_stacks/fire = spider.has_status_effect(/datum/status_effect/fire_handler/fire_stacks)
		fire.deal_damage(1)
		TEST_ASSERT_EQUAL(spider.health, spider.maxHealth - 4, "[spider.type] did not take direct damage from burning.")
		spider.extinguish_mob()
		TEST_ASSERT(!spider.on_fire, "[spider.type] did not stop burning.")
		spider.bodytemperature = 500
		spider.Life(1)
		TEST_ASSERT_EQUAL(spider.health, spider.maxHealth - 4, "[spider.type] took residual heat damage after extinguishing.")

	var/datum/action/cooldown/mob_cooldown/terror_destroyer_ignite/ignite = locate() in destroyer.actions
	TEST_ASSERT_NOTNULL(ignite, "The Destroyer has no fire ring action.")
	RegisterSignal(destroyer, COMSIG_ATOM_EXPLODE, PROC_REF(capture_fire_ring))
	TEST_ASSERT(ignite.Activate(), "The Destroyer could not cast the fire ring.")
	TEST_ASSERT_NOTNULL(ring_explosion, "The fire ring did not reach the explosion system.")
	TEST_ASSERT(ring_explosion[EXARG_KEY_PROTECT_EPICENTER], "The fire ring did not spare the Destroyer's tile.")
	TEST_ASSERT_EQUAL(ring_explosion[EXARG_KEY_FLAME_RANGE], 5, "Protecting the center changed the fire ring's range.")

/// Capture the action's real explosion arguments without igniting any test fixtures.
/datum/unit_test/terror_spider_heat/proc/capture_fire_ring(datum/source, list/explosion_args)
	SIGNAL_HANDLER
	ring_explosion = explosion_args
	return COMSIG_CANCEL_EXPLOSION

/datum/unit_test/terror_spider_parasite

/datum/unit_test/terror_spider_parasite/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human)
	TEST_ASSERT(host.try_implant_terror_eggs(), "The parasite could not infect an exposed host.")
	TEST_ASSERT(!host.try_implant_terror_eggs(), "A host must only carry one clutch.")
	var/obj/item/organ/terror_eggs/embryo = host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG)
	TEST_ASSERT(istype(embryo), "Infection did not put an egg in the surgical parasite slot.")

	embryo.egg_progress = 120
	embryo.Remove(host)
	embryo.hatch_egg()
	TEST_ASSERT_NULL(locate(/mob/living/basic/spider/growing/spiderling/terror) in run_loc_floor_bottom_left, "A removed egg must not hatch.")
	qdel(embryo)
	TEST_ASSERT(host.try_implant_terror_eggs(), "The host should be infectable again after extraction.")
	embryo = host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG)
	embryo.on_life(2)
	embryo.hatch_egg()
	TEST_ASSERT_EQUAL(embryo.eggs_hatched, 0, "The eggs emerged before maturity.")
	embryo.egg_progress = 120
	embryo.hatch_egg()
	TEST_ASSERT_EQUAL(embryo.eggs_hatched, 1, "The first spiderling did not hatch from mature eggs.")
	TEST_ASSERT_EQUAL(host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG), embryo, "The clutch should remain after its first spiderling hatches.")
	var/mob/living/basic/spider/growing/spiderling/terror/spiderling = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(spiderling, "Mature parasite eggs did not spawn a spiderling.")
	var/static/list/first_caste_pool = list(/mob/living/basic/spider/giant/terror/gray, /mob/living/basic/spider/giant/terror/red, /mob/living/basic/spider/giant/terror/reaper)
	TEST_ASSERT(spiderling.grow_as in first_caste_pool, "The first parasite spiderling came from the wrong caste pool.")

/datum/unit_test/terror_spider_ghost_roles
	normal_floor_required = TRUE
	/// Unlike the unit-test room, a reservation is not on an away level.
	var/datum/turf_reservation/brood_room
	/// A clientless observer lets the poll run without an eligible candidate.
	var/mob/dead/observer/poll_observer

/datum/unit_test/terror_spider_ghost_roles/Destroy()
	GLOB.player_list -= poll_observer
	poll_observer = null
	. = ..()
	QDEL_NULL(brood_room)

/datum/unit_test/terror_spider_ghost_roles/Run()
	var/turf/egg_turf = run_loc_floor_bottom_left
	var/mob/dead/observer/ghost = allocate(__IMPLIED_TYPE__)
	var/datum/spawners_menu/menu = allocate(__IMPLIED_TYPE__, ghost)
	var/datum/tgui/ui = allocate(__IMPLIED_TYPE__, ghost, menu, "SpawnersMenu")
	ui.status = UI_INTERACTIVE

	var/obj/effect/mob_spawn/ghost_role/spider/terror/first = allocate(__IMPLIED_TYPE__, egg_turf)
	var/obj/effect/mob_spawn/ghost_role/spider/terror/second = allocate(__IMPLIED_TYPE__, egg_turf)
	var/group_name = format_text(first.name)
	first.process(20)
	TEST_ASSERT(menu.ui_act("jump", list("name" = group_name), ui, menu.ui_state(ghost)), "A ghost could not jump to the mature clutch.")
	TEST_ASSERT(second in GLOB.mob_spawners[group_name], "Looking up a mature clutch unregistered the immature one.")
	TEST_ASSERT_EQUAL(menu_count(menu, ghost, group_name), 1, "The menu did not list the mature clutch.")
	second.process(20)
	TEST_ASSERT_EQUAL(menu_count(menu, ghost, group_name), 2, "The open menu did not reflect the second clutch becoming ready.")

	var/obj/effect/mob_spawn/ghost_role/spider/terror/empress/royal_egg = allocate(__IMPLIED_TYPE__, egg_turf)
	royal_egg.process(170)
	TEST_ASSERT(!royal_egg.ready, "The Empress egg matured before the crew had three minutes to stop it.")
	royal_egg.process(12)
	TEST_ASSERT(royal_egg.ready, "The Empress egg did not mature after three minutes.")

	brood_room = SSmapping.request_turf_block_reservation(2, 2, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(brood_room, "Could not reserve a non-away turf for the brood.")
	var/turf/brood_turf = brood_room.bottom_left_turfs[1]
	var/obj/structure/spider/eggcluster/terror/brood/clutch = allocate(__IMPLIED_TYPE__, brood_turf, /mob/living/basic/spider/giant/terror/red)
	clutch.process(60)
	TEST_ASSERT(QDELETED(clutch), "A normal Terror clutch took more than one minute to hatch.")
	var/mob/living/basic/spider/growing/spiderling/terror/hatchling = locate() in brood_turf
	TEST_ASSERT_NOTNULL(hatchling, "The clutch did not produce a spiderling.")
	poll_observer = ghost
	GLOB.player_list |= poll_observer
	hatchling.grow_up()
	var/mob/living/basic/spider/giant/terror/red/adult = locate() in brood_turf
	TEST_ASSERT_NOTNULL(adult, "The spiderling did not become an adult.")
	allocated += adult
	var/adult_group = format_text(initial(adult.name))
	TEST_ASSERT_EQUAL(menu_count(menu, ghost, adult_group), 0, "The adult appeared in the spawners menu before the poll finished.")

	var/obj/effect/mob_spawn/ghost_role/spider/terror/polled_egg = allocate(__IMPLIED_TYPE__, brood_turf, /mob/living/basic/spider/giant/terror/gray)
	var/egg_group = format_text(polled_egg.name)
	polled_egg.process(20)
	TEST_ASSERT(!polled_egg.ready, "The mature egg was claimable before the poll finished.")
	TEST_ASSERT_EQUAL(menu_count(menu, ghost, egg_group), 0, "The mature egg appeared in the spawners menu during the poll.")

	var/deadline = world.time + 15 SECONDS
	UNTIL((menu_count(menu, ghost, adult_group) && polled_egg.ready) || world.time >= deadline)
	TEST_ASSERT_EQUAL(menu_count(menu, ghost, adult_group), 1, "The unoccupied adult did not appear in the spawners menu after the poll.")
	TEST_ASSERT_EQUAL(menu_count(menu, ghost, egg_group), 1, "The unclaimed egg did not appear in the spawners menu after the poll.")
	adult.death()
	TEST_ASSERT_EQUAL(menu_count(menu, ghost, adult_group), 0, "A dead adult stayed in the spawners menu.")

/// Read the live menu payload for a particular group without requiring a client.
/datum/unit_test/terror_spider_ghost_roles/proc/menu_count(datum/spawners_menu/menu, mob/dead/observer/ghost, group_name)
	var/list/data = menu.ui_data(ghost)
	for(var/list/group as anything in data?["spawners"])
		if(group["name"] == group_name)
			return group["amount_left"]
	return 0

/datum/unit_test/terror_spider_webs
	normal_floor_required = TRUE

/datum/unit_test/terror_spider_webs/Run()
	var/turf/web_turf = run_loc_floor_bottom_left
	var/turf/neighbor = get_step(web_turf, EAST)
	web_turf.immediate_calculate_adjacent_turfs()
	TEST_ASSERT(neighbor in web_turf.get_atmos_adjacent_turfs(), "The open test tiles must initially exchange gas.")
	TEST_ASSERT(web_turf in neighbor.get_atmos_adjacent_turfs(), "The initial atmos connection must be bidirectional.")

	var/mob/living/basic/spider/giant/terror/builder/drone = allocate(__IMPLIED_TYPE__, web_turf)
	var/normal_delay = drone.cached_multiplicative_slowdown
	var/datum/action/cooldown/mob_cooldown/lay_web/terror/airtight/drone/spin = locate() in drone.actions
	TEST_ASSERT_NOTNULL(spin, "The Drone has no airtight web ability.")
	spin.plant_web(web_turf)
	var/obj/structure/spider/stickyweb/terror/airtight/web = locate() in web_turf
	TEST_ASSERT_NOTNULL(web, "The ability did not create an airtight web.")
	TEST_ASSERT(!(neighbor in web_turf.get_atmos_adjacent_turfs()), "Gas can escape through the webbed tile.")
	TEST_ASSERT(!(web_turf in neighbor.get_atmos_adjacent_turfs()), "Gas can enter the webbed tile.")
	var/datum/movespeed_modifier/drone_boost = drone.has_movespeed_modifier(/datum/movespeed_modifier/terror_web/drone)
	TEST_ASSERT_NOTNULL(drone_boost, "The newly laid web did not apply the Drone's speed modifier.")
	TEST_ASSERT(drone_boost.multiplicative_slowdown < -1.4, "The Drone's web bonus did not improve over its previous value.")
	// The effective delay scales with RUN_DELAY, which the minimal CI config leaves at zero.
	TEST_ASSERT(abs(drone.cached_multiplicative_slowdown - normal_delay - drone_boost.get_rp_speed()) < 0.01, "The Drone's web modifier was not included in its move delay.")

	var/mob/living/basic/spider/giant/terror/red/knight = allocate(__IMPLIED_TYPE__, neighbor)
	var/knight_normal_delay = knight.cached_multiplicative_slowdown
	knight.forceMove(web_turf)
	var/datum/movespeed_modifier/knight_boost = knight.has_movespeed_modifier(/datum/movespeed_modifier/terror_web)
	TEST_ASSERT_NOTNULL(knight_boost, "The Knight did not gain the speed modifier on the web.")
	TEST_ASSERT(knight_boost.multiplicative_slowdown < 0, "The web modifier must speed up the Knight.")
	TEST_ASSERT(abs(knight.cached_multiplicative_slowdown - knight_normal_delay - knight_boost.get_rp_speed()) < 0.01, "The Knight's web modifier was not included in its move delay.")
	knight.forceMove(neighbor)
	TEST_ASSERT(!knight.has_movespeed_modifier(/datum/movespeed_modifier/terror_web), "The Knight kept the web modifier after leaving the web.")
	TEST_ASSERT_EQUAL(knight.cached_multiplicative_slowdown, knight_normal_delay, "The Knight kept the speed bonus after leaving the web.")
	qdel(web)
	TEST_ASSERT(!drone.has_movespeed_modifier(/datum/movespeed_modifier/terror_web/drone), "The Drone kept the web modifier after the web was removed.")
	TEST_ASSERT_EQUAL(drone.cached_multiplicative_slowdown, normal_delay, "The Drone kept the speed bonus after the web was removed.")
	TEST_ASSERT(neighbor in web_turf.get_atmos_adjacent_turfs(), "Gas exchange did not resume after the web was removed.")
	TEST_ASSERT(web_turf in neighbor.get_atmos_adjacent_turfs(), "The reopened atmos connection must be bidirectional.")

/datum/unit_test/terror_spider_shove
	normal_floor_required = TRUE

/datum/unit_test/terror_spider_shove/Run()
	var/turf/spider_turf = get_step(run_loc_floor_bottom_left, EAST)
	var/mob/living/basic/spider/giant/terror/red/knight = allocate(__IMPLIED_TYPE__, spider_turf)
	var/mob/living/carbon/human/shover = allocate(__IMPLIED_TYPE__, get_step(spider_turf, EAST))
	shover.move_force = MOVE_FORCE_OVERPOWERING
	knight.combat_mode = FALSE
	TEST_ASSERT(!(knight.get_shove_flags(shover) & SHOVE_CAN_MOVE), "A strong shover can still move an adult Terror Spider.")
	shover.disarm(knight)
	TEST_ASSERT_EQUAL(knight.loc, spider_turf, "A right-click shove displaced an adult Terror Spider.")
	TEST_ASSERT(!shover.can_mobswap_with(knight), "Bumping into a Terror Spider can still swap positions.")

/datum/unit_test/terror_spider_widow_spit

/datum/unit_test/terror_spider_widow_spit/Run()
	var/mob/living/basic/spider/giant/terror/black/widow = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/prey = allocate(__IMPLIED_TYPE__)
	for(var/spit_type in subtypesof(/obj/projectile/terror_spider/widow))
		var/obj/projectile/terror_spider/widow/spit = allocate(spit_type)
		spit.firer = widow
		spit.ignore_source_check = TRUE // Portals normally let redirected projectiles hit their firer.
		TEST_ASSERT(!spit.can_hit_target(widow, ignore_loc = TRUE), "A redirected Widow spit can hit the Widow that fired it.")
		TEST_ASSERT(spit.can_hit_target(prey, ignore_loc = TRUE), "Widow spit stopped being able to hit crew.")

	var/obj/projectile/terror_spider/widow/venom/venom = allocate(__IMPLIED_TYPE__)
	venom.firer = widow
	venom.on_hit(prey)
	var/obj/effect/particle_effect/fluid/smoke/chem/cloud = locate() in prey.loc
	TEST_ASSERT_NOTNULL(cloud, "The venom projectile did not create its chemical cloud.")
	var/tox_before = widow.get_tox_loss()
	cloud.process(1)
	TEST_ASSERT(prey.reagents.has_reagent(/datum/reagent/toxin/terror_black_venom), "The Widow's cloud did not deliver venom to crew.")
	TEST_ASSERT_EQUAL(widow.get_tox_loss(), tox_before, "The Widow took toxin damage from her own cloud.")
	TEST_ASSERT(!widow.reagents?.has_reagent(/datum/reagent/toxin/terror_black_venom), "The Widow absorbed venom from her own cloud.")
