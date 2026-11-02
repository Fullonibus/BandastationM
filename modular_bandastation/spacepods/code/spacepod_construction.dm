/// Adapted from ss220-space/Paradise, code/modules/spacepods/construction.dm (AGPL-3.0).
/obj/structure/spacepod_frame
	name = "space pod chassis"
	desc = "Незавершённый каркас космического челнока."
	density = TRUE
	anchored = TRUE
	layer = BELOW_MOB_LAYER
	icon = 'modular_bandastation/spacepods/icons/pod_construction.dmi'
	icon_state = "pod_1"
	bound_width = 64
	bound_height = 64
	dir = EAST

/obj/structure/spacepod_frame/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/construction/spacepod)

/// Construction clicks can reach any chassis tile while retaining normal border checks.
/obj/structure/spacepod_frame/CheckReachableAdjacency(atom/movable/reacher, reacher_range)
	if(!isturf(loc) || !isturf(reacher.loc))
		return ..()
	for(var/turf/frame_turf as anything in locs)
		if(frame_turf.Adjacent(reacher, target = src, mover = reacher))
			return TRUE
	return ..()

/// Use the native reversible construction component to keep refunds tied to completed steps.
/datum/component/construction/spacepod
	result = /obj/vehicle/sealed/spacepod/civilian
	steps = list(
		list(
			"key" = /obj/item/stack/cable_coil,
			"amount" = 4,
			"no_refund" = TRUE, // Paradise cuts the first wiring out without returning cable.
			"desc" = "Пустой каркас: проложите четыре отрезка <b>кабеля</b>.",
			"forward_message" = "Вы прокладываете проводку челнока.",
			"icon_state" = "pod_1",
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_WIRECUTTER,
			"desc" = "Проводка проложена: закрепите её <b>отвёрткой</b> или срежьте <b>кусачками</b>.",
			"forward_message" = "Вы закрепляете проводку челнока.",
			"backward_message" = "Вы срезаете проводку челнока.",
			"icon_state" = "pod_2",
		),
		list(
			"key" = /obj/item/circuitboard/mecha/pod,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_SCREWDRIVER,
			"desc" = "Проводка закреплена: вставьте <b>главную плату челнока</b>.",
			"forward_message" = "Вы устанавливаете главную плату челнока.",
			"backward_message" = "Вы ослабляете крепления проводки.",
			"icon_state" = "pod_3",
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"desc" = "Главная плата установлена: закрепите её <b>отвёрткой</b> или извлеките <b>ломом</b>.",
			"forward_message" = "Вы закрепляете главную плату челнока.",
			"backward_message" = "Вы извлекаете главную плату челнока.",
			"icon_state" = "pod_4",
		),
		list(
			"key" = /obj/item/pod_parts/core,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_SCREWDRIVER,
			"desc" = "Главная плата закреплена: установите <b>ядро челнока</b>.",
			"forward_message" = "Вы устанавливаете ядро челнока.",
			"backward_message" = "Вы откручиваете главную плату челнока.",
			"icon_state" = "pod_5",
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"desc" = "Ядро установлено: закрепите его <b>гаечным ключом</b> или извлеките <b>ломом</b>.",
			"forward_message" = "Вы затягиваете крепления ядра челнока.",
			"backward_message" = "Вы извлекаете ядро челнока.",
			"icon_state" = "pod_6",
		),
		list(
			"key" = /obj/item/stack/sheet/iron,
			"amount" = 5,
			"back_key" = TOOL_WRENCH,
			"desc" = "Ядро закреплено: добавьте пять <b>железных листов</b> для герметичного корпуса.",
			"forward_message" = "Вы устанавливаете герметичные переборки челнока.",
			"backward_message" = "Вы ослабляете крепления ядра челнока.",
			"icon_state" = "pod_7",
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"desc" = "Переборки установлены: закрепите их <b>гаечным ключом</b> или снимите <b>ломом</b>.",
			"forward_message" = "Вы закрепляете переборки челнока.",
			"backward_message" = "Вы снимаете переборки челнока.",
			"icon_state" = "pod_8",
		),
		list(
			"key" = TOOL_WELDER,
			"back_key" = TOOL_WRENCH,
			"desc" = "Переборки закреплены: герметизируйте их <b>сваркой</b>.",
			"forward_message" = "Вы завариваете переборки челнока.",
			"backward_message" = "Вы откручиваете переборки челнока.",
			"icon_state" = "pod_9",
		),
		list(
			"key" = /obj/item/pod_parts/armor,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_WELDER,
			"desc" = "Переборки герметичны: установите <b>броню гражданского челнока</b>.",
			"forward_message" = "Вы устанавливаете броню челнока.",
			"backward_message" = "Вы разрезаете сварные швы переборок.",
			"icon_state" = "pod_10",
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"desc" = "Броня установлена: закрепите её <b>гаечным ключом</b> или снимите <b>ломом</b>.",
			"forward_message" = "Вы закрепляете броню челнока.",
			"backward_message" = "Вы снимаете броню челнока.",
			"icon_state" = "pod_11",
		),
		list(
			"key" = TOOL_WELDER,
			"back_key" = TOOL_WRENCH,
			"desc" = "Броня закреплена: завершите сборку <b>сваркой</b>.",
			"forward_message" = "Вы завариваете броню и завершаете сборку челнока.",
			"backward_message" = "Вы откручиваете броню челнока.",
			"icon_state" = "pod_12",
		),
	)

/datum/component/construction/spacepod/action(datum/source, obj/item/used_item, mob/living/user)
	// The signal-handler contract is inherited from construction.action().
	if(QDELETED(used_item) || QDELETED(user) || user.combat_mode || !is_right_key(used_item))
		return NONE
	// Completion deletes the component and its parent; decide the attack-chain result before that happens.
	INVOKE_ASYNC(src, PROC_REF(check_step), used_item, user)
	return COMPONENT_NO_AFTERATTACK

/datum/component/construction/spacepod/check_step(obj/item/used_item, mob/living/user)
	var/obj/structure/spacepod_frame/chassis = parent
	if(QDELETED(chassis) || QDELETED(used_item) || QDELETED(user) || !isturf(chassis.loc) || user.combat_mode)
		return FALSE
	if(!user.can_perform_action(chassis, NEED_DEXTERITY|NEED_HANDS) || !user.is_holding(used_item))
		return FALSE
	return ..()

/datum/component/construction/spacepod/custom_action(obj/item/used_item, mob/living/user, diff)
	var/list/step = steps[index]
	if(!..())
		return FALSE
	to_chat(user, span_notice(step[diff == FORWARD ? "forward_message" : "backward_message"]))
	var/atom/chassis = parent
	chassis.add_fingerprint(user)
	return TRUE

/datum/component/construction/spacepod/spawn_result()
	var/obj/structure/spacepod_frame/chassis = parent
	var/obj/vehicle/sealed/spacepod/civilian/pod = new(chassis.loc)
	chassis.transfer_fingerprints_to(pod)
	SSblackbox.record_feedback("amount", "spacepod_created", 1)
	qdel(chassis)
