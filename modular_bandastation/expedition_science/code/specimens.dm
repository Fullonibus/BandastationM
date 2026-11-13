GLOBAL_VAR_INIT(stationtrauma_research_serial, 0)

/** A stable authored location ID, independent of room names and the allocated z-level. */
/obj/effect/landmark/stationtrauma_research_site
	name = "район экспедиционного исследования"
	/// Set once per mapped location; place the same ID on each of its decks.
	var/site_id

/** Immutable observations shared by the field source and its physical specimens. */
/datum/stationtrauma_research_record
	parent_type = /datum/expedition_record
	/// Authored location identity, or null when no site marker was mapped.
	var/site_id
	/// Display name captured before the specimen leaves its location.
	var/site_name
	/// Coordinates supplement the stable site ID; they never replace it.
	var/coordinates
	/// Original source name and authored observations, not random scanner flavour.
	var/source_name
	/// Information available to a field survey.
	var/field_notes
	/// Information revealed by laboratory analysis.
	var/laboratory_notes
	/// A completed field survey is required before taking a documented specimen.
	var/surveyed = FALSE

/datum/stationtrauma_research_record/New(obj/structure/stationtrauma_research_source/source)
	GLOB.stationtrauma_research_serial++
	id = "F-[GLOB.stationtrauma_research_serial]"
	source_name = source.name
	field_notes = source.field_notes
	laboratory_notes = source.laboratory_notes
	var/turf/tile = get_turf(source)
	coordinates = tile ? "[tile.x], [tile.y], [tile.z]" : "не установлены"
	site_name = "неразмеченный район"
	for(var/obj/effect/landmark/stationtrauma_research_site/site in GLOB.landmarks_list)
		if(!tile || site.z != tile.z || !istext(site.site_id) || !length(site.site_id))
			continue
		site_id = site.site_id
		site_name = site.name
		break
	origin = "[source_name]; [site_name] ([site_id || "ID не назначен"]), [coordinates]"

/** Build safe display text; possession of a record alone does not reveal laboratory results. */
/datum/stationtrauma_research_record/proc/specimen_text(laboratory = FALSE)
	var/list/lines = list(
		"<b>Находка [html_encode(id)]</b>: [html_encode(source_name)]",
		"Район: [html_encode(site_name)] ([html_encode(site_id || "ID не назначен")])",
		"Координаты обследования: [html_encode(coordinates)]",
		"Полевые наблюдения: [html_encode(field_notes)]",
	)
	if(laboratory)
		lines += "Лабораторные наблюдения: [html_encode(laboratory_notes)]"
	return lines.Join("<br>")

/** Surveyable source with a finite specimen supply. */
/obj/structure/stationtrauma_research_source
	name = "колония местной растительности"
	desc = "Неизученный образец местной флоры. Сначала обследуйте его полевым сканером, затем используйте пустой контейнер для проб."
	icon = 'icons/obj/fluff/flora/jungleflora.dmi'
	icon_state = "bushb1"
	anchored = TRUE
	/// Samples remaining after completed collections.
	var/remaining_samples = 3
	/// Authored field observations.
	var/field_notes = "Волокнистая колония, закреплённая на грунте. Различимы отдельные ветвящиеся побеги."
	/// Authored laboratory observations.
	var/laboratory_notes = "Обнаружены клетки с плотной оболочкой и внутриклеточными пигментными включениями. Нужны дальнейшие испытания для определения их свойств."
	/// Lazily allocated once; sampled observations survive removal of their source.
	var/datum/stationtrauma_research_record/record

/obj/structure/stationtrauma_research_source/examine(mob/user)
	. = ..()
	. += span_notice("Доступно проб: [remaining_samples]. [record?.surveyed ? "Полевое обследование выполнено." : "Полевое обследование не выполнено."]")

/** Repeated surveys and samples refer to the same discovery and authored properties. */
/obj/structure/stationtrauma_research_source/proc/research_record()
	if(!record)
		record = new(src)
	return record

/** Surveyable mineral source using the native ore appearance. */
/obj/structure/stationtrauma_research_source/mineral
	name = "необычный минеральный нарост"
	desc = "Кристаллические отложения в породе. Стратиграфический сканер и контейнер позволят доставить пробу в лабораторию."
	icon = 'icons/obj/ore.dmi'
	icon_state = "iron"
	field_notes = "Плотный минеральный нарост с заметными кристаллическими включениями."
	laboratory_notes = "Образец неоднороден: кристаллические включения окружены мелкозернистой матрицей. Химические свойства требуют отдельных испытаний."

/** Surveyable organic specimen source with authored field and laboratory observations. */
/obj/structure/stationtrauma_research_source/tissue
	name = "останки неизвестного организма"
	desc = "Фрагмент местного организма. После полевого обследования можно отобрать ткань для лаборатории."
	icon = 'icons/obj/food/meat.dmi'
	icon_state = "meat"
	field_notes = "Различимы плотные внешние ткани и более мягкая внутренняя структура."
	laboratory_notes = "Обнаружены несколько типов тканей и сеть полостей. По одному фрагменту нельзя восстановить физиологию целого организма."
