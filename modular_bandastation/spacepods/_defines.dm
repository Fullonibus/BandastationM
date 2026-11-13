#ifndef SPACEPOD_SECURITY_LOCK_ID
#define SPACEPOD_SECURITY_LOCK_ID 100000
#endif

#ifndef SPACEPOD_ENERGY_UNIT
// Paradise high cells store 10,000 units; native high cells store 100,000 joules.
#define SPACEPOD_ENERGY_UNIT (10 JOULES)
#endif

/// Built-in life support: CO2 moles per second, fresh-air litres per second and active power draw.
#ifndef SPACEPOD_CO2_FILTER_RATE
#define SPACEPOD_CO2_FILTER_RATE 1
#endif
#ifndef SPACEPOD_CABIN_AIR_FLOW_RATE
#define SPACEPOD_CABIN_AIR_FLOW_RATE 10
#endif
#ifndef SPACEPOD_CABIN_OXYGEN_TARGET
#define SPACEPOD_CABIN_OXYGEN_TARGET 20
#endif
#ifndef SPACEPOD_LIFE_SUPPORT_POWER
#define SPACEPOD_LIFE_SUPPORT_POWER (5 WATTS)
#endif
