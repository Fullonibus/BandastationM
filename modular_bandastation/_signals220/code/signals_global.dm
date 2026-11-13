// Expedition science events, sent through SSdcs so that orders can follow them without coupling the modules.

/// An expedition specimen source got its first field survey: (datum/stationtrauma_research_record/record, mob/living/user, atom/location)
#define COMSIG_GLOB_EXPEDITION_SOURCE_SURVEYED "!expedition_source_surveyed"
/// An expedition specimen finished its laboratory analysis: (datum/stationtrauma_research_record/record, mob/living/user, atom/location)
#define COMSIG_GLOB_EXPEDITION_SAMPLE_ANALYZED "!expedition_sample_analyzed"
/// A find came out where it was found: a large find freed from its boulder, a field artefact taken from its field, a core left by a neutralized anomaly: (atom/movable/find, mob/user, atom/location)
#define COMSIG_GLOB_EXPEDITION_FIND_RECOVERED "!expedition_find_recovered"
/// A find was catalogued for the first time: a large find analysed in full, or a small find, field artefact or core on the scan pad: (atom/movable/find, mob/user, atom/location)
#define COMSIG_GLOB_EXPEDITION_FIND_CATALOGUED "!expedition_find_catalogued"
/// A core sampler drew a core from a boulder: (obj/item/excavation/core_sampler/sampler, mob/user, atom/location)
#define COMSIG_GLOB_EXPEDITION_CORE_TAKEN "!expedition_core_taken"
/// The spectrometer finished reading the core in a sampler: (obj/item/excavation/core_sampler/sampler, mob/user, atom/location)
#define COMSIG_GLOB_EXPEDITION_CORE_READ "!expedition_core_read"
/// A charted destination finished loading its map on the first approach: (datum/stationtrauma_overmap_site/space/site)
#define COMSIG_GLOB_EXPEDITION_SITE_LOADED "!expedition_site_loaded"
