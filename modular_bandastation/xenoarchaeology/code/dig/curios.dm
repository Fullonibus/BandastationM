/**
 * # Curios and small finds
 *
 * What comes out of strange rocks: fossils, pottery, statuettes, instruments, scrap, now and then
 * tg's strange object, a page of research notes or a single item from a sealed research case.
 * Each dig site has a kind (Bay's: garden, animal, house, technical, temple, war), weighted by
 * the planet's climate, which decides its small finds by tier.
 *
 * Every curio and strange object that comes out of the ground is stamped with the band it was
 * dug in (origin_band). Buyers read that and `curio_class`; an unstamped one (admin spawned,
 * experimentor copies, maintenance relics) is not a find.
 *
 * Sprites: Polaris (6cd19fe0dec6) icons/obj/xenoarchaeology.dmi small-find states, CC BY-SA 3.0.
 */

// ===== Site kinds =====

/// Climate favourites: planet type -> site kinds that turn up more often there.
GLOBAL_LIST_INIT(xenoarch_site_kind_climates, list(
	/datum/stationtrauma_overmap_site/space/planet = list(XENOARCH_SITE_TECHNICAL, XENOARCH_SITE_WAR),
	/datum/stationtrauma_overmap_site/space/planet/frozen = list(XENOARCH_SITE_ANIMAL, XENOARCH_SITE_HOUSE),
	/datum/stationtrauma_overmap_site/space/planet/frozen/plain = list(XENOARCH_SITE_HOUSE, XENOARCH_SITE_GARDEN),
	/datum/stationtrauma_overmap_site/space/planet/arid = list(XENOARCH_SITE_TECHNICAL, XENOARCH_SITE_TEMPLE),
	/datum/stationtrauma_overmap_site/space/planet/lush = list(XENOARCH_SITE_GARDEN, XENOARCH_SITE_ANIMAL),
	/datum/stationtrauma_overmap_site/space/planet/lava = list(XENOARCH_SITE_TEMPLE, XENOARCH_SITE_WAR),
	/datum/stationtrauma_overmap_site/space/planet/dead = list(XENOARCH_SITE_HOUSE, XENOARCH_SITE_TECHNICAL),
))

/// Picks a site kind, favouring the ones the planet's climate suits.
/proc/xenoarch_pick_site_kind(planet_type)
	var/list/weights = list()
	for(var/kind in list(XENOARCH_SITE_GARDEN, XENOARCH_SITE_ANIMAL, XENOARCH_SITE_HOUSE, XENOARCH_SITE_TECHNICAL, XENOARCH_SITE_TEMPLE, XENOARCH_SITE_WAR))
		weights[kind] = 10
	var/list/favoured = GLOB.xenoarch_site_kind_climates[planet_type]
	for(var/kind in favoured)
		weights[kind] = 30
	return pick_weight(weights)

/// A small find's tier, 1 to 3, by band.
/proc/xenoarch_roll_small_tier(band)
	var/list/odds
	switch(XENOARCH_BAND_INDEX(band))
		if(XENOARCH_BAND_RED)
			odds = XENOARCH_SMALL_TIER_ODDS_RED
		if(XENOARCH_BAND_YELLOW)
			odds = XENOARCH_SMALL_TIER_ODDS_YELLOW
		else
			odds = XENOARCH_SMALL_TIER_ODDS_GREEN
	return text2num(pick_weight(odds))

/// Stands in a small find table for "one item from a sealed research case".
/datum/xenoarch_research_draw

/// What a strange rock from a site of `site_kind` holds at `tier`: a type path.
/proc/xenoarch_small_find(site_kind, tier)
	switch(site_kind)
		if(XENOARCH_SITE_GARDEN)
			switch(tier)
				if(1)
					return pick(/obj/item/xenoarch_curio/plant_fossil, /obj/item/xenoarch_curio/shell)
				if(2)
					return /obj/item/xenoarch_curio/seed_pod
				else
					return /obj/item/research_notes/excavation/tiny
		if(XENOARCH_SITE_ANIMAL)
			switch(tier)
				if(1)
					return pick(/obj/item/xenoarch_curio/bone, /obj/item/xenoarch_curio/skull)
				if(2)
					return /obj/item/xenoarch_curio/skeleton
				else
					return /obj/item/research_notes/excavation/tiny
		if(XENOARCH_SITE_TECHNICAL)
			switch(tier)
				if(1)
					return /obj/item/xenoarch_curio/scrap
				if(2)
					return /obj/item/relic/excavated
				else
					return /datum/xenoarch_research_draw
		if(XENOARCH_SITE_TEMPLE)
			switch(tier)
				if(1)
					return pick(/obj/item/xenoarch_curio/urn, /obj/item/xenoarch_curio/statuette)
				if(2)
					return pick(/obj/item/xenoarch_curio/instrument, /obj/item/xenoarch_curio/idol)
				else
					return /obj/item/relic/excavated
		if(XENOARCH_SITE_WAR)
			switch(tier)
				if(1)
					return /obj/item/xenoarch_curio/sidearm
				if(2)
					return /obj/item/relic/excavated
				else
					return /obj/item/research_notes/excavation/small
	// House, and anything unknown
	switch(tier)
		if(1)
			return pick(/obj/item/xenoarch_curio/bowl, /obj/item/xenoarch_curio/urn)
		if(2)
			return pick(/obj/item/xenoarch_curio/statuette, /obj/item/xenoarch_curio/instrument)
	return /obj/item/relic/excavated

/// Makes a small find at `destination` and stamps it with `band`. Returns it.
/proc/xenoarch_spawn_small_find(find_type, atom/destination, band)
	if(find_type == /datum/xenoarch_research_draw)
		return xenoarch_research_draw(destination, band)
	if(!ispath(find_type, /atom/movable))
		return null
	var/atom/movable/find = new find_type(destination)
	xenoarch_stamp_find(find, band)
	return find

/// One item from the research loot theme, at the band's odds, as a sealed case would give it.
/proc/xenoarch_research_draw(atom/destination, band)
	var/static/list/draws = list(
		list(/obj/item/research_notes/excavation/small = 4, /obj/item/stock_parts/capacitor/adv = 2, /obj/item/stock_parts/scanning_module/adv = 2, /obj/item/stock_parts/servo/nano = 2),
		list(/obj/item/research_notes/excavation/medium = 4, /obj/item/stock_parts/capacitor/super = 2, /obj/item/stock_parts/scanning_module/phasic = 2, /obj/item/stock_parts/servo/pico = 2),
		list(/obj/item/research_notes/excavation/large = 4, /obj/item/stock_parts/capacitor/quadratic = 2, /obj/item/stock_parts/scanning_module/triphasic = 2, /obj/item/stock_parts/servo/femto = 2),
	)
	var/loot_path = pick_weight(draws[XENOARCH_BAND_INDEX(band)])
	return new loot_path(destination)

/// Stamps a curio or strange object with the band it was dug in.
/// First stamp wins. Returns TRUE if `find` is a stampable small find.
/proc/xenoarch_stamp_find(atom/movable/find, band)
	band = XENOARCH_BAND_INDEX(band)
	if(istype(find, /obj/item/xenoarch_curio))
		var/obj/item/xenoarch_curio/curio = find
		if(!isnull(curio.origin_band))
			return TRUE
		curio.origin_band = band
		return TRUE
	if(istype(find, /obj/item/relic/excavated))
		var/obj/item/relic/excavated/relic = find
		if(!isnull(relic.origin_band))
			return TRUE
		relic.origin_band = band
		return TRUE
	return FALSE

// ===== Research notes =====

/obj/item/research_notes/excavation
	origin_type = "xenoarchaeology"

/obj/item/research_notes/excavation/tiny
	value = 100

/obj/item/research_notes/excavation/small
	value = 250

// Sealed-case draws for deeper bands; starting balance values.
/obj/item/research_notes/excavation/medium
	value = 400

/obj/item/research_notes/excavation/large
	value = 700

// ===== Strange object =====

/// tg's strange object, as dug out of a site. Only these, stamped, count as finds.
/obj/item/relic/excavated
	inhand_icon_state = "blackcube"
	/// Band it was dug in, or null
	var/origin_band

// ===== Curios =====

/obj/item/xenoarch_curio
	name = "curio"
	desc = "Что-то древнее, извлечённое из земли."
	icon = 'modular_bandastation/xenoarchaeology/icons/curios.dmi'
	icon_state = "bone"
	inhand_icon_state = "minimeteor"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FIRE_PROOF
	/// XENOARCH_CURIO_*: what a buyer files it under
	var/curio_class = XENOARCH_CURIO_FOSSIL
	/// ZONE_* it was dug in, or null if it never came out of the ground
	var/origin_band
	/// Icon states to pick from
	var/list/variants
	/// Descriptions to pick from
	var/list/descs

/obj/item/xenoarch_curio/Initialize(mapload)
	. = ..()
	if(length(variants))
		icon_state = pick(variants)
	if(length(descs))
		desc = pick(descs)
	pixel_x = base_pixel_x + rand(-6, 6)
	pixel_y = base_pixel_y + rand(-4, 4)

/obj/item/xenoarch_curio/examine(mob/user)
	. = ..()
	if(!isnull(origin_band))
		. += "В нём всё ещё забита пыль раскопок."

/obj/item/xenoarch_curio/plant_fossil
	name = "окаменелое растение"
	curio_class = XENOARCH_CURIO_FOSSIL
	variants = list("plant1", "plant2", "plant3", "plant4")
	descs = list(
		"Каменная пластинка с отпечатком листа. Ни у одного нынешнего растения нет таких листьев.",
		"Плита породы с вдавленной ветвью, на которой видна каждая жилка.",
	)

/obj/item/xenoarch_curio/shell
	name = "окаменелая раковина"
	curio_class = XENOARCH_CURIO_SHELL
	variants = list("shell")
	descs = list(
		"Закрученная раковина, ставшая камнем, из давно высохшего моря.",
		"Рубчатая раковина, насквозь каменная.",
	)

/obj/item/xenoarch_curio/seed_pod
	name = "семенная коробочка"
	curio_class = XENOARCH_CURIO_STATUETTE
	variants = list("green_lump")
	descs = list(
		"Твёрдая зелёная коробочка размером с кулак. Если потрясти, внутри что-то гремит.",
		"Стекловидная зелёная семенная оболочка, запечатанная неведомо сколько времени.",
	)

/obj/item/xenoarch_curio/bone
	name = "окаменелая кость"
	curio_class = XENOARCH_CURIO_FOSSIL
	variants = list("bone")
	descs = list(
		"Длинная окаменевшая кость, всё ещё лежащая в кусочке породы.",
		"Тяжёлая кость конечности чего-то большого. Теперь это сплошной камень.",
	)

/obj/item/xenoarch_curio/skull
	name = "окаменелый череп"
	curio_class = XENOARCH_CURIO_FOSSIL
	variants = list("skull", "hskull")
	descs = list(
		"Череп, вросший в камень. Глазницы смотрят не туда, куда у любого известного вам существа.",
		"Рогатый череп, наполовину освобождённый из породы.",
	)

/obj/item/xenoarch_curio/skeleton
	name = "окаменелый скелет"
	curio_class = XENOARCH_CURIO_STATUETTE
	w_class = WEIGHT_CLASS_BULKY
	variants = list("uskel", "skel")
	descs = list(
		"Целый скелет давно вымершего существа, закреплённый стоймя на глыбе собственной породы.",
		"Все кости небольшого животного, лежащие там, где оно погибло.",
	)

/obj/item/xenoarch_curio/bowl
	name = "глиняная чаша"
	curio_class = XENOARCH_CURIO_POTTERY
	variants = list("bowl")
	descs = list(
		"Неглубокая чаша из обожжённой глины со сколотым краем; глазурь внутри всё ещё яркая.",
		"Чаша ручной лепки. В донышке запечён чей-то отпечаток пальца.",
	)

/obj/item/xenoarch_curio/urn
	name = "urn"
	curio_class = XENOARCH_CURIO_POTTERY
	variants = list("urn", "urn1", "urn2", "urn3")
	descs = list(
		"Узкогорлая урна, запечатанная чем-то, что затвердело как камень.",
		"Расписная урна. Узор повторяется по кругу и нигде точно не сходится.",
	)

/obj/item/xenoarch_curio/statuette
	name = "statuette"
	curio_class = XENOARCH_CURIO_STATUETTE
	variants = list("statuette", "statuette1", "statuette2", "statuette3")
	descs = list(
		"Небольшая резная фигурка. У рук слишком много суставов.",
		"Фигурка, стёртая до гладкости руками задолго до того, как её закопали.",
	)

/obj/item/xenoarch_curio/instrument
	name = "странный инструмент"
	curio_class = XENOARCH_CURIO_INSTRUMENT
	variants = list("instrument")
	descs = list(
		"Колокольчики, язычки или и то и другое в раме из тёмного металла. Если потрясти, не издаёт ни звука.",
		"Что-то, на чём играли, но не такими руками, как ваши.",
	)

/obj/item/xenoarch_curio/idol
	name = "idol"
	curio_class = XENOARCH_CURIO_STATUETTE
	variants = list("unknown1")
	descs = list(
		"Колонна из колец золотистого металла, сложенная как позвоночник.",
		"Колонна из металлических колец, стёртых до гладкости там, где её когда-то держали.",
	)

/obj/item/xenoarch_curio/scrap
	name = "проржавевший механизм"
	curio_class = XENOARCH_CURIO_POTTERY
	variants = list("unknown2", "unknown3", "unknown4", "box", "sliver1", "pen1")
	descs = list(
		"Ком механизмов, спаянный временем. Что бы он ни делал, перестал давным-давно.",
		"Какая-то деталь с резьбой, забитой древней пылью.",
	)

/obj/item/xenoarch_curio/sidearm
	name = "истлевший пистолет"
	curio_class = XENOARCH_CURIO_POTTERY
	w_class = WEIGHT_CLASS_NORMAL
	variants = list("egun1", "egun3", "egun5", "egun9", "gun1", "gun3", "gunold")
	descs = list(
		"Пистолет с войны, которую никто не помнит. Механизм внутри сгнил намертво.",
		"Рукоять и ствол, более или менее. Он больше никогда не выстрелит.",
	)
