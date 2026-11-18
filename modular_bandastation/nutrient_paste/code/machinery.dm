#define PASTE_PORTION_COST 8

/// Shared power, timed cycle, and reservoir handling for the two paste machines.
/obj/machinery/nutrient_paste
	abstract_type = /obj/machinery/nutrient_paste
	icon = 'modular_bandastation/nutrient_paste/icons/nutrient_paste.dmi'
	density = TRUE
	/// Maximum volume of concentrate the internal reservoir can hold.
	var/reservoir_capacity
	/// Time between starting a cycle and processing its inputs.
	var/cycle_duration
	/// Concentrate amount at which the ready indicator lights up.
	var/ready_volume = 1
	/// Stoppable timer for the current cycle, if any.
	var/cycle_timer

/obj/machinery/nutrient_paste/Initialize(mapload)
	. = ..()
	create_reagents(reservoir_capacity, NO_REACT)
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/nutrient_paste/Destroy()
	cancel_cycle()
	return ..()

/obj/machinery/nutrient_paste/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		cancel_cycle()
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/nutrient_paste/on_set_panel_open(old_value)
	. = ..()
	if(panel_open)
		cancel_cycle()
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/nutrient_paste/set_anchored(anchorvalue)
	. = ..()
	if(!anchored)
		cancel_cycle()
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/nutrient_paste/screwdriver_act(mob/living/user, obj/item/tool)
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/nutrient_paste/crowbar_act(mob/living/user, obj/item/tool)
	if(panel_open && reagents.total_volume)
		balloon_alert(user, "сначала слейте концентрат")
		return ITEM_INTERACT_BLOCKING
	return default_pry_open(user, tool, close_after_pry = TRUE, deconstruct_on_fail = TRUE)

/obj/machinery/nutrient_paste/wrench_act(mob/living/user, obj/item/tool)
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/nutrient_paste/update_icon_state()
	. = ..()
	if(panel_open)
		icon_state = "[base_icon_state]_open"
	else if(!is_operational || !anchored)
		icon_state = "[base_icon_state]_off"
	else if(cycle_timer)
		icon_state = "[base_icon_state]_working"
	else if(reagents?.total_volume >= ready_volume)
		icon_state = "[base_icon_state]_ready"
	else
		icon_state = base_icon_state

/obj/machinery/nutrient_paste/examine(mob/user)
	. = ..()
	. += span_notice("Концентрат в баке: [round(reagents.total_volume, 0.01)] из [reservoir_capacity] ед.")

/// Checks physical machine state before starting or finishing work.
/obj/machinery/nutrient_paste/proc/can_run_cycle()
	return anchored && is_operational && !panel_open

/// Checks whether the user may load or use an idle, powered machine.
/obj/machinery/nutrient_paste/proc/can_use_controls(mob/user)
	if(!user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return FALSE
	if(!can_run_cycle() || cycle_timer)
		balloon_alert(user, cycle_timer ? "машина занята" : "машина недоступна")
		return FALSE
	return TRUE

/// Starts a cycle only after the caller has verified its inputs.
/obj/machinery/nutrient_paste/proc/start_cycle(mob/user)
	if(!use_energy(active_power_usage, force = FALSE))
		balloon_alert(user, "не хватает энергии")
		return FALSE
	cycle_timer = addtimer(CALLBACK(src, PROC_REF(finish_cycle)), cycle_duration, TIMER_STOPPABLE)
	update_appearance(UPDATE_ICON_STATE)
	return TRUE

/// Draws concentrate through the manual drain without contaminating the receiving container.
/obj/machinery/nutrient_paste/proc/drain_concentrate(mob/living/user, obj/item/reagent_containers/container)
	if(!user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return ITEM_INTERACT_BLOCKING
	if(cycle_timer)
		balloon_alert(user, "машина занята")
		return ITEM_INTERACT_BLOCKING
	var/datum/reagents/receiver = container.reagents
	if(receiver.total_volume != receiver.get_reagent_amount(/datum/reagent/toxin/biomass_concentrate))
		balloon_alert(user, "в ёмкости другая жидкость")
		return ITEM_INTERACT_BLOCKING
	if(!reagents.trans_to(container, reagents.total_volume, transferred_by = user))
		balloon_alert(user, "нечего слить или ёмкость полна")
		return ITEM_INTERACT_BLOCKING
	update_appearance(UPDATE_ICON_STATE)
	balloon_alert(user, "ядовитый концентрат слит")
	return ITEM_INTERACT_SUCCESS

/// Cancels the timer without consuming any input.
/obj/machinery/nutrient_paste/proc/cancel_cycle()
	if(!cycle_timer)
		return
	deltimer(cycle_timer)
	cycle_timer = null

/// Clears the busy state and rechecks power and anchoring at completion.
/obj/machinery/nutrient_paste/proc/finish_cycle()
	SHOULD_CALL_PARENT(TRUE)
	cycle_timer = null
	update_appearance(UPDATE_ICON_STATE)
	return can_run_cycle()

/// An unloaded organic waste processor that dispenses toxic concentrate into open containers.
/obj/machinery/nutrient_paste/processor
	name = "organic waste processor"
	desc = "Перерабатывает урожай, пищевые отходы, бумагу, древесину и отдельные органические органы. Сырой концентрат ядовит."
	icon_state = "processor"
	base_icon_state = "processor"
	circuit = /obj/item/circuitboard/machine/organic_waste_processor
	reservoir_capacity = 80
	cycle_duration = 12 SECONDS
	active_power_usage = 1200
	/// Input items in loading order. Stacks are counted by units during processing.
	var/list/obj/item/queued_scraps = list()

/obj/machinery/nutrient_paste/processor/Destroy()
	if(drop_location())
		eject_scraps()
	queued_scraps = null
	return ..()

/obj/machinery/nutrient_paste/processor/Exited(atom/movable/gone, direction)
	. = ..()
	if(queued_scraps)
		queued_scraps -= gone

/obj/machinery/nutrient_paste/processor/examine(mob/user)
	. = ..()
	. += span_notice("Загружено предметов: [length(queued_scraps)]. Нажмите пустой рукой для запуска. Приложите открытую ёмкость, чтобы слить ядовитый концентрат. Alt + ЛКМ выгружает сырьё.")

/obj/machinery/nutrient_paste/processor/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(user.combat_mode)
		return ITEM_INTERACT_SKIP_TO_ATTACK
	if(istype(tool, /obj/item/reagent_containers) && tool.is_open_container())
		return drain_concentrate(user, tool)
	if(!can_use_controls(user))
		return ITEM_INTERACT_BLOCKING
	if(!scrap_yield(tool))
		balloon_alert(user, "сырьё не подходит")
		return ITEM_INTERACT_BLOCKING
	if(length(queued_scraps) >= 40)
		balloon_alert(user, "загрузочный отсек полон")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src) || tool.loc != src)
		return ITEM_INTERACT_BLOCKING
	queued_scraps += tool
	balloon_alert(user, "сырьё загружено")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/nutrient_paste/processor/interact(mob/user)
	..()
	if(!can_use_controls(user))
		return TRUE
	if(!length(queued_scraps))
		balloon_alert(user, "загрузите сырьё")
		return TRUE
	if(reservoir_capacity - reagents.total_volume < 2)
		balloon_alert(user, "слейте концентрат")
		return TRUE
	if(start_cycle(user))
		balloon_alert(user, "переработка началась")
	return TRUE

/obj/machinery/nutrient_paste/processor/click_alt(mob/user)
	if(cycle_timer)
		balloon_alert(user, "машина занята")
		return CLICK_ACTION_BLOCKING
	eject_scraps()
	return CLICK_ACTION_SUCCESS

/// Returns all unprocessed inputs to the tile, including partially used stacks.
/obj/machinery/nutrient_paste/processor/proc/eject_scraps()
	var/atom/output = drop_location()
	for(var/obj/item/scrap as anything in queued_scraps.Copy())
		scrap.forceMove(output)

/// Returns raw concentrate output per input unit, or zero for unsupported items.
/obj/machinery/nutrient_paste/processor/proc/scrap_yield(obj/item/scrap)
	if(QDELETED(scrap) || (scrap.item_flags & (ABSTRACT | DROPDEL)) || (scrap.flags_1 & HOLOGRAM_1) || length(scrap.contents))
		return 0
	if(istype(scrap, /obj/item/food/nutrient_paste))
		return 0
	if(istype(scrap, /obj/item/organ))
		var/obj/item/organ/organ = scrap
		if(!IS_ORGANIC_ORGAN(organ) || IS_ROBOTIC_ORGAN(organ) || IS_MINERAL_ORGAN(organ) || organ.owner || organ.bodypart_owner)
			return 0
		return 12
	if(isstack(scrap))
		var/obj/item/stack/stack = scrap
		if(stack.is_cyborg)
			return 0
		if(istype(stack, /obj/item/stack/sheet/mineral/wood))
			return 4
		if(istype(stack, /obj/item/stack/sheet/cardboard))
			return 2
	if(istype(scrap, /obj/item/paper))
		return 2
	if(istype(scrap, /obj/item/grown/log/steel))
		return 0
	if(istype(scrap, /obj/item/food) || istype(scrap, /obj/item/grown))
		return 6
	return 0

/obj/machinery/nutrient_paste/processor/finish_cycle()
	if(!..())
		return
	var/remaining_capacity = reservoir_capacity - reagents.total_volume
	var/produced = 0
	for(var/obj/item/scrap as anything in queued_scraps.Copy())
		var/volume_per_unit = scrap_yield(scrap)
		if(!volume_per_unit || scrap.loc != src || volume_per_unit > remaining_capacity)
			continue
		var/volume = volume_per_unit
		if(isstack(scrap))
			var/obj/item/stack/stack = scrap
			var/units = min(stack.get_amount(), FLOOR(remaining_capacity / volume_per_unit, 1))
			if(!units || !stack.use(units))
				continue
			volume *= units
		else
			queued_scraps -= scrap
			qdel(scrap)
		produced += volume
		remaining_capacity -= volume
	if(produced)
		reagents.add_reagent(/datum/reagent/toxin/biomass_concentrate, produced)
		say("Партия готова. Слейте концентрат в открытую ёмкость.")
	else
		say("Для этой партии не хватает сырья или места в баке.")
	update_appearance(UPDATE_ICON_STATE)

/// An unloaded cafeteria dispenser that turns concentrate into individual edible portions.
/obj/machinery/nutrient_paste/dispenser
	name = "nutrient paste dispenser"
	desc = "Очищает токсичный концентрат и выдаёт съедобную питательную пасту."
	icon_state = "dispenser"
	base_icon_state = "dispenser"
	circuit = /obj/item/circuitboard/machine/nutrient_paste_dispenser
	reservoir_capacity = 160
	cycle_duration = 2 SECONDS
	ready_volume = PASTE_PORTION_COST
	active_power_usage = 400

/obj/machinery/nutrient_paste/dispenser/examine(mob/user)
	. = ..()
	. += span_notice("Доступно порций: [FLOOR(reagents.total_volume / PASTE_PORTION_COST, 1)]. Заправьте чистым концентратом из открытой ёмкости. Нажмите пустой рукой для выдачи.")
	. += span_notice("ПКМ с открытой ёмкостью сливает концентрат из бака.")

/obj/machinery/nutrient_paste/dispenser/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(user.combat_mode)
		return ITEM_INTERACT_SKIP_TO_ATTACK
	if(!istype(tool, /obj/item/reagent_containers) || !tool.is_open_container())
		return ..()
	if(!can_use_controls(user))
		return ITEM_INTERACT_BLOCKING
	var/volume = tool.reagents.get_reagent_amount(/datum/reagent/toxin/biomass_concentrate)
	if(!volume || volume != tool.reagents.total_volume)
		balloon_alert(user, "нужен чистый концентрат")
		return ITEM_INTERACT_BLOCKING
	if(!tool.reagents.trans_to(src, volume, transferred_by = user))
		balloon_alert(user, "бак полон")
		return ITEM_INTERACT_BLOCKING
	update_appearance(UPDATE_ICON_STATE)
	balloon_alert(user, "концентрат залит")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/nutrient_paste/dispenser/item_interaction_secondary(mob/living/user, obj/item/tool, list/modifiers)
	if(!user.combat_mode && istype(tool, /obj/item/reagent_containers) && tool.is_open_container())
		return drain_concentrate(user, tool)
	return ..()

/obj/machinery/nutrient_paste/dispenser/interact(mob/user)
	..()
	if(!can_use_controls(user))
		return TRUE
	if(reagents.get_reagent_amount(/datum/reagent/toxin/biomass_concentrate) < PASTE_PORTION_COST)
		balloon_alert(user, "недостаточно концентрата")
		return TRUE
	start_cycle(user)
	return TRUE

/obj/machinery/nutrient_paste/dispenser/finish_cycle()
	if(!..() || reagents.get_reagent_amount(/datum/reagent/toxin/biomass_concentrate) < PASTE_PORTION_COST || !drop_location())
		return
	reagents.remove_reagent(/datum/reagent/toxin/biomass_concentrate, PASTE_PORTION_COST)
	new /obj/item/food/nutrient_paste(drop_location())
	playsound(src, 'sound/machines/click.ogg', 35, TRUE)
	update_appearance(UPDATE_ICON_STATE)

/// Circuit board for building or servicing the organic waste processor.
/obj/item/circuitboard/machine/organic_waste_processor
	name = "Organic Waste Processor"
	greyscale_colors = CIRCUIT_COLOR_SERVICE
	build_path = /obj/machinery/nutrient_paste/processor
	req_components = list(
		/datum/stock_part/matter_bin = 1,
		/datum/stock_part/servo = 1,
	)

/// Circuit board for building or servicing the nutrient paste dispenser.
/obj/item/circuitboard/machine/nutrient_paste_dispenser
	name = "Nutrient Paste Dispenser"
	greyscale_colors = CIRCUIT_COLOR_SERVICE
	build_path = /obj/machinery/nutrient_paste/dispenser
	req_components = list(
		/datum/stock_part/matter_bin = 1,
		/datum/stock_part/servo = 1,
	)

#undef PASTE_PORTION_COST
