// Barren environment profile adapted from SierraBay, AGPL-3.0; terrain generation uses local TG/rust-g.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/barren.dm
// Biome selection, tables and densities adapted from CeladonSS13/Shiptest, AGPL-3.0; contents use local TG types.
// https://github.com/CeladonSS13/Shiptest/tree/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary
/** Celadon lunar plains: bare airless regolith. */
/datum/biome/expedition/lunar
	open_turf_type = /turf/open/misc/asteroid/airless
	fauna_density = 1.5
	fauna_types = list(/mob/living/basic/carp = 2)

/** Celadon coarse lunar ground: airless basalt fields. */
/datum/biome/expedition/lunar/rocky
	open_turf_type = /turf/open/misc/asteroid/basalt/airless

/** Finite research source: кристаллический нарост экзопланеты, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_barren
	name = "кристаллический нарост экзопланеты"
	desc = "Минеральные включения на безвоздушной поверхности. Их можно обследовать и отобрать пробы."
	field_notes = "В трещинах породы видны неоднородные кристаллические включения с острыми гранями. Следов растительности нет."
	laboratory_notes = "Включения образуют несколько минеральных фракций. Состав и возможное применение требуют дальнейших испытаний."
