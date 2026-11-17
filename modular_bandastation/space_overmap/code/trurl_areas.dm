/** Independent orbital Trurl compartments, retaining the service CentCom's power and access environment. */
/area/shuttle/stationtrauma_space/trurl
	name = "Трурль"
	icon = 'icons/area/areas_centcom.dmi'
	icon_state = "centcom"
	static_lighting = TRUE
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	area_flags = NOTELEPORT
	flags_1 = NONE

/** Exterior nozzle mounts and trim are owned hull equipment, outside the sealed compartments. */
/area/shuttle/stationtrauma_space/trurl/exterior
	name = "Трурль - наружная обшивка"
	monitored_compartment = FALSE
	vacuum_by_design = TRUE

/** Trurl's command bridge. */
/area/shuttle/stationtrauma_space/trurl/control
	name = "ЦК - Мостик"
	icon_state = "centcom_control"

/** Trurl's first port. */
/area/shuttle/stationtrauma_space/trurl/fore
	name = "ЦК - Первый Порт"
	icon_state = "centcom_fore"

/** Trurl's courtroom. */
/area/shuttle/stationtrauma_space/trurl/courtroom
	name = "ЦК - Зал Суда"
	icon_state = "centcom_court"

/** Trurl's administrative offices. */
/area/shuttle/stationtrauma_space/trurl/admin
	name = "ЦК - Офисы"
	icon_state = "centcom_admin"

/** Trurl's response-team assembly room. */
/area/shuttle/stationtrauma_space/trurl/briefing
	name = "ЦК - Плац ОБР"
	icon_state = "centcom_briefing"

/** Trurl's armory. */
/area/shuttle/stationtrauma_space/trurl/armory
	name = "ЦК - Оружейная"
	icon_state = "centcom_armory"

/** Trurl's second port. */
/area/shuttle/stationtrauma_space/trurl/ferry
	name = "ЦК - Второй Порт"
	icon_state = "centcom_ferry"

/** Trurl's brig. */
/area/shuttle/stationtrauma_space/trurl/prison
	name = "ЦК - Тюрьма"
	icon_state = "centcom_prison"

/** Trurl's brig cells. */
/area/shuttle/stationtrauma_space/trurl/prison/cells
	name = "ЦК - Тюремная Камера"
	icon_state = "centcom_cells"

/** Trurl's cargo hangar. */
/area/shuttle/stationtrauma_space/trurl/supply
	name = "ЦК - Грузовой Ангар"
	icon_state = "centcom_supply"

/** Trurl's former supply-pod hangars, independent of the global service loading bays. */
/area/shuttle/stationtrauma_space/trurl/supplypod
	name = "ЦК - Ангары Системы Быстрой Доставки"
	icon_state = "supplypod"

/** Trurl's response-team hangar. */
/area/shuttle/stationtrauma_space/trurl/supplypod/loading/ert
	name = "ЦК - Ангар ОБР"
	icon_state = "supplypod_loading"

/** Trurl's first hangar. */
/area/shuttle/stationtrauma_space/trurl/supplypod/loading/one
	name = "ЦК - Первый Ангар"
	icon_state = "supplypod_loading"

/** Trurl's second hangar. */
/area/shuttle/stationtrauma_space/trurl/supplypod/loading/two
	name = "ЦК - Второй Ангар"
	icon_state = "supplypod_loading"

/** Trurl's third hangar. */
/area/shuttle/stationtrauma_space/trurl/supplypod/loading/three
	name = "ЦК - Третий Ангар"
	icon_state = "supplypod_loading"

/** Trurl's fourth hangar. */
/area/shuttle/stationtrauma_space/trurl/supplypod/loading/four
	name = "ЦК - Четвертый Ангар"
	icon_state = "supplypod_loading"

/** Trurl's main hangar. */
/area/shuttle/stationtrauma_space/trurl/supplypod/pod_storage
	name = "ЦК - Главный Ангар"
	icon_state = "supplypod_holding"

/** Trurl's corridors. */
/area/shuttle/stationtrauma_space/trurl/hallway
	name = "ЦК - Коридоры"

/** Trurl's conference room. */
/area/shuttle/stationtrauma_space/trurl/conference_room
	name = "ЦК - Конференц Зал"

/** Trurl's garden. */
/area/shuttle/stationtrauma_space/trurl/arboretum
	name = "ЦК - Сад"

/** Trurl's mess hall. */
/area/shuttle/stationtrauma_space/trurl/bar
	name = "ЦК - Столовая"

/** Trurl's hospital. */
/area/shuttle/stationtrauma_space/trurl/hospital
	name = "ЦК - Госпиталь"

/** Trurl's engine room, including its exterior nozzle mounts. */
/area/shuttle/stationtrauma_space/trurl/engine
	name = "ЦК - Машинный Отсек"

/** Trurl's maintenance compartments. */
/area/shuttle/stationtrauma_space/trurl/maintance
	name = "ЦК - Технические Помещения"

/** Trurl's fleet representative cabin. */
/area/shuttle/stationtrauma_space/trurl/cabin
	name = "ЦК - Каюта Представителя Флота"

/** Trurl's special operations officer cabin. */
/area/shuttle/stationtrauma_space/trurl/cabin/soo
	name = "ЦК - Каюта Офицера Специальных Операций"

/** Trurl's captain cabin. */
/area/shuttle/stationtrauma_space/trurl/cabin/captain
	name = "ЦК - Каюта Капитана Корабля"

/** Trurl's response-team cabins. */
/area/shuttle/stationtrauma_space/trurl/ert
	name = "ЦК - Каюты ОБР"

/** Trurl's special-team cabins. */
/area/shuttle/stationtrauma_space/trurl/srt
	name = "ЦК - Каюты ГСН"

/** Trurl's special-team briefing room. */
/area/shuttle/stationtrauma_space/trurl/srt/brief_srt
	name = "ЦК - Брифинг ГСН"
