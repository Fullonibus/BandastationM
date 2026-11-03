#ifndef PHOENIX_DEFINES
#define PHOENIX_DEFINES

/// Environmental suitability levels, ordered from dangerous to reproductive.
#define PHOENIX_DANGER 0
#define PHOENIX_SURVIVAL 1
#define PHOENIX_BREEDING 2
/// Developmental stages of an amber weaver.
#define PHOENIX_LARVA 1
#define PHOENIX_COCOON 2
#define PHOENIX_ADULT 3
/// Source used only by Phoenix preservation capsules.
#define PHOENIX_STASIS_SOURCE "phoenix_capsule"
/// Biology durations are expressed in seconds, matching Life's delta time.
#define PHOENIX_EGG_SECONDS 90
#define PHOENIX_LARVA_SECONDS 120
#define PHOENIX_COCOON_SECONDS 60
#define PHOENIX_BREED_SECONDS 180
#define PHOENIX_FIBER_SECONDS 60
#define PHOENIX_ENVIRONMENT_SECONDS 10
/// Maximum stored nutrition, shared by biology and clinical observations.
#define PHOENIX_NUTRITION_MAX 100
/// Capsule treatment restores a full health budget over three minutes, using existing trauma medicine.
#define PHOENIX_TREATMENT_SECONDS 180
#define PHOENIX_MEDICINE_TYPE /datum/reagent/medicine/c2/libital
#define PHOENIX_MEDICINE_CAPACITY 60
#define PHOENIX_MEDICINE_PER_HEALTH 0.25
/// Limits keep a station project finite and preserve the need for a habitat.
#define PHOENIX_MAX_POPULATION 12
#define PHOENIX_MAX_ADAPTATIONS 2
#define PHOENIX_FIBER_TARGET 30
#define PHOENIX_DESCENDANT_TARGET 3
#define PHOENIX_ADAPTATION_COST 120

#endif
