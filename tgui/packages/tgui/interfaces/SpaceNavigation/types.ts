import type { BooleanLike } from 'tgui-core/react';

export type Position = { x: number; y: number };
export type Site = Position & {
  id: string;
  name: string;
  kind: string;
  type: string;
  distance: number;
  failed: BooleanLike;
  /** A distress beacon transmits there. */
  sos?: BooleanLike;
};
export type Contact = Position & {
  id: number;
  age: number;
  mode: string;
  vx?: number;
  vy?: number;
  identity?: { callsign: string; faction: string };
};
export type CelestialBody = Position & {
  name: string;
  radius: number;
  kind: string;
  orbit_x: number;
  orbit_y: number;
};
export type FuelGauge = {
  name: string;
  /** Moles in the connected supply network. */
  amount: number;
  /** Standard fill of the connected canisters of this gas, moles; 0 without a canister. */
  capacity: number;
};
/** Share of the connected canisters' standard fill, 0 to 1; 0 without a canister. */
export function fuelShare(gauge: FuelGauge) {
  return gauge.capacity > 0 ? Math.min(1, gauge.amount / gauge.capacity) : 0;
}

/** Below a fifth of the standard fill, or nothing connected at all. */
export function fuelLow(gauge: FuelGauge) {
  return fuelShare(gauge) < 0.2;
}

export type Compartment = {
  name: string;
  /** Mean floor pressure in the compartment, kPa; null without open floor. */
  pressure: number | null;
  low_pressure: BooleanLike;
  fire: BooleanLike;
  /** Hull tiles open to space. */
  breaches: number;
};
export type NavigationData = Position & {
  board?: {
    jumps: { id: string; name: string; available: BooleanLike }[];
    transponder: { callsign: string | null; enabled: BooleanLike } | null;
  };
  vessel_name?: string;
  au_scale: number;
  status: string;
  sector: string;
  sector_name: string;
  jumping: BooleanLike;
  star: Position & { name: string | null; radius: number };
  celestial_bodies: CelestialBody[];
  vx: number;
  vy: number;
  trajectory: (Position & { seconds: number })[];
  course: number;
  ordered_course: number;
  speed: number;
  /** Full scale of the speedometer, shared by every hull. */
  speed_scale: number;
  throttle: number;
  maneuver_direction: number;
  braking: BooleanLike;
  braking_distance: number | null;
  /** Powered emergency manoeuvring thrusters are braking. */
  emergency_braking: BooleanLike;
  /** Any compartment has equipment power. */
  ship_power: BooleanLike;
  engines: number;
  engines_running: BooleanLike;
  core_overdrive: BooleanLike;
  afterburner: BooleanLike;
  can_afterburner: BooleanLike;
  core_heat: number | null;
  fuel: FuelGauge[] | null;
  engine_fault: BooleanLike;
  can_start_engines: BooleanLike;
  helm: BooleanLike;
  autopilot: BooleanLike;
  preparing: BooleanLike;
  planning: BooleanLike;
  relocating: BooleanLike;
  landed: BooleanLike;
  selected: string | null;
  docked: string | null;
  coupled: BooleanLike;
  docking_request: { token: number; contact: number | null } | null;
  station_docking?: {
    required: BooleanLike;
    state: 'none' | 'pending' | 'approved';
    canRequest: BooleanLike;
    canCancel: BooleanLike;
    expiresIn: number | null;
  };
  can_request_ship_dock: BooleanLike;
  dockable_contacts: number[];
  landing: BooleanLike;
  distance: number;
  eta: number | null;
  scan_ready: BooleanLike;
  /** Seconds since the last sensor pulse, or null before the first one. */
  scan_age: number | null;
  /** Sensor noise from 0 to 1, as near the star. */
  interference: number;
  sensor_range: number;
  can_dock: BooleanLike;
  routes: Site[];
  path: [number, number][];
  zones: (Position & {
    name: string;
    kind: string;
    radius: number;
    direction: number;
  })[];
  terrain: (Position & { end_x: number; end_y: number })[];
  ship_contacts: Contact[];
  planet?: {
    biome: string;
    atmosphere: string;
    temperature: number;
    breathable: BooleanLike;
    modifiers: string[];
  };
  approach: {
    elapsed: number;
    duration: number;
    departing: BooleanLike;
    site: string;
    scene: 'planet' | 'ruin' | 'cargo' | 'asteroids';
    biome: string | null;
    loading: BooleanLike;
  } | null;
  compartments: Compartment[];
  /** Hull silhouette rows, north first: space outside, `#` wall, `!` breach, otherwise the compartment code. */
  hull: string[];
};

export function compartmentDamaged(room: Compartment) {
  return !!(room.breaches || room.fire || room.low_pressure);
}

/** Seconds of unchanged motion represented by a velocity vector. */
export const VECTOR_SECONDS = 60;

/**
 * Closest point of approach from the sensor fix, dead-reckoned to now.
 * Uses only the observed contact track, so a stale fix gives a stale forecast.
 */
export function closestApproach(own: NavigationData, contact: Contact) {
  if (contact.vx === undefined || contact.vy === undefined) return null;
  const rx = contact.x + contact.vx * contact.age - own.x;
  const ry = contact.y + contact.vy * contact.age - own.y;
  const vx = contact.vx - own.vx;
  const vy = contact.vy - own.vy;
  const closing = vx * vx + vy * vy;
  // Matched velocities keep the current separation; past CPA means opening.
  const time = closing < 1e-6 ? 0 : Math.max(0, -(rx * vx + ry * vy) / closing);
  return { distance: Math.hypot(rx + vx * time, ry + vy * time), time };
}

export function distanceLabel(value: number, scale: number) {
  return `${(value * scale).toFixed(Math.abs(value) >= 10 ? 3 : 5)} а.е.`;
}

export function speedLabel(value: number, scale: number) {
  const kilometres = Math.abs(value) * scale * 149597870.7;
  const lightSpeed = kilometres / 299792.458;
  return lightSpeed >= 0.01
    ? `${lightSpeed.toFixed(2)} c`
    : `${Math.round(kilometres)} км/с`;
}
