import { useEffect, useRef, useState } from 'react';
import { PlanetGlyph, ShipGlyph } from './DisplayArt';
import type { NavigationData } from './types';

type Props = {
  approach: NonNullable<NavigationData['approach']>;
};

const WIDTH = 620;
const HEIGHT = 440;
const PLANET = { x: 330, y: 270, radius: 125 };
// Orbit to the planet's western limb, as plotted by the descent computer.
const APPROACH = 'M 575 45 C 340 25, 140 90, 207 252';
const BIOME_COLOURS: Record<string, string> = {
  barren: '#8b8f8c',
  frozen: '#cfe3ee',
  arid: '#c89a5f',
  lush: '#4d8a43',
  lava: '#a8442c',
};

/** Seconds into the approach, extrapolated between server updates. */
export function useApproachClock(elapsed: number, duration: number) {
  const [now, setNow] = useState(elapsed);
  useEffect(() => {
    const received = performance.now();
    let frame = requestAnimationFrame(function tick() {
      setNow(
        Math.min(duration, elapsed + (performance.now() - received) / 1000),
      );
      frame = requestAnimationFrame(tick);
    });
    return () => cancelAnimationFrame(frame);
  }, [elapsed, duration]);
  return now;
}

/** Position and heading of the hull at a fraction of a plotted path. */
export function pointOnPath(path: SVGPathElement | null, progress: number) {
  if (!path) return null;
  const length = path.getTotalLength();
  const here = path.getPointAtLength(progress * length);
  const ahead = path.getPointAtLength(Math.min(length, progress * length + 1));
  const behind = path.getPointAtLength(Math.max(0, progress * length - 1));
  return {
    x: here.x,
    y: here.y,
    angle: (Math.atan2(ahead.y - behind.y, ahead.x - behind.x) * 180) / Math.PI,
  };
}

const fraction = (seconds: number, start: number, end: number) =>
  Math.min(1, Math.max(0, (seconds - start) / Math.max(end - start, 0.001)));

export function descentPlot(approach: Props['approach'], seconds: number) {
  const timing = approach.planet_timing;
  if (approach.departing) {
    if (timing?.liftoff == null) {
      return {
        flown: 1,
        heat: 0,
        phase: 'ПОДГОТОВКА К ВЗЛЁТУ',
        countdown: false,
      };
    }
    const progress = fraction(seconds, timing.liftoff, approach.duration);
    const phase =
      timing.ascent_cloud != null && seconds < timing.ascent_cloud
        ? 'НАБОР ВЫСОТЫ'
        : timing.ascent_orbit != null && seconds < timing.ascent_orbit
          ? 'ПРОХОД АТМОСФЕРЫ'
          : progress < 1
            ? 'ВЫХОД НА ОРБИТУ'
            : 'ОРБИТА';
    return { flown: 1 - progress, heat: 0, phase, countdown: true };
  }

  const orbitDuration = timing?.orbit_duration || approach.duration;
  const orbitFraction = (time: number) => {
    const ratio = time / orbitDuration;
    const extra = Math.max(0, ratio - 1);
    return 0.22 * Math.min(1, ratio) + (0.055 * extra) / (extra + 0.3125);
  };
  if (
    timing?.descent_start == null ||
    timing.entry_start == null ||
    timing.entry_end == null
  ) {
    return {
      flown: orbitFraction(seconds),
      heat: 0,
      phase: 'СБЛИЖЕНИЕ',
      countdown: false,
    };
  }
  if (seconds < timing.entry_start) {
    const start = orbitFraction(timing.descent_start);
    const progress = fraction(
      seconds,
      timing.descent_start,
      timing.entry_start,
    );
    return {
      flown: start + (0.3 - start) * progress,
      heat: 0,
      phase: 'СХОД С ОРБИТЫ',
      countdown: true,
    };
  }
  if (seconds < timing.entry_end) {
    const progress = fraction(seconds, timing.entry_start, timing.entry_end);
    return {
      flown: 0.3 + progress * 0.37,
      heat: Math.sin(progress * Math.PI),
      phase: 'ВХОД В АТМОСФЕРУ',
      countdown: true,
    };
  }
  const progress = fraction(seconds, timing.entry_end, approach.duration);
  return {
    flown: 0.67 + progress * 0.33,
    heat: 0,
    phase: progress < 1 ? 'ЗАХОД НА ТОЧКУ ВЫСАДКИ' : 'КАСАНИЕ',
    countdown: true,
  };
}

/** Planetary plot follows the phase times published by the flight scene. */
export function Descent({ approach }: Props) {
  const path = useRef<SVGPathElement>(null);
  const seconds = useApproachClock(approach.elapsed, approach.duration);
  const { flown, heat, phase, countdown } = descentPlot(approach, seconds);
  const point = pointOnPath(path.current, flown) || {
    x: 575,
    y: 45,
    angle: 180,
  };
  const ship = approach.departing
    ? { ...point, angle: point.angle + 180 }
    : point;
  const colour = (approach.biome && BIOME_COLOURS[approach.biome]) || '#8b8f8c';
  const title = approach.departing ? 'ВЗЛЁТ' : 'ПОСАДКА';
  const left = Math.max(0, Math.ceil(approach.duration - seconds));

  return (
    <>
      <div className="SpaceNavigation__plot-head">
        <span>
          {title} · {approach.site}
        </span>
        <span>
          {phase}
          {countdown &&
            ` · T−${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`}
        </span>
      </div>
      <svg
        width={WIDTH}
        height={HEIGHT}
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="SpaceNavigation__chart SpaceNavigation__descent"
        aria-label={`${title}: ${phase}`}
      >
        <circle
          cx={PLANET.x}
          cy={PLANET.y}
          r={PLANET.radius + 9}
          fill="none"
          stroke={colour}
          strokeOpacity={0.25}
          strokeWidth={6}
        />
        <g transform={`translate(${PLANET.x} ${PLANET.y})`}>
          <PlanetGlyph
            radius={PLANET.radius}
            kind={approach.biome || 'barren'}
          />
        </g>
        <path
          ref={path}
          d={APPROACH}
          fill="none"
          stroke="#e6c78b"
          strokeDasharray="6 6"
        />
        <circle cx={207} cy={252} r={4} fill="none" stroke="#e6c78b" />
        <g
          transform={`translate(${ship.x} ${ship.y}) rotate(${ship.angle}) scale(${1 - flown * 0.4})`}
        >
          {heat > 0 && (
            <circle
              r={9 + heat * 5}
              fill="#ff9d4d"
              fillOpacity={0.15 + heat * 0.35}
            />
          )}
          <g transform="rotate(90)" style={{ color: '#c4e9d7' }}>
            <ShipGlyph />
          </g>
        </g>
      </svg>
      {!!approach.loading && (
        <p className="SpaceNavigation__help" role="status">
          Картографирование поверхности…
        </p>
      )}
    </>
  );
}
