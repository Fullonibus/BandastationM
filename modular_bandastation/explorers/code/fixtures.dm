/obj/machinery/door/airlock/research/expedition
	name = "expedition airlock"
	icon = 'modular_bandastation/explorers/icons/airlock.dmi'
	assemblytype = /obj/structure/door_assembly/expedition

/obj/machinery/door/airlock/research/expedition/glass
	name = "expedition glass airlock"
	opacity = FALSE
	glass = TRUE

/obj/structure/door_assembly/expedition
	name = "expedition airlock assembly"
	icon = 'modular_bandastation/explorers/icons/airlock.dmi'
	base_name = "expedition airlock"
	glass_type = /obj/machinery/door/airlock/research/expedition/glass
	airlock_type = /obj/machinery/door/airlock/research/expedition

/obj/structure/sign/departments/expedition
	name = "табличка экспедиционного корпуса"
	desc = "Компас со звездой обозначает экспедиционный корпус Нанотрейзен."
	sign_change_name = "Department - Expedition Corps"
	icon = 'modular_bandastation/explorers/icons/signs.dmi'
	icon_state = "expedition"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/sign/departments/expedition, 32)
