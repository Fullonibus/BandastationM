import { useState } from 'react';
import { Button, DraggableControl, Icon } from 'tgui-core/components';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { Annunciator } from './Annunciator';
import { Chart } from './Chart';
import { Compartments } from './Compartments';
import { Descent } from './Descent';
import { ZoomKnob } from './DisplayArt';
import { Docking } from './Docking';
import { AnalogDial, FuelGauges } from './Fuel';
import { Scanner } from './Scanner';
import { distanceLabel, type NavigationData, speedLabel } from './types';
import { useHelm } from './useHelm';

export const SpaceNavigation = () => {
  const { data } = useBackend<NavigationData>();
  return (
    <Window width={1280} height={800}>
      <Window.Content>
        {data.sector ? (
          <Navigation key={data.sector} data={data} />
        ) : (
          'Нет связи с навигационным комплексом'
        )}
      </Window.Content>
    </Window>
  );
};

function Navigation({ data }: { data: NavigationData }) {
  const { act } = useBackend();
  const helm = useHelm(data);
  const [chartZoom, setChartZoom] = useState(1);
  const [hoveredTarget, setHoveredTarget] = useState<string | null>(null);
  const [focusedContact, setFocusedContact] = useState<number | null>(null);
  const [panel, setPanel] = useState<'objects' | 'contacts' | 'scanner'>(
    'objects',
  );
  const moored = !!(data.docked || data.coupled);
  const contact = data.ship_contacts.find(
    (record) => record.id === focusedContact,
  );
  const stationDocking =
    focusedContact === null && data.station_docking?.required
      ? data.station_docking
      : null;
  let dockAction = 'dock';
  let dockValue: string | number | null = data.selected;
  let dockDisabled = !data.can_dock;
  let dockTooltip = data.landing ? 'Посадка' : 'Стыковка';
  if (focusedContact !== null) {
    dockAction = 'ship_dock';
    dockValue = focusedContact;
    dockDisabled = !contact || !data.dockable_contacts.includes(contact.id);
    dockTooltip = `Запрос стыковки К${focusedContact}`;
  } else if (stationDocking?.state === 'approved') {
    dockTooltip = 'Начать стыковку';
  } else if (stationDocking) {
    const pending = stationDocking.state === 'pending';
    dockAction = 'request_station_dock';
    dockDisabled = pending || !stationDocking.canRequest;
    dockTooltip = pending
      ? 'Запрос передан'
      : 'Запросить разрешение на стыковку';
  }
  const clearanceStatus =
    stationDocking && stationDocking.state !== 'none'
      ? `${stationDocking.state === 'approved' ? 'Стыковка разрешена' : 'Запрос передан'}${stationDocking.expiresIn !== null ? ` (${Math.ceil(stationDocking.expiresIn)} с)` : ''}`
      : null;
  const distance = (value: number) => distanceLabel(value, data.au_scale);
  const reverse =
    data.vx * Math.sin((data.course * Math.PI) / 180) +
      data.vy * Math.cos((data.course * Math.PI) / 180) <
    -0.05;
  const mode = data.approach
    ? data.approach.scene === 'planet'
      ? data.approach.departing
        ? 'ВЗЛЁТ'
        : 'ПОСАДКА'
      : data.approach.departing
        ? 'РАССТЫКОВКА'
        : 'СТЫКОВКА'
    : data.preparing
      ? 'ПОДГОТОВКА'
      : moored
        ? data.landed
          ? 'НА ПОВЕРХНОСТИ'
          : 'ПРИСТЫКОВАН'
        : data.autopilot
          ? 'АВТОПИЛОТ'
          : data.speed > 0.05
            ? 'ПОЛЁТ'
            : 'СТОП';
  const selectSite = (id: string) => {
    setFocusedContact(null);
    act('select', { value: id });
  };

  return (
    <main className="SpaceNavigation">
      <header>
        <div className="SpaceNavigation__nameplate">
          <strong title={data.vessel_name}>
            {data.vessel_name || 'НАВИГАЦИЯ'}
          </strong>
          <span>НАВИГАЦИЯ / NAV–01</span>
        </div>
        <Annunciator data={data} />
        <ZoomKnob
          zoom={chartZoom}
          onChange={setChartZoom}
          disabled={!!data.approach}
        />
      </header>
      <div className="SpaceNavigation__body">
        <div className="SpaceNavigation__left-bank">
          <div
            className="SpaceNavigation__tabs"
            role="tablist"
            aria-label="Данные навигации"
          >
            {(
              [
                ['objects', 'ОБЪЕКТЫ'],
                ['contacts', 'КОНТАКТЫ'],
                ['scanner', 'СКАНЕР'],
              ] as const
            ).map(([id, label]) => (
              <button
                type="button"
                key={id}
                className={`Button ${panel === id ? 'Button--selected' : ''}`}
                role="tab"
                aria-selected={panel === id}
                onClick={() => {
                  act('interface_click');
                  setPanel(id);
                }}
              >
                {label}
              </button>
            ))}
          </div>
          <aside className="SpaceNavigation__contacts" aria-label="Объекты">
            <div className="SpaceNavigation__screen-label">
              <span>ОБЗОР</span>
              <span>01</span>
            </div>

            {panel === 'scanner' ? (
              <Scanner data={data} focusedContact={focusedContact} />
            ) : (
              <div className="SpaceNavigation__routes">
                {panel === 'objects' &&
                  data.routes.map((site) => (
                    <Button
                      key={site.id}
                      fluid
                      color={site.sos ? 'red' : undefined}
                      tooltip={
                        site.kind === 'signal' && !site.sos
                          ? site.type
                          : site.name
                      }
                      selected={
                        focusedContact === null && site.id === data.selected
                      }
                      disabled={
                        site.failed || data.preparing || data.relocating
                      }
                      onMouseEnter={() => setHoveredTarget(`site:${site.id}`)}
                      onMouseLeave={() => setHoveredTarget(null)}
                      onClick={() => selectSite(site.id)}
                    >
                      <span>
                        {site.kind === 'signal' && !site.sos
                          ? site.type
                          : site.name}
                      </span>
                      <span>{distance(site.distance)}</span>
                    </Button>
                  ))}
                {panel === 'contacts' &&
                  data.ship_contacts.map((record) => (
                    <Button
                      key={`contact-${record.id}`}
                      fluid
                      tooltip={
                        record.identity?.callsign || 'Неопознанное судно'
                      }
                      selected={record.id === focusedContact}
                      onMouseEnter={() =>
                        setHoveredTarget(`contact:${record.id}`)
                      }
                      onMouseLeave={() => setHoveredTarget(null)}
                      onClick={() => {
                        act('interface_click');
                        setFocusedContact(record.id);
                      }}
                    >
                      <span>
                        К{record.id} ·{' '}
                        {record.identity?.callsign || 'Неопознанное судно'}
                      </span>
                      <span>
                        {distance(
                          Math.hypot(record.x - data.x, record.y - data.y),
                        )}
                      </span>
                    </Button>
                  ))}
                {((panel === 'objects' && !data.routes.length) ||
                  (panel === 'contacts' && !data.ship_contacts.length)) && (
                  <p className="SpaceNavigation__help">Нет отметок</p>
                )}
              </div>
            )}
          </aside>
          <div className="SpaceNavigation__hull-screen">
            <Compartments rooms={data.compartments} hull={data.hull} />
          </div>
        </div>
        <section className="SpaceNavigation__plot">
          <div className="SpaceNavigation__screen-label">
            <span>ОРБИТАЛЬНАЯ НАВИГАЦИЯ</span>
          </div>
          {data.approach?.scene === 'planet' ? (
            <Descent approach={data.approach} />
          ) : data.approach ? (
            <Docking approach={data.approach} />
          ) : (
            <Chart
              zoom={chartZoom}
              hoveredTarget={hoveredTarget}
              data={data}
              focusedContact={focusedContact}
              onContact={(id) => {
                act('interface_click');
                setFocusedContact(id);
                setPanel('scanner');
              }}
              onSite={selectSite}
            />
          )}
          <div className="SpaceNavigation__legend">
            <span title="При сохранении текущей тяги и команды курса">
              <Icon name="location-arrow" /> +20 / 40 / 60 с
            </span>
          </div>
        </section>

        <aside className="SpaceNavigation__telemetry" aria-label="Управление">
          <div className="SpaceNavigation__engraving">
            <span>ДВИГАТЕЛЬНАЯ УСТАНОВКА</span>
            <span>01</span>
          </div>
          <div className="SpaceNavigation__engine-control">
            <Button
              className="SpaceNavigation__engine"
              icon="power-off"
              selected={!!data.engines_running}
              tooltip={
                data.engines_running
                  ? 'Выключить двигатели'
                  : 'Запустить двигатели'
              }
              aria-label="Двигатели"
              aria-pressed={!!data.engines_running}
              disabled={
                data.preparing ||
                data.relocating ||
                (!data.engines_running && !data.can_start_engines)
              }
              onClick={() =>
                act('engine', { value: data.engines_running ? 0 : 1 })
              }
            >
              <span className="SpaceNavigation__key-label">ДВИГАТЕЛИ</span>
            </Button>
            <Button
              className="SpaceNavigation__engine"
              icon="fire"
              selected={!!data.afterburner}
              color={data.afterburner ? 'good' : undefined}
              tooltip={
                data.afterburner
                  ? 'Выключить форсаж'
                  : 'Форсаж: +50 % тяги, двойной расход трития, ядро греется'
              }
              aria-label="Форсаж"
              aria-pressed={!!data.afterburner}
              disabled={!data.can_afterburner}
              onClick={() => act('afterburner')}
            >
              <span className="SpaceNavigation__key-label">ФОРСАЖ</span>
            </Button>

            <Button
              className="SpaceNavigation__scan"
              selected={data.scan_age !== null && data.scan_age < 1.5}
              tooltip="Сканирование"
              aria-label="Сканирование"
              disabled={!data.scan_ready}
              onClick={() => act('scan')}
            >
              <Icon name="satellite-dish" />
              <span className="SpaceNavigation__key-label">СОНАР</span>
              <span
                role="status"
                aria-label={
                  data.scan_ready
                    ? 'Сканирование доступно'
                    : 'Сканирование недоступно'
                }
                className={`SpaceNavigation__lamp ${data.scan_ready ? 'ready' : ''}`}
              />
            </Button>
          </div>

          <div className="SpaceNavigation__gauges">
            <AnalogDial
              label="СКОРОСТЬ"
              share={data.speed / data.speed_scale}
              scaleMax={data.speed_scale}
              readout={`${reverse ? '−' : ''}${speedLabel(data.speed, data.au_scale)}`}
            />
            {!!data.fuel && <FuelGauges gauges={data.fuel} />}
          </div>
          <div className="SpaceNavigation__flight-screen">
            <div className="SpaceNavigation__screen-label">
              <span>ПОЛЁТНЫЕ ДАННЫЕ</span>
              <span>03</span>
            </div>
            <dl>
              <dt>ПОЗ</dt>
              <dd>
                {distance(data.x)} / {distance(data.y)}
              </dd>
              <dt>КУРС / ЗАД</dt>
              <dd>
                {Math.round(data.course)}° / {Math.round(data.ordered_course)}°
              </dd>
              <dt>ДИСТ</dt>
              <dd>{data.selected ? distance(data.distance) : '—'}</dd>
              <dt>ТОРМ. ПУТЬ</dt>
              <dd>
                {data.braking_distance === null
                  ? '—'
                  : distance(data.braking_distance)}
              </dd>
            </dl>
          </div>

          <div className="SpaceNavigation__engraving">
            <span>ТЯГА И МАНЁВРЫ</span>
            <span>02</span>
          </div>
          <div className="SpaceNavigation__helm">
            <div className="SpaceNavigation__throttle" aria-label="Рычаг тяги">
              <span className="SpaceNavigation__throttle-label">ТЯГА</span>
              <div className="SpaceNavigation__scale" aria-hidden="true">
                {['+100', '+50', '0', '−50', '−100'].map((mark) => (
                  <span key={mark}>{mark}</span>
                ))}
              </div>
              <DraggableControl
                value={data.throttle}
                minValue={-100}
                maxValue={100}
                step={5}
                stepPixelSize={3.5}
                dragMatrix={[0, -1]}
                updateRate={150}
                tickWhileDragging
                disabled={helm.blocked}
                unit="%"
                onChange={(_, value) => helm.setThrottle(value)}
              >
                {({ displayValue, handleDragStart, inputElement }) => (
                  <>
                    <div
                      className="SpaceNavigation__lever"
                      role="slider"
                      tabIndex={helm.blocked ? -1 : 0}
                      aria-label="Тяга, проценты"
                      aria-valuemin={-100}
                      aria-valuemax={100}
                      aria-valuenow={displayValue}
                      aria-disabled={helm.blocked}
                      style={{ top: `${12 + (100 - displayValue) * 0.7}px` }}
                      onMouseDown={handleDragStart}
                      onKeyDown={(event) => {
                        if (helm.blocked) return;
                        if (
                          ['ArrowUp', 'ArrowDown', 'Home', 'End'].includes(
                            event.key,
                          )
                        ) {
                          event.preventDefault();
                          event.stopPropagation();
                          if (event.key === 'Home') helm.setThrottle(0);
                          else if (event.key === 'End') helm.setThrottle(100);
                          else
                            helm.changeThrottle(
                              event.key === 'ArrowUp' ? 5 : -5,
                            );
                        }
                      }}
                    />
                    {inputElement}
                    <output>{displayValue}%</output>
                  </>
                )}
              </DraggableControl>
            </div>
            <div className="SpaceNavigation__helm-buttons">
              <div
                className="SpaceNavigation__maneuvers"
                role="group"
                aria-label="Управление кораблём"
              >
                <Button
                  disabled={helm.blocked}
                  tooltip="Рыскание влево"
                  onClick={() => act('turn', { value: -15 })}
                  aria-label="Рыскание влево"
                >
                  <Icon name="rotate-left" />
                </Button>
                <Button
                  disabled={helm.blocked}
                  tooltip="Увеличить тягу"
                  onClick={() => helm.changeThrottle(5, true)}
                  aria-label="Увеличить тягу"
                >
                  <Icon name="arrow-up" />
                </Button>
                <Button
                  disabled={helm.blocked}
                  tooltip="Рыскание вправо"
                  onClick={() => act('turn', { value: 15 })}
                  aria-label="Рыскание вправо"
                >
                  <Icon name="rotate-right" />
                </Button>
                <Button
                  disabled={helm.lateralBlocked}
                  tooltip="Боковая тяга влево: удерживать"
                  selected={data.maneuver_direction === 8}
                  onMouseDown={(event) => {
                    if (event.button === 0) helm.hold('left');
                  }}
                  aria-label="Боковая тяга влево"
                  onClick={(event) => {
                    if (event.detail === 0)
                      act('maneuver', {
                        value: data.maneuver_direction === 8 ? 0 : 8,
                      });
                  }}
                >
                  <Icon name="arrow-left" />
                </Button>
                <Button
                  disabled={helm.blocked}
                  tooltip="Уменьшить тягу"
                  onClick={() => helm.changeThrottle(-5, true)}
                  aria-label="Уменьшить тягу"
                >
                  <Icon name="arrow-down" />
                </Button>
                <Button
                  disabled={helm.lateralBlocked}
                  tooltip="Боковая тяга вправо: удерживать"
                  selected={data.maneuver_direction === 4}
                  onMouseDown={(event) => {
                    if (event.button === 0) helm.hold('right');
                  }}
                  aria-label="Боковая тяга вправо"
                  onClick={(event) => {
                    if (event.detail === 0)
                      act('maneuver', {
                        value: data.maneuver_direction === 4 ? 0 : 4,
                      });
                  }}
                >
                  <Icon name="arrow-right" />
                </Button>
              </div>
              <Button
                fluid
                disabled={
                  helm.blocked ||
                  data.planning ||
                  !data.selected ||
                  data.selected === data.docked ||
                  data.engines <= 0 ||
                  data.throttle <= 0
                }
                className="SpaceNavigation__auto"
                icon="route"
                aria-label="Автопилот"
                tooltip="Автопилот к выбранной цели"
                selected={!!data.autopilot}
                onClick={() => act('autopilot')}
              >
                <span className="SpaceNavigation__key-label">АП</span>
              </Button>
              <div className="SpaceNavigation__brakes">
                <Button
                  className="SpaceNavigation__stop"
                  icon="pause"
                  aria-label="Торможение"
                  selected={!!data.braking}
                  tooltip={data.jumping ? 'Отменить прыжок' : 'Торможение'}
                  disabled={data.relocating}
                  onClick={() => act('stop')}
                >
                  <span className="SpaceNavigation__key-label">ТОРМОЗ</span>
                </Button>
                <Button
                  className="SpaceNavigation__emergency"
                  icon="triangle-exclamation"
                  tooltip="Аварийное торможение маневровыми двигателями: работает без основных двигателей, нужно питание корабля"
                  aria-label="Аварийное торможение"
                  selected={!!data.emergency_braking}
                  disabled={
                    !data.ship_power ||
                    moored ||
                    data.relocating ||
                    data.speed <= 0.05
                  }
                  onClick={() => act('emergency_brake')}
                >
                  <span className="SpaceNavigation__key-label">АВАР.</span>
                </Button>
              </div>
            </div>
          </div>

          <div className="SpaceNavigation__engraving">
            <span>СТЫКОВОЧНЫЕ ОПЕРАЦИИ</span>
            <span>03</span>
          </div>
          <div className="SpaceNavigation__dock-bank">
            <section className="SpaceNavigation__docking" aria-label="Стыковка">
              <Button
                fluid
                aria-label="Стыковка или посадка"
                tooltip={dockTooltip}
                disabled={dockDisabled}
                selected={!!clearanceStatus}
                onClick={() => act(dockAction, { value: dockValue })}
              >
                <Icon name="right-to-bracket" />
                <span className="SpaceNavigation__key-label">СТЫК</span>
              </Button>
              <Button
                fluid
                aria-label="Отстыковка или взлёт"
                tooltip={data.landed ? 'Взлёт' : 'Отстыковка'}
                disabled={
                  !moored ||
                  !data.engines_running ||
                  data.preparing ||
                  data.relocating ||
                  data.engines <= 0
                }
                onClick={() => act('depart')}
              >
                <Icon name="right-from-bracket" />
                <span className="SpaceNavigation__key-label">ОТСТЫК</span>
              </Button>
            </section>
            <div
              className="SpaceNavigation__request"
              role="group"
              aria-label="Входящий запрос стыковки"
            >
              <Button
                fluid
                tooltip={
                  data.docking_request
                    ? `Принять запрос К${data.docking_request.contact ?? '?'}`
                    : 'Нет запроса'
                }
                aria-label="Принять запрос стыковки"
                disabled={!data.docking_request || !data.can_request_ship_dock}
                onClick={() =>
                  act('accept_ship_dock', {
                    value: data.docking_request?.token,
                  })
                }
              >
                <Icon name="check" />
                <span className="SpaceNavigation__key-label">ПРИНЯТЬ</span>
              </Button>
              <Button
                fluid
                aria-label={
                  data.docking_request
                    ? 'Отклонить запрос стыковки'
                    : 'Отменить запрос на стыковку'
                }
                tooltip={
                  data.docking_request
                    ? 'Отклонить запрос стыковки'
                    : 'Отменить запрос или разрешение на стыковку'
                }
                disabled={!data.docking_request && !stationDocking?.canCancel}
                onClick={() =>
                  data.docking_request
                    ? act('decline_ship_dock', {
                        value: data.docking_request.token,
                      })
                    : act('cancel_station_dock', { value: data.selected })
                }
              >
                <Icon name="xmark" />
                <span className="SpaceNavigation__key-label">ОТКАЗ</span>
              </Button>
            </div>
          </div>
        </aside>
      </div>
      <div className="SpaceNavigation__status-bank">
        <footer role="status" title={clearanceStatus || data.status}>
          <span className="SpaceNavigation__status-dot" />
          {clearanceStatus || data.status}
        </footer>
        <div
          className="SpaceNavigation__mode-screen"
          role="status"
          aria-label="Состояние полёта"
        >
          <strong>{mode}</strong>
          <span>
            ТЯГА <b>{data.throttle}%</b>
          </span>
        </div>
      </div>
    </main>
  );
}
