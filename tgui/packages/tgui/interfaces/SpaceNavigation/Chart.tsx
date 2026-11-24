import { useEffect, useRef, useState } from 'react';
import { Button } from 'tgui-core/components';

import { useApproachClock } from './Descent';
import {
  PlanetGlyph,
  ShipGlyph,
  StationGlyph,
  SunGlyph,
  ZoneArt,
} from './DisplayArt';
import {
  distanceLabel,
  type NavigationData,
  type Position,
  VECTOR_SECONDS,
} from './types';

/** Seconds a sensor pulse takes to spread from the hull to the edge of sensor range. */
const SCAN_WAVE = 1.5;
/** Seconds a distress signal keeps pulsing on the chart after a sensor pulse finds it. */
const SOS_PULSE = 10;

/** Sensor pulse ring: spreads from the hull, slowing towards the edge of sensor range, and fades out. */
function ScanWave(props: {
  age: number;
  x: number;
  y: number;
  radius: number;
}) {
  const { age, x, y, radius } = props;
  const seconds = useApproachClock(age, SCAN_WAVE);
  if (seconds >= SCAN_WAVE) return null;
  const progress = seconds / SCAN_WAVE;
  return (
    <circle
      cx={x}
      cy={y}
      r={radius * (1 - (1 - progress) ** 2)}
      fill="none"
      stroke="#82de89"
      strokeWidth={2}
      strokeOpacity={1 - progress}
      pointerEvents="none"
    />
  );
}

type Props = {
  data: NavigationData;
  zoom: number;
  hoveredTarget: string | null;
  focusedContact: number | null;
  onContact: (id: number) => void;
  onSite: (id: string) => void;
};

export function Chart({
  data,
  focusedContact,
  onContact,
  onSite,
  zoom,
  hoveredTarget,
}: Props) {
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const drag = useRef<Position | null>(null);
  const svg = useRef<SVGSVGElement>(null);
  const scale = 0.16 * zoom;
  const width = 620;
  const height = 440;
  const centre = { x: data.x + pan.x, y: data.y + pan.y };
  const point = (x: number, y: number) => ({
    x: width / 2 + (x - centre.x) * scale,
    y: height / 2 - (y - centre.y) * scale,
  });
  const own = point(data.x, data.y);
  const disabled = !!(data.preparing || data.relocating);

  useEffect(() => {
    const release = () => {
      drag.current = null;
    };
    const move = (event: MouseEvent) => {
      if (!drag.current || !svg.current) return;
      const matrix = svg.current.getScreenCTM();
      if (!matrix?.a || !matrix.d) return;
      const dx = (event.clientX - drag.current.x) / matrix.a;
      const dy = (event.clientY - drag.current.y) / matrix.d;
      drag.current = { x: event.clientX, y: event.clientY };
      setPan((prior) => ({ x: prior.x - dx / scale, y: prior.y + dy / scale }));
    };
    document.addEventListener('mousemove', move);
    document.addEventListener('mouseup', release);
    document.addEventListener('visibilitychange', release);
    window.addEventListener('blur', release);
    return () => {
      document.removeEventListener('mousemove', move);
      document.removeEventListener('mouseup', release);
      document.removeEventListener('visibilitychange', release);
      window.removeEventListener('blur', release);
    };
  }, [scale]);

  const grid: number[] = [];
  for (
    let x = Math.floor((centre.x - width / 2 / scale) / 250) * 250;
    x <= centre.x + width / 2 / scale;
    x += 250
  )
    grid.push(x);
  const rows: number[] = [];
  for (
    let y = Math.floor((centre.y - height / 2 / scale) / 250) * 250;
    y <= centre.y + height / 2 / scale;
    y += 250
  )
    rows.push(y);
  const bodies = data.celestial_bodies || [];

  return (
    <div className="SpaceNavigation__chart-stage">
      <div className="SpaceNavigation__map-controls">
        {' '}
        <Button
          compact
          icon="crosshairs"
          tooltip="Центрировать на корабле"
          aria-label="Центрировать на корабле"
          onClick={() => setPan({ x: 0, y: 0 })}
        />
      </div>
      <svg
        ref={svg}
        width={width}
        height={height}
        viewBox={`0 0 ${width} ${height}`}
        className="SpaceNavigation__chart"
        aria-label="Карта контактов. Выбор левой кнопкой, перемещение правой."
        onContextMenu={(event) => event.preventDefault()}
        onMouseDown={(event) => {
          if (event.button !== 2) return;
          event.preventDefault();
          drag.current = { x: event.clientX, y: event.clientY };
        }}
      >
        <defs>
          <marker
            id="velocity-arrow"
            viewBox="0 0 10 10"
            refX="8"
            refY="5"
            markerWidth="7"
            markerHeight="7"
            orient="auto"
          >
            <path d="M0 1L8 5L0 9" fill="none" stroke="#91d7d0" />
          </marker>
          <filter id="sensor-noise">
            <feTurbulence
              type="fractalNoise"
              baseFrequency="0.9"
              seed={Math.floor(Math.random() * 1000)}
            />
            <feColorMatrix values="0 0 0 0 0.85 0 0 0 0 0.9 0 0 0 0 0.75 0 0 0 1.4 -0.6" />
          </filter>
        </defs>
        <g stroke="#233936" strokeOpacity=".65">
          {grid.map((x) => (
            <line
              key={x}
              x1={point(x, 0).x}
              x2={point(x, 0).x}
              y1={0}
              y2={height}
            />
          ))}
          {rows.map((y) => (
            <line
              key={y}
              y1={point(0, y).y}
              y2={point(0, y).y}
              x1={0}
              x2={width}
            />
          ))}
        </g>
        <g
          fill="none"
          stroke="#64796b"
          strokeOpacity=".4"
          strokeDasharray="3 3"
        >
          {bodies.map((body) => (
            <circle
              key={body.name}
              cx={point(body.orbit_x, body.orbit_y).x}
              cy={point(body.orbit_x, body.orbit_y).y}
              r={
                Math.hypot(body.x - body.orbit_x, body.y - body.orbit_y) * scale
              }
            />
          ))}
          {data.routes
            .filter((site) => site.kind === 'planet')
            .map((site) => (
              <circle
                key={site.id}
                cx={point(0, 0).x}
                cy={point(0, 0).y}
                r={Math.hypot(site.x, site.y) * scale}
              />
            ))}
          {bodies.length > 0 &&
            data.routes
              .filter((site) => site.kind === 'station')
              .map((site) => (
                <circle
                  key={site.id}
                  cx={point(bodies[0].x, bodies[0].y).x}
                  cy={point(bodies[0].x, bodies[0].y).y}
                  r={
                    Math.hypot(site.x - bodies[0].x, site.y - bodies[0].y) *
                    scale
                  }
                />
              ))}
        </g>
        {bodies
          .filter(
            (body) =>
              !data.routes.some(
                (site) =>
                  site.kind === 'planet' &&
                  Math.hypot(site.x - body.x, site.y - body.y) < 1,
              ),
          )
          .map((body) => (
            <g
              key={body.name}
              transform={`translate(${point(body.x, body.y).x} ${point(body.x, body.y).y})`}
            >
              <title>{body.name}</title>
              <PlanetGlyph
                radius={Math.max(16, body.radius)}
                kind={body.kind}
              />
            </g>
          ))}
        {data.zones.map((zone, index) => (
          <g
            className="SpaceNavigation__map-feature"
            key={index}
            transform={`translate(${point(zone.x, zone.y).x} ${point(zone.x, zone.y).y})`}
          >
            <circle r={zone.radius * scale} fill="transparent" stroke="none" />
            <title>
              {zone.kind === 'meteors' ? 'Метеоритный поток' : zone.name}
            </title>
            <ZoneArt
              kind={zone.kind}
              radius={zone.radius * scale}
              direction={zone.direction}
            />
            <text
              className="nav-feature-label nav-chart-label nav-chart-label--muted"
              x={zone.radius * scale * 0.8 + 7}
              y="0"
              pointerEvents="none"
            >
              {zone.kind === 'meteors' ? 'Метеоритный поток' : zone.name}
            </text>
          </g>
        ))}
        {data.star && (
          <g
            transform={`translate(${point(data.star.x, data.star.y).x} ${point(data.star.x, data.star.y).y})`}
            className="SpaceNavigation__map-feature"
          >
            <circle
              r={data.star.radius * 1.8}
              fill="transparent"
              stroke="none"
            />
            <SunGlyph radius={data.star.radius} />
            <text
              className="nav-feature-label nav-chart-label"
              x={-data.star.radius - 8}
              y={-data.star.radius - 5}
              textAnchor="end"
            >
              {data.star.name}
            </text>
          </g>
        )}
        <g stroke="#bdad80" strokeWidth={0.65}>
          {data.terrain.map((rock, index) => (
            <line
              key={index}
              x1={point(rock.x, rock.y).x}
              y1={point(rock.x, rock.y).y}
              x2={point(rock.end_x, rock.end_y).x}
              y2={point(rock.end_x, rock.end_y).y}
            />
          ))}
        </g>
        {data.path?.length > 0 && (
          <polyline
            fill="none"
            stroke="#a48e65"
            points={[own, ...data.path.map(([x, y]) => point(x, y))]
              .map((p) => `${p.x},${p.y}`)
              .join(' ')}
          />
        )}
        {data.routes.map((site, siteIndex) => {
          const p = point(site.x, site.y);
          const selected = focusedContact === null && site.id === data.selected;
          return (
            <g
              key={site.id}
              transform={`translate(${p.x} ${p.y})`}
              className={`SpaceNavigation__marker ${selected ? 'is-selected' : ''} ${hoveredTarget === `site:${site.id}` ? 'is-hovered' : ''}`}
              role="button"
              tabIndex={0}
              aria-label={site.name}
              aria-disabled={disabled || !!site.failed}
              onClick={() => !disabled && !site.failed && onSite(site.id)}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !disabled && !site.failed)
                  onSite(site.id);
              }}
              stroke={selected ? '#edc587' : site.sos ? '#e0533f' : '#7b9c86'}
            >
              <title>{site.name}</title>
              <circle
                className="nav-marker-focus"
                r={site.kind === 'planet' ? 33 : 15}
                pointerEvents="none"
              />
              <circle
                r={site.kind === 'planet' ? 31 : 18}
                fill="transparent"
                stroke="none"
              />
              <g
                style={{
                  color: selected ? '#e7c689' : '#9cc8b7',
                }}
              >
                {site.kind === 'planet' ? (
                  <PlanetGlyph
                    radius={selected ? 25 : 17}
                    kind={
                      bodies.find(
                        (body) =>
                          Math.hypot(body.x - site.x, body.y - site.y) < 1,
                      )?.kind || 'barren'
                    }
                  />
                ) : site.kind === 'station' ? (
                  <StationGlyph />
                ) : (
                  <g>
                    <path d="M0-8L8 0L0 8L-8 0Z" fill="#10221d" />
                    <path d="M-3 0H3M0-3V3" strokeWidth="1" />
                  </g>
                )}
              </g>
              <g
                className="nav-object-label"
                pointerEvents="none"
                fill="none"
                strokeWidth=".6"
                strokeOpacity=".55"
              >
                <path
                  d={`M${site.kind === 'planet' ? 27 : 13} -4l11-${siteIndex % 2 ? 13 : 25}h50`}
                />
              </g>
              <text
                className={`nav-object-label nav-chart-label ${selected ? 'nav-chart-label--selected' : ''}`}
                x={site.kind === 'planet' ? 39 : 25}
                y={siteIndex % 2 ? -20 : -32}
                pointerEvents="none"
              >
                {site.kind === 'signal' && !site.sos ? site.type : site.name}
              </text>
              {!!site.sos &&
                data.scan_age !== null &&
                data.scan_age < SOS_PULSE && (
                  <circle
                    r={9}
                    fill="none"
                    stroke="#e0533f"
                    className="SpaceNavigation__sos"
                  />
                )}
            </g>
          );
        })}
        {data.ship_contacts.map((contact) => {
          const p = point(contact.x, contact.y);
          return (
            <g
              key={contact.id}
              className={`SpaceNavigation__marker ${contact.id === focusedContact ? 'is-selected' : ''} ${hoveredTarget === `contact:${contact.id}` ? 'is-hovered' : ''}`}
              role="button"
              tabIndex={0}
              aria-label={`Контакт ${contact.id}`}
              onClick={() => onContact(contact.id)}
              onKeyDown={(event) =>
                event.key === 'Enter' && onContact(contact.id)
              }
            >
              <title>{`К${contact.id} · ${contact.identity?.callsign || 'Неопознанное судно'} · ${Math.floor(contact.age)} с`}</title>
              <circle cx={p.x} cy={p.y} r={13} fill="transparent" />
              <circle
                className="nav-marker-focus"
                cx={p.x}
                cy={p.y}
                r="10"
                pointerEvents="none"
              />
              <circle
                cx={p.x}
                cy={p.y}
                r={5}
                fill="none"
                stroke={
                  contact.id === focusedContact
                    ? '#edc587'
                    : contact.age >= 20
                      ? '#6e7664'
                      : '#d2a46a'
                }
              />
              <text
                className="nav-object-label nav-chart-label nav-chart-label--contact"
                x={p.x + 12}
                y={p.y + 4}
                pointerEvents="none"
              >
                К{contact.id}
                {contact.identity ? ` / ${contact.identity.callsign}` : ' / ?'}
              </text>
              {contact.id === focusedContact &&
                contact.vx !== undefined &&
                contact.vy !== undefined && (
                  <Velocity
                    origin={p}
                    vx={contact.vx}
                    vy={contact.vy}
                    scale={scale}
                  />
                )}
            </g>
          );
        })}
        {data.scan_age !== null && data.scan_age < SCAN_WAVE && (
          <ScanWave
            age={data.scan_age}
            x={own.x}
            y={own.y}
            radius={data.sensor_range * scale}
          />
        )}
        {data.trajectory.map(({ x, y, seconds }, index) => {
          const previous = index ? data.trajectory[index - 1] : data;
          const dx = x - previous.x,
            dy = y - previous.y;
          const angle =
            dx || dy ? (Math.atan2(dx, dy) * 180) / Math.PI : data.course;
          const position = point(x, y);
          return (
            <path
              key={seconds}
              className="nav-prediction"
              d="M0-5L3.5 3L0 1L-3.5 3Z"
              transform={`translate(${position.x} ${position.y}) rotate(${angle}) scale(${1 - index * 0.12})`}
              fill="#91d7d0"
              fillOpacity={1 - index * 0.2}
              stroke="#080e0d"
              strokeWidth=".65"
              pointerEvents="none"
            >
              <title>{`+${seconds} с при текущей тяге`}</title>
            </path>
          );
        })}
        <g
          transform={`translate(${own.x} ${own.y})`}
          pointerEvents="none"
          style={{ color: '#c4e9d7' }}
        >
          <circle
            r={data.dock_range * scale}
            fill="none"
            stroke="#a6d4c3"
            strokeWidth=".5"
            strokeOpacity=".35"
            strokeDasharray="2 5"
          >
            <title>Дальность стыковки и посадки</title>
          </circle>
          <g transform={`rotate(${data.course})`}>
            <ShipGlyph />
          </g>
        </g>
        <g fill="#718870" stroke="#718870">
          <text x={12} y={54} stroke="none">
            N ↑
          </text>
          <path d={`M12 ${height - 30}h100`} />
          <text x={12} y={height - 12} stroke="none">
            {distanceLabel(100 / scale, data.au_scale)}
          </text>
        </g>
        <text className="nav-system-title" x="14" y="27" pointerEvents="none">
          {data.sector_name}
        </text>
        {data.interference > 0 && (
          <rect
            width={width}
            height={height}
            filter="url(#sensor-noise)"
            opacity={0.6 * data.interference}
            pointerEvents="none"
          />
        )}
      </svg>
    </div>
  );
}

function Velocity({
  origin,
  vx,
  vy,
  scale,
}: {
  origin: Position;
  vx: number;
  vy: number;
  scale: number;
}) {
  if (Math.hypot(vx, vy) < 0.01) return null;
  // The tip is where the vessel will be after VECTOR_SECONDS of unchanged motion.
  return (
    <line
      pointerEvents="none"
      x1={origin.x}
      y1={origin.y}
      x2={origin.x + vx * VECTOR_SECONDS * scale}
      y2={origin.y - vy * VECTOR_SECONDS * scale}
      stroke="#91d7d0"
      strokeWidth={2}
      markerEnd="url(#velocity-arrow)"
    />
  );
}
