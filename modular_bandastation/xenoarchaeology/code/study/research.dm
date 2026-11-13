/**
 * # Xenoarchaeology research and journal
 *
 * Adapted from Voidcrew PR #506. The first full analysis of a dug large find pays research once,
 * as research notes the analyser prints for any R&D console; a find that came out of the rock
 * damaged pays half. Dug curios and strange objects pay once when catalogued on the scan pad and
 * stay whole (Voidcrew destroyed them in the destructive analyzer).
 *
 * Every dug find carries a corps journal record: extraction, analysis, each stimulus tried on the
 * pad and its label are written there as facts. Field artefacts are catalogued here the same way.
 */

/// First full analysis of a large artifact, by stamped band (green, yellow, red).
#define ARTIFACT_RESEARCH_POINTS list(100, 150, 250)
/// Multiplier for a rare or extreme main effect.
#define ARTIFACT_RESEARCH_RARE_MULT 1.5
/// Multiplier for a find that came out of the rock damaged.
#define ARTIFACT_RESEARCH_DAMAGED_MULT 0.5

/// Journal record of one dug find; its ID is the find's catalogue number.
/datum/expedition_record/xenoarch_find

/datum/expedition_record/xenoarch_find/New(serial, atom/where)
	. = ..()
	id = serial
	var/turf/tile = get_turf(where)
	origin = tile ? "[get_area(tile)] ([tile.x], [tile.y], [tile.z])" : "место не установлено"

/obj/machinery/artifact
	/// Corps journal record, made when it is dug.
	var/datum/expedition_record/xenoarch_find/journal_record

/// Writes a fact about this find to the corps journal, if it was dug.
/obj/machinery/artifact/proc/journal_note(mob/user, text)
	journal_record?.log_observation(user, src, text)

/obj/item/xenoarch_curio
	/// Paid its catalogue research already.
	var/research_paid = FALSE

/obj/item/relic/excavated
	/// Paid its catalogue research already.
	var/research_paid = FALSE

/// Research points the first full analysis of `artifact` pays: 0 once paid or if it was never dug.
/proc/artifact_research_value(obj/machinery/artifact/artifact)
	if(QDELETED(artifact) || !artifact.is_dug() || artifact.research_paid || !artifact.main_effect)
		return 0
	var/list/points = ARTIFACT_RESEARCH_POINTS
	. = points[XENOARCH_BAND_INDEX(artifact.origin_band)]
	if(artifact.main_effect.tier >= ARTIFACT_TIER_RARE)
		. *= ARTIFACT_RESEARCH_RARE_MULT
	if(artifact.damaged)
		. *= ARTIFACT_RESEARCH_DAMAGED_MULT
	return round(.)

/// Claims the research for analysing `find`, once per find. Returns the points, or 0.
/proc/xenoarch_claim_analysis(obj/machinery/artifact/find, atom/analyser, mob/user)
	var/points = artifact_research_value(find)
	if(points <= 0)
		return 0
	find.research_paid = TRUE
	return points

/// Prints claimed research as notes at `where`.
/proc/xenoarch_print_analysis_notes(atom/where, points)
	if(!where || points <= 0)
		return null
	return new /obj/item/research_notes(where, points, "xenoarchaeology")

/// Catalogue research for small finds, by type: a full set is a pleasant extra, not a research route.
GLOBAL_LIST_INIT(xenoarch_curio_research_points, list(
	/obj/item/xenoarch_curio/shell = 20,
	/obj/item/xenoarch_curio/plant_fossil = 25,
	/obj/item/xenoarch_curio/bone = 25,
	/obj/item/xenoarch_curio/bowl = 25,
	/obj/item/xenoarch_curio/skull = 30,
	/obj/item/xenoarch_curio/urn = 30,
	/obj/item/xenoarch_curio/scrap = 30,
	/obj/item/xenoarch_curio/sidearm = 35,
	/obj/item/xenoarch_curio/seed_pod = 40,
	/obj/item/xenoarch_curio/statuette = 45,
	/obj/item/xenoarch_curio/instrument = 45,
	/obj/item/xenoarch_curio/idol = 50,
	/obj/item/xenoarch_curio/skeleton = 60,
	/obj/item/relic/excavated = 60,
))

/// Catalogues a dug small find, a field artefact or a planetary anomaly core lying on the scan pad. Returns TRUE if one was found there.
/obj/machinery/artifact_analyser/proc/catalogue_small_find(mob/user)
	for(var/obj/item/find in pad.loc)
		if(HAS_TRAIT(find, TRAIT_EXPEDITION_ORDER_ITEM))
			print_catalogue(find, 0, "<br>Предмет заказа экспедиционного корпуса.")
			SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_FIND_CATALOGUED, find, user, src)
			return TRUE
		var/obj/item/assembly/signaler/anomaly/planetary/core = find
		if(istype(core))
			var/core_points = core.research_paid ? 0 : core.research_points
			if(!core.research_paid)
				xenoarch_record_study(core.energy_kind)
				core.journal_record?.log_observation(user, src, "Ядро каталогизировано на сканирующей площадке.")
				SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_FIND_CATALOGUED, core, user, src)
			core.research_paid = TRUE
			print_catalogue(find, core_points, "<br>Вид энергии: [artifact_energy_kind(core.energy_kind)?.report_name]")
			return TRUE
		if(!istype(find, /obj/item/xenoarch_curio) && !istype(find, /obj/item/relic/excavated) && !istype(find, /obj/item/field_artefact))
			continue
		if(isnull(xenoarch_find_band(find)))
			continue
		var/obj/item/xenoarch_curio/curio = find
		var/obj/item/relic/excavated/relic = find
		var/obj/item/field_artefact/artefact = find
		var/paid = istype(curio) ? curio.research_paid : (istype(relic) ? relic.research_paid : artefact.research_paid)
		var/points = 0
		if(istype(artefact))
			if(!paid)
				points = artefact.research_points
				artefact.research_paid = TRUE
				xenoarch_record_study(artefact.energy_kind)
				artefact.journal_record?.log_observation(user, src, "Каталогизирован на сканирующей площадке.")
				SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_FIND_CATALOGUED, artefact, user, src)
		else if(!paid)
			for(var/listed_type in GLOB.xenoarch_curio_research_points)
				if(istype(find, listed_type))
					points = GLOB.xenoarch_curio_research_points[listed_type]
					break
			if(istype(curio))
				curio.research_paid = TRUE
			else
				relic.research_paid = TRUE
		print_catalogue(find, points, "<br>Зона происхождения: [xenoarch_find_band(find)][istype(artefact) ? "<br>Вид энергии: [artifact_energy_kind(artefact.energy_kind)?.report_name]<br>Реакции: [artefact.catalogue_note]" : ""]")
		return TRUE
	return FALSE

/// Announces the catalogue entry for `find` and prints its report, plus research notes worth `points`.
/obj/machinery/artifact_analyser/proc/print_catalogue(obj/item/find, points, details)
	say(points ? "Находка каталогизирована. Данные напечатаны." : "Находка уже в каталоге.")
	playsound(src, 'sound/machines/ping.ogg', 30, FALSE)
	var/obj/item/paper/artifact_report/report = new(drop_location())
	report.name = "отчёт каталогизации ([find.name])"
	report.add_raw_text("<b>Каталог находок</b><br>Объект: [html_encode(find.name)]<br>[html_encode(find.desc)][details]", advanced_html = TRUE)
	report.update_appearance()
	if(points)
		xenoarch_print_analysis_notes(drop_location(), points)

#undef ARTIFACT_RESEARCH_POINTS
#undef ARTIFACT_RESEARCH_RARE_MULT
#undef ARTIFACT_RESEARCH_DAMAGED_MULT
