// Xenoarchaeology, ported from Voidcrew PR #506 (cfde23a6397c), which ported it from NovaSector and
// Polaris. Only what the current stage reads lives here; later stages add their own sections.

// ===== Bands =====
// A find's band is stamped when it is dug: the danger of the planet it came from.
#define XENOARCH_BAND_GREEN 1
#define XENOARCH_BAND_YELLOW 2
#define XENOARCH_BAND_RED 3
/// Clamps a stamped band (or null) to a valid index into the positional lists below.
#define XENOARCH_BAND_INDEX(band) clamp(band || XENOARCH_BAND_GREEN, XENOARCH_BAND_GREEN, XENOARCH_BAND_RED)

// ===== Effect tiers =====
#define ARTIFACT_TIER_COMMON 1
#define ARTIFACT_TIER_UNCOMMON 2
#define ARTIFACT_TIER_RARE 3
#define ARTIFACT_TIER_EXTREME 4

/// Main-effect tier weights for a large artifact, per band.
#define ARTIFACT_TIER_ODDS_GREEN list("1" = 62, "2" = 28, "3" = 9, "4" = 1)
#define ARTIFACT_TIER_ODDS_YELLOW list("1" = 45, "2" = 33, "3" = 18, "4" = 4)
#define ARTIFACT_TIER_ODDS_RED list("1" = 30, "2" = 34, "3" = 27, "4" = 9)

/// Chance a large artifact also carries a minor second effect.
#define ARTIFACT_SECOND_EFFECT_CHANCE 50

// ===== Effect strength =====
#define ARTIFACT_STRENGTH_SMALL "small"
#define ARTIFACT_STRENGTH_MEDIUM "medium"
#define ARTIFACT_STRENGTH_LARGE "large"
/// Strength weights per band: green leans small, red leans large.
#define ARTIFACT_STRENGTH_ODDS_GREEN list(ARTIFACT_STRENGTH_SMALL = 60, ARTIFACT_STRENGTH_MEDIUM = 30, ARTIFACT_STRENGTH_LARGE = 10)
#define ARTIFACT_STRENGTH_ODDS_YELLOW list(ARTIFACT_STRENGTH_SMALL = 35, ARTIFACT_STRENGTH_MEDIUM = 45, ARTIFACT_STRENGTH_LARGE = 20)
#define ARTIFACT_STRENGTH_ODDS_RED list(ARTIFACT_STRENGTH_SMALL = 15, ARTIFACT_STRENGTH_MEDIUM = 45, ARTIFACT_STRENGTH_LARGE = 40)

// ===== Release modes =====
#define ARTIFACT_RELEASE_TOUCH "touch"
#define ARTIFACT_RELEASE_AURA "aura"
#define ARTIFACT_RELEASE_PULSE "pulse"

// ===== Charge, per second =====
// Auras spend three times what the artifact refills, so an awake aura runs about a third of the time.
#define ARTIFACT_RECHARGE_PER_SECOND 0.5
#define ARTIFACT_AURA_COST_PER_SECOND 1.5
#define ARTIFACT_TOUCH_COST 3

// ===== Triggers =====
#define ARTIFACT_TRIGGER_TOUCH (1<<0)
#define ARTIFACT_TRIGGER_WATER (1<<1)
#define ARTIFACT_TRIGGER_ACID (1<<2)
#define ARTIFACT_TRIGGER_VOLATILE (1<<3)
#define ARTIFACT_TRIGGER_TOXIN (1<<4)
#define ARTIFACT_TRIGGER_IMPACT (1<<5)
#define ARTIFACT_TRIGGER_ENERGY (1<<6)
#define ARTIFACT_TRIGGER_HEAT (1<<7)
#define ARTIFACT_TRIGGER_COLD (1<<8)
#define ARTIFACT_TRIGGER_PLASMA (1<<9)
#define ARTIFACT_TRIGGER_CO2 (1<<10)
#define ARTIFACT_TRIGGER_PROXIMITY (1<<11)

/// Triggers read from the air on the artifact's tile every process.
#define ARTIFACT_TRIGGERS_AIR (ARTIFACT_TRIGGER_HEAT | ARTIFACT_TRIGGER_COLD | ARTIFACT_TRIGGER_PLASMA | ARTIFACT_TRIGGER_CO2)
/// Triggers held for as long as a condition lasts, rather than woken by a stimulus.
#define ARTIFACT_TRIGGERS_LEVEL (ARTIFACT_TRIGGERS_AIR | ARTIFACT_TRIGGER_PROXIMITY)

#define ARTIFACT_ALL_TRIGGERS list(\
	ARTIFACT_TRIGGER_TOUCH,\
	ARTIFACT_TRIGGER_WATER,\
	ARTIFACT_TRIGGER_ACID,\
	ARTIFACT_TRIGGER_VOLATILE,\
	ARTIFACT_TRIGGER_TOXIN,\
	ARTIFACT_TRIGGER_IMPACT,\
	ARTIFACT_TRIGGER_ENERGY,\
	ARTIFACT_TRIGGER_HEAT,\
	ARTIFACT_TRIGGER_COLD,\
	ARTIFACT_TRIGGER_PLASMA,\
	ARTIFACT_TRIGGER_CO2,\
	ARTIFACT_TRIGGER_PROXIMITY,\
)

// Trigger thresholds (Nova's values).
#define ARTIFACT_HEAT_AIR_KELVIN 375
#define ARTIFACT_HEAT_TOOL_KELVIN 700
#define ARTIFACT_COLD_AIR_KELVIN 225
#define ARTIFACT_GAS_TRIGGER_MOLES 10
#define ARTIFACT_PROXIMITY_RANGE 3
#define ARTIFACT_IMPACT_THROWFORCE 10

// Trigger families, as the analyser reports them.
#define ARTIFACT_FAMILY_CONTACT "contact"
#define ARTIFACT_FAMILY_ENERGY "energy"
#define ARTIFACT_FAMILY_AIR "air"

// ===== Waking =====
/// How long a contact stimulus keeps an effect awake; each artifact rolls once in this range.
#define ARTIFACT_WAKE_MIN (45 SECONDS)
#define ARTIFACT_WAKE_MAX (90 SECONDS)
/// How long a level trigger keeps an effect awake after its condition ends.
#define ARTIFACT_LEVEL_LINGER (6 SECONDS)
/// Hauling, bumping and repeated pats count as one touch per this long.
#define ARTIFACT_TOUCH_COOLDOWN (3 SECONDS)

// ===== Energy kinds =====
// Several effects share each kind, so the analyser narrows an artifact down without naming its effect.
#define ARTIFACT_ENERGY_CONCENTRATED "concentrated"
#define ARTIFACT_ENERGY_PSIONIC "psionic"
#define ARTIFACT_ENERGY_ELECTROMAGNETIC "electromagnetic"
#define ARTIFACT_ENERGY_PARTICLE "particle"
#define ARTIFACT_ENERGY_ORGANIC "organic"
#define ARTIFACT_ENERGY_BLUESPACE "bluespace"
#define ARTIFACT_ENERGY_SYNTHESIS "synthesis"

// ===== Labels =====
/// The second-effect field when the labeller thinks there is none. A correct "none" counts.
#define ARTIFACT_LABEL_NONE "Нет"

// ===== Scan and harvest lock =====
/// A lock nobody released frees itself after this long.
#define ARTIFACT_LOCK_TIMEOUT (2 MINUTES)

// ===== Harvesting =====
#define ARTIFACT_MAX_HARVESTS 3
/// Charge an exotic battery holds. One harvest fills one battery.
#define ARTIFACT_BATTERY_CAPACITY 200
/// Charge a core or field artefact pours into an empty battery: half of what a large find gives.
#define ARTIFACT_BATTERY_SMALL_CHARGE 100
/// Battery charge a light resonator ability costs.
#define RESONANCE_COST_LIGHT 20
/// Battery charge a heavy resonator ability costs.
#define RESONANCE_COST_HEAVY 40
/// How far a targeted resonator ability reaches, in tiles.
#define RESONANCE_REACH 7
/// Bounds of the wait between hallucination echoes of the resonance binding implant.
#define RESONANCE_ECHO_MIN (40 MINUTES)
#define RESONANCE_ECHO_MAX (80 MINUTES)
/// How long one echo makes its host hallucinate.
#define RESONANCE_ECHO_DURATION (1 MINUTES)
/// How long it takes to put a battery into a resonator or take it out.
#define RESONANCE_SWAP_TIME (3 SECONDS)
/// How long a resonator attunes to a fresh power source before it gives anything.
#define RESONANCE_ATTUNE_TIME (5 SECONDS)
/// Damage multiplier of a large find's resonator abilities.
#define RESONANCE_LARGE_POWER 1.25
/// How often a resonator worn without the binding hurts its wearer.
#define RESONANCE_PUNISH_PERIOD (30 SECONDS)
/// Resonator passive of a flyer battery, instead of its energy kind's.
#define RESONANCE_PASSIVE_FLIGHT "flight"
/// Resonator passive of a melter core battery: thermal sight.
#define RESONANCE_PASSIVE_THERMAL "thermal"

// Field protections, shared by field artefacts (anomaly_fields) and the resonator.
/// Its carrier keeps their footing: no field throws them and a gravitational field does not rip them.
#define FIELD_ARTEFACT_ANCHOR (1<<0)
/// Field throws carry its carrier much further.
#define FIELD_ARTEFACT_LIFT (1<<1)
/// Its carrier is not blinded by a flash field.
#define FIELD_ARTEFACT_BLINDPROOF (1<<2)
/// Charge per second a harvester draws on tier-1 capacitors: a full battery in 80 seconds.
#define ARTIFACT_HARVEST_DRAW_RATE 2.5
/// Charge per second a utilizer spends running a field or bursts: a full battery lasts 400 seconds.
#define ARTIFACT_UTILIZER_DRAIN 0.5
/// Charge per second a utilizer feeds a burst effect's store, twice what an artifact refills.
#define ARTIFACT_UTILIZER_PULSE_FEED 1
/// Charge one contact use costs: ten from a full battery.
#define ARTIFACT_UTILIZER_TOUCH_COST 20

/// do_after key for every xenoarchaeology action, so one person works one thing at a time.
#define DOAFTER_SOURCE_XENOARCH "doafter_xenoarch"

// ===== Dig sites =====
#define XENOARCH_SITES_PER_PLANET 3
/// Large and small finds per site, by band (green, yellow, red).
#define XENOARCH_LARGE_PER_SITE list(1, 1, 2)
#define XENOARCH_SMALL_PER_SITE list(3, 3, 2)
/// Small-find tier odds per band: tier 1, 2, 3.
#define XENOARCH_SMALL_TIER_ODDS_GREEN list("1" = 60, "2" = 32, "3" = 8)
#define XENOARCH_SMALL_TIER_ODDS_YELLOW list("1" = 50, "2" = 37, "3" = 13)
#define XENOARCH_SMALL_TIER_ODDS_RED list("1" = 40, "2" = 40, "3" = 20)
/// Chance that uncovering a large find wakes local fauna, by band.
#define XENOARCH_AMBUSH_CHANCE list(0, 25, 45)
/// Minimum tiles between two dig sites.
#define XENOARCH_SITE_SPACING 20

/// What a site wall gives up when it is mined.
#define XENOARCH_FIND_LARGE 1
#define XENOARCH_FIND_SMALL 2

/// Dig site kinds (Bay's), which set the small finds a site holds.
#define XENOARCH_SITE_GARDEN "garden"
#define XENOARCH_SITE_ANIMAL "animal"
#define XENOARCH_SITE_HOUSE "house"
#define XENOARCH_SITE_TECHNICAL "technical"
#define XENOARCH_SITE_TEMPLE "temple"
#define XENOARCH_SITE_WAR "war"

/// Large find shares, in percent, out of what a boulder holds. The rest is an alien artifact.
#define XENOARCH_FIND_SHARE_FORMATION 6
#define XENOARCH_FIND_SHARE_CRYSTAL 4
#define XENOARCH_FIND_SHARE_CASE 2
/// Combat exosuit wrecks: red sites only, taken out of the artifact share. About one a round.
#define XENOARCH_FIND_SHARE_EXOSUIT_RED 1

/// A boulder's find sits this deep, in cm.
#define XENOARCH_BOULDER_DEPTH_MIN 25
#define XENOARCH_BOULDER_DEPTH_MAX 200
/// The plain depth scanner reads a boulder to within this many cm (a strange rock to a third of it).
#define XENOARCH_SCAN_ERROR 15
/// Hammering costs this long per cm the head takes off.
#define XENOARCH_HAMMER_TIME_PER_CM (0.5 SECONDS)
/// One pass of the brush.
#define XENOARCH_BRUSH_TIME (3 SECONDS)
#define XENOARCH_BRUSH_TIME_QUICK (1 SECONDS)
/// A pick or drill takes this much off a boulder per swing, roughly.
#define XENOARCH_PICK_CUT_MIN 18
#define XENOARCH_PICK_CUT_MAX 30
/// Chance an unstabilised large find comes apart as it is freed. The rest come out damaged.
#define XENOARCH_UNSTABLE_CRUMBLE_CHANCE 50

/// Strange rocks: the find sits 6 to 14 cm deep, plus this much per tier.
#define XENOARCH_ROCK_DEPTH_PER_TIER 8

/// Curio classes, as buyers price them (design: shell 40, fossil 50, pottery 80,
/// statuette or instrument 150 cr).
#define XENOARCH_CURIO_SHELL "shell"
#define XENOARCH_CURIO_FOSSIL "fossil"
#define XENOARCH_CURIO_POTTERY "pottery"
#define XENOARCH_CURIO_STATUETTE "statuette"
#define XENOARCH_CURIO_INSTRUMENT "instrument"

/// Charged crystal: what it puts on the wire and for how long in all before it goes dull.
#define XENOARCH_CRYSTAL_POWER (15 KILO WATTS)
#define XENOARCH_CRYSTAL_LIFETIME (90 MINUTES)

// ===== Signals, sent on the artifact =====
/// An effect woke: (datum/artifact_effect/effect)
#define COMSIG_ARTIFACT_EFFECT_ACTIVATED "artifact_effect_activated"
/// An effect went dormant: (datum/artifact_effect/effect)
#define COMSIG_ARTIFACT_EFFECT_DEACTIVATED "artifact_effect_deactivated"
/// A stimulus reached the artifact, whether or not anything woke: (trigger, mob/living/user, woke)
#define COMSIG_ARTIFACT_STIMULATED "artifact_stimulated"
/// A label was stuck on or scraped off: (datum/artifact_label/label_or_null, mob/user)
#define COMSIG_ARTIFACT_LABEL_CHANGED "artifact_label_changed"
/// The artifact was stamped as dug: (band)
#define COMSIG_ARTIFACT_STAMPED "artifact_stamped"
/// One harvest was taken from it: (datum/artifact_effect/effect, mob/user)
#define COMSIG_ARTIFACT_HARVESTED "artifact_harvested"
