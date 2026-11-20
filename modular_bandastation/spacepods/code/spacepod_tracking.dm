/obj/machinery/computer/podtracker
	name = "pod tracking console"
	desc = "Отслеживает маяки космических челноков."
	icon_keyboard = "tech_key"
	icon_screen = "rdcomp"
	light_color = LIGHT_COLOR_ORANGE
	circuit = /obj/item/circuitboard/computer/podtracker

/obj/machinery/computer/podtracker/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SpacepodTracking", name)
		ui.open()

/obj/machinery/computer/podtracker/ui_data(mob/user)
	var/list/pods = list()
	for(var/obj/item/spacepod_equipment/misc/tracker/tracker as anything in GLOB.pod_trackers)
		var/obj/vehicle/sealed/spacepod/pod = tracker.my_atom
		var/turf/position = get_turf(pod || tracker)
		if(!position)
			continue
		var/list/passenger_names = list()
		for(var/mob/passenger as anything in pod?.passengers)
			passenger_names += passenger.name
		pods += list(list(
			"name" = tracker.tracking_name,
			"x" = position.x,
			"y" = position.y,
			"z" = position.z,
			"pilot" = pod?.pilot?.name || "Нет",
			"passengers" = length(passenger_names) ? jointext(passenger_names, ", ") : "Нет",
			"integrity" = pod ? ROUND_UP(pod.get_integrity() / pod.max_integrity * 100) : null,
			"charge" = pod?.battery ? ROUND_UP(pod.battery.percent()) : null,
		))
	return list("pods" = pods)

/obj/item/circuitboard/computer/podtracker
	custom_materials = list(/datum/material/glass = SHEET_MATERIAL_AMOUNT * 1)
	name = "Pod Tracking Console"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/computer/podtracker
