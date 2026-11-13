/// Astronomical units per sector unit, for crew-facing distances.
#define ST_SPACE_AU_SCALE 0.001
/// Duration of a bluespace jump between sectors.
#define ST_SPACE_JUMP_TIME (4 MINUTES)
/// Percent chance that a space ruin holds a fuel cache.
#define ST_FUEL_CACHE_SPACE_CHANCE 35
/// Percent chance that a planet ruin holds a fuel cache; planets already offer ore and supply crates.
#define ST_FUEL_CACHE_PLANET_CHANCE 25
/// Flight of a called ship to its station berth.
#define ST_SPACE_DISPATCH_TIME (2 MINUTES)
/// Parallax loop speed multiplier through bluespace flight.
#define ST_SPACE_JUMP_PARALLAX_RUSH 8
/// Reach of the star's corona from the system centre, in virtual sector units; the nearest rolled objects lie past 500.
#define ST_STAR_CORONA_RADIUS 350
/// Interval between corona effects on a hull inside it.
#define ST_STAR_HEAT_INTERVAL (4 SECONDS)
/// Bluespace jumps one anomaly core charges.
#define ST_BLUESPACE_CORE_JUMPS 2
/// Jumps a bluespace drive can hold.
#define ST_BLUESPACE_DRIVE_CAPACITY 4
/// Highest relative speed at which two hulls may dock.
#define ST_SPACE_DOCK_SPEED 0.5
/// How long a ship-to-ship docking request waits for an answer.
#define ST_SPACE_DOCK_REQUEST_TIME (30 SECONDS)
/// Planetary descent duration; a first landing generates the surface meanwhile.
#define ST_SPACE_LANDING_TIME (2 MINUTES)
/// Approach to a space destination before its seam is built; a first visit loads the destination meanwhile.
#define ST_SPACE_APPROACH_TIME (45 SECONDS)
/// Planetary ascent, mostly flown on the ship's flight level.
#define ST_SPACE_TAKEOFF_TIME (1 MINUTES)
/// Brief preparation at the old berth before casting off into flight space.
#define ST_SPACE_DEPARTURE_DELAY (5 SECONDS)
/// Mooring or casting off at a physical berth or another hull.
#define ST_SPACE_MOORING_TIME (20 SECONDS)
/// Losses overboard from one hull within this time share an open-space level.
#define ST_LOST_SHARED_TIME (1 MINUTES)
/// Chart distance within which a loss overboard drifts towards a charted object, in virtual sector units.
#define ST_LOST_WRECK_RANGE 150
/// Rescue berth distance from the open-space level border; the seam needs clearance from the transition edge.
#define ST_LOST_BERTH_MARGIN 45
/// Part of the departure preparation reserved for closing and folding gangways.
#define ST_STANDARD_DOCK_RETRACTION_LEAD (4 SECONDS)
/// Width of a standard S slot in tiles.
#define ST_STANDARD_S_WIDTH 7
/// Length of a standard S slot in tiles.
#define ST_STANDARD_S_HEIGHT 15
/// Width of a standard M slot in tiles.
#define ST_STANDARD_M_WIDTH 19
/// Length of a standard M slot in tiles.
#define ST_STANDARD_M_HEIGHT 25
/// Engine sound levels glide this much of their full range per second.
#define ST_ENGINE_SOUND_GLIDE 0.8
/// Smallest engine sound level change worth sending to listeners.
#define ST_ENGINE_SOUND_STEP 0.04
/// Sent by an area when its space parallax background changes: ().
#define COMSIG_AREA_SPACE_PARALLAX_CHANGED "area_space_parallax_changed"
/// Hot-gas temperature giving full nozzle power.
#define SHIP_ENGINE_OPERATING_TEMPERATURE 1000
/// Extra share of nominal nozzle power while the fusion core runs in overdrive.
#define SHIP_AFTERBURNER_THRUST 0.5
/// Tritium the fusion core burns per second at full output, in moles; a standard canister lasts about half an hour.
#define ST_CORE_FUEL_RATE 1
/// Hot helium the fusion core gives per mole of tritium; full output covers Raven's converters at full thrust.
#define ST_CORE_HELIUM_YIELD 4.5
/// Temperature of the helium leaving the fusion core.
#define ST_CORE_EXHAUST_TEMPERATURE 3000
/// Outlet line pressure above which the fusion core stops adding helium, in kPa.
#define ST_CORE_EXHAUST_PRESSURE 1000
/// Electric power the fusion core feeds into its grid at full output.
#define ST_CORE_POWER (600 KILO WATTS)
/// Output multiplier of the fusion core's overdrive.
#define ST_CORE_OVERDRIVE_OUTPUT 1.5
/// Fuel multiplier of the fusion core's overdrive.
#define ST_CORE_OVERDRIVE_FUEL 2
/// Seconds of overdrive from a cold core to its heat trip; cooling takes twice as long.
#define ST_CORE_OVERDRIVE_ENDURANCE 60
/// Neutron reach of the fusion core at full output, in tiles; a common wall stops it.
#define ST_CORE_RADIATION_RANGE 3
/// Time near a running core before its neutrons irradiate someone.
#define ST_CORE_RADIATION_EXPOSURE (5 SECONDS)
/// Highest manual output setting of the fusion core, in percent; above 100 is overload.
#define ST_CORE_MAX_LEVEL 150
/// Lowest output the fusion core's automatic mode keeps to hold the reaction, in percent.
#define ST_CORE_IDLE_LEVEL 10
/// Core heat per second for each full nominal output of overload, in percent; 150 % reaches the interlock in about three minutes.
#define ST_CORE_OVERLOAD_HEATING 1.1
/// Core heat required for an unprotected rupture after the warning grace period, in percent.
#define ST_CORE_MELTDOWN_HEAT 200
/// Minimum real time to respond to an unprotected overheating warning before critical heat can rupture the core.
#define ST_CORE_MELTDOWN_DELAY (60 SECONDS)
/// Waste heat the fusion core releases into its room per nominal output of overload, and per full heat at half that rate.
#define ST_CORE_WASTE_HEAT (40 KILO WATTS)
/// Engine power per hull tile that gives the reference speed and acceleration.
#define ST_SPACE_REFERENCE_THRUST 0.03
/// Top speed of a hull at the reference thrust ratio.
#define ST_SPACE_REFERENCE_SPEED 5
/// Absolute top speed; also the full scale of the helm speedometer.
#define ST_SPACE_MAX_SPEED 8
/// Hull tiles of a ship turning at the base turn rate; lighter hulls turn faster.
#define ST_SPACE_REFERENCE_MASS 250
/// Constant slight deceleration of every hull per second, so a dead ship does not drift forever.
#define ST_SPACE_DRAG 0.01
/// Powered emergency manoeuvring thrusters: a tenth of a full main-engine brake, per second.
#define ST_SPACE_RCS_DECELERATION (5 / 150)

/** Registers the space overmap module and its compile-time dependencies. */
/datum/modpack/space_overmap
	name = "Space Overmap StationTrauma"
	desc = "Космические рейсы, межзвёздные переходы и экспедиционные локации."
	author = "junkky"
