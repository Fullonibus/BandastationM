/// Restore a viable naturally reproduced population and deliver its material.
/datum/station_goal/phoenix
	name = "Проект «Феникс»"
	/// Separates this goal's population and material from unrelated specimens.
	var/project_id
	/// Owned archived genotype; each animal receives an independent copy.
	var/datum/phoenix_strain/founding_strain
	/// Weak references avoid retaining dead or deleted animals.
	var/list/population = list()
	/// Material actually consumed by the acceptance station.
	var/fiber_delivered = 0
	/// Cargo claims the archive once; repeated orders cannot create another founder.
	var/founder_delivered = FALSE

/datum/station_goal/phoenix/New()
	. = ..()
	project_id = REF(src)
	founding_strain = new()

/datum/station_goal/phoenix/Destroy(force)
	QDEL_NULL(founding_strain)
	population.Cut()
	return ..()

/datum/station_goal/phoenix/get_report()
	return list(
		"#### Проект «Феникс»",
		"В архивном биобанке сохранился живой образец утраченного вида — янтарного ткача. Нанотрейзен поручает восстановить его промышленное разведение.",
		"Капсула и исследовательское оборудование доступны для заказа через снабжение. Первый комплект содержит единственный архивный образец; последующие — запасное оборудование. До подготовки вольера сохраняйте образец в стазисе.",
		"Определите требования к атмосфере, температуре, освещению, субстрату и питанию. Медицинский анализатор позволяет наблюдать реакцию особей.",
		"Исследовательская станция ограниченно адаптирует яйца. Изменения наследуются; взрослые особи сохраняют свою линию.",
		"Для приёмки нужны [PHOENIX_DESCENDANT_TARGET] здоровых взрослых потомка в условиях размножения и [PHOENIX_FIBER_TARGET] единиц биоволокна. Сдавайте волокно в архивную капсулу.",
	).Join("\n\n")

/datum/station_goal/phoenix/on_report()
	var/datum/supply_pack/pack = SSshuttle.supply_packs[/datum/supply_pack/science/phoenix_equipment]
	if(pack)
		pack.order_flags |= ORDER_SPECIAL_ENABLED

/** Register a real matching specimen without retaining it past deletion. */
/datum/station_goal/phoenix/proc/register_specimen(mob/living/basic/phoenix_weaver/specimen)
	if(QDELETED(specimen) || specimen.project_id != project_id)
		return
	population |= WEAKREF(specimen)

/** Consume a nearby matching stack once, preserving unrelated/excess material. */
/datum/station_goal/phoenix/proc/accept_fiber(obj/item/stack/phoenix_fiber/fiber, mob/living/user)
	if(QDELETED(fiber) || QDELETED(user) || user.incapacitated || !user.Adjacent(fiber))
		return 0
	if(fiber.project_id != project_id || fiber.is_cyborg || (fiber.item_flags & ABSTRACT) || (fiber.flags_1 & HOLOGRAM_1))
		return 0
	var/accepted = min(fiber.amount, PHOENIX_FIBER_TARGET - fiber_delivered)
	if(accepted <= 0 || !fiber.use(accepted))
		return 0
	fiber_delivered += accepted
	check_completion()
	return accepted

/datum/station_goal/phoenix/check_completion()
	if(..())
		return TRUE
	if(fiber_delivered < PHOENIX_FIBER_TARGET)
		return FALSE
	var/healthy_descendants = 0
	for(var/datum/weakref/reference as anything in population.Copy())
		var/mob/living/basic/phoenix_weaver/specimen = reference.resolve()
		if(!specimen)
			population -= reference
			continue
		if(specimen.project_id != project_id || specimen.generation < 1 || specimen.life_stage != PHOENIX_ADULT)
			continue
		if(specimen.stat == DEAD || HAS_TRAIT(specimen, TRAIT_STASIS) || specimen.health < specimen.maxHealth * 0.8 || specimen.nutrition < 20)
			continue
		specimen.assess_environment()
		if(specimen.last_environment["state"] != PHOENIX_BREEDING)
			continue
		healthy_descendants++
	if(healthy_descendants < PHOENIX_DESCENDANT_TARGET)
		return FALSE
	set_completed(TRUE)
	return TRUE

/// Cargo delivers one archived founder, followed by replacement equipment without new adaptation budgets.
/datum/supply_pack/science/phoenix_equipment
	name = "Оборудование проекта «Феникс»"
	desc = "Стазисная капсула, станция адаптации, субстрат и анализатор. Первый заказ доставляет единственный архивный образец; в последующих капсула пуста."
	cost = CARGO_CRATE_VALUE * 5
	order_flags = ORDER_SPECIAL
	contains = list(
		/obj/machinery/phoenix_capsule,
		/obj/machinery/phoenix_research,
		/obj/item/stack/phoenix_bedding = 50,
		/obj/item/stack/phoenix_bedding/grass = 50,
		/obj/item/stack/phoenix_bedding/snow = 50,
		/obj/item/healthanalyzer/advanced,
		/obj/item/food/grown/soybeans,
	)
	crate_name = "ящик оборудования проекта «Феникс»"

/datum/supply_pack/science/phoenix_equipment/generate(atom/location, datum/bank_account/paying_account, crate_override)
	. = ..()
	var/obj/container = .
	if(QDELETED(container) || (order_flags & ORDER_ADMIN_SPAWNED) || !(order_flags & ORDER_SPECIAL_ENABLED))
		return
	var/datum/station_goal/phoenix/goal = SSstation.get_station_goal(/datum/station_goal/phoenix)
	if(!goal || goal.founder_delivered)
		return
	var/obj/machinery/phoenix_capsule/capsule = locate() in container
	if(!capsule || !capsule.load_archive(goal.founding_strain, goal.project_id))
		return
	// The manifest is generated afterwards and must not randomly discard the unique archive.
	ADD_TRAIT(container, TRAIT_NO_MISSING_ITEM_ERROR, INNATE_TRAIT)
	goal.founder_delivered = TRUE
