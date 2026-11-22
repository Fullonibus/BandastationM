import { type ComponentProps, useState } from 'react';
import { Icon, ProgressBar, Section } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Option = { id: string; name: string };

type Unit = Option & {
  health: number;
  maxHealth: number;
  reachable: number;
  viewing: number;
  selected: number;
  autonomous: number;
  status: string;
};

type Data = {
  units: Unit[];
  stock: (Option & {
    guest: number;
    prepared: number;
    portrait: string | null;
  })[];
  limit: number;
  storageLimit: number;
  transports: Option[];
  beacons: Option[];
  sites: (Option & { type: string; failed: number })[];
  site: string | null;
  watching: number;
  armedClick: string | null;
  patrolFirst: number;
  hostileTargets: Option[];
  computer: number;
  fabricator: number;
};

const statusLabels: Record<string, string> = {
  attack: 'Атака',
  detonating: 'Самоуничтожение',
  follow: 'Сопровождение',
  guest: 'Игрок',
  hold: 'Ожидает',
  move: 'Маршрут',
  patrol: 'Патруль',
  polling: 'Розыгрыш',
  transit: 'В пути',
};

const orders = [
  ['move', 'К точке', 'location-arrow'],
  ['follow', 'Следовать', 'link'],
  ['patrol', 'Патруль', 'route'],
  ['attack', 'Атака', 'crosshairs'],
  ['hold', 'Стоять', 'hand-paper'],
] as const;

function RelayButton({
  children,
  icon,
  tone = 'default',
  className = '',
  ...props
}: ComponentProps<'button'> & {
  icon?: string;
  tone?: 'default' | 'transparent' | 'danger';
}) {
  return (
    <button
      {...props}
      type="button"
      className={`Button Button--color--${tone} ${props['aria-pressed'] ? 'Button--selected' : ''} ${className}`}
    >
      {icon && <Icon name={icon} aria-hidden="true" />}
      {children}
    </button>
  );
}

export function DroidRelay() {
  const { act, data } = useBackend<Data>();
  const [page, setPage] = useState<'squad' | 'deployment'>('squad');
  const [hostileListOpen, setHostileListOpen] = useState(false);
  const [transportId, setTransport] = useState('');
  const [mode, setMode] = useState('random');
  const [beaconId, setBeacon] = useState('');
  const selected = data.units.filter((entry) => entry.selected);
  const unit = selected.length === 1 ? selected[0] : undefined;
  const transport = data.transports.find((entry) => entry.id === transportId);
  const beacon = data.beacons.find((entry) => entry.id === beaconId);
  const prepared = data.stock.filter((entry) => entry.prepared).length;
  const availableSites = data.sites.filter((site) => !site.failed);
  const site = availableSites.find((entry) => entry.id === data.site);
  const canOrder = selected.some(
    (entry) => entry.reachable && entry.autonomous,
  );
  const freePilot = !!(unit?.reachable && unit.autonomous);
  const watching = !!data.watching;
  const chooseDrop = !!transport && mode === 'aimed';
  const dropArmed = data.armedClick === 'drop';
  const markArmed = data.armedClick === 'mark_hostile';
  const slots = Math.max(0, data.limit - data.units.length);
  const launchCount = Math.min(prepared, slots);
  const launchAdvice = !slots
    ? 'Лимит отряда исчерпан.'
    : !prepared
      ? 'Отметьте корпуса для отправки.'
      : transportId && !transport
        ? 'Выбранный транспорт потерял связь.'
        : transport && !site
          ? 'Выберите объект на овермапе.'
          : transport && mode === 'beacon' && !beacon
            ? 'Выберите действующий маяк.'
            : chooseDrop && !watching
              ? 'Откройте камеру дроида в отряде.'
              : '';
  const clickAdvice = dropArmed
    ? 'Нажмите на свободную площадку в игровом окне.'
    : markArmed
      ? 'Нажмите ЛКМ по видимой цели. ПКМ отменяет выбор.'
      : data.patrolFirst
        ? 'Выберите вторую точку патруля.'
        : data.armedClick === 'patrol'
          ? 'Выберите первую точку патруля.'
          : 'Укажите цель в игровом окне.';

  return (
    <Window width={420} height={496}>
      <Window.Content fitted className="DroidRelay">
        <header className="DroidRelay__header">
          <nav className="DroidRelay__nav" aria-label="Режим работы реле">
            <RelayButton
              aria-controls="relay-squad"
              aria-pressed={page === 'squad'}
              onClick={() => setPage('squad')}
            >
              Отряд{' '}
              <span>
                {data.units.length}/{data.limit}
              </span>
            </RelayButton>
            <RelayButton
              aria-controls="relay-deployment"
              aria-pressed={page === 'deployment'}
              onClick={() => setPage('deployment')}
            >
              Высадка <span>{prepared}</span>
            </RelayButton>
          </nav>
          <div className="DroidRelay__tools">
            <RelayButton
              icon="industry"
              className="DroidRelay__productionLink"
              disabled={!data.fabricator}
              aria-label="Производство дроидов"
              title={
                data.fabricator
                  ? 'Производство дроидов'
                  : 'Фабрикатор не подключён'
              }
              onClick={() => act('fabricator')}
            />
            <RelayButton
              icon="comment"
              tone="transparent"
              aria-label="Канал отряда"
              title="Канал отряда"
              onClick={() => act('message')}
            />
            {!!data.computer && (
              <RelayButton
                icon="space-shuttle"
                tone="transparent"
                aria-label="Управление кораблём"
                title="Управление кораблём"
                onClick={() => act('ship')}
              />
            )}
          </div>
        </header>

        {!!data.armedClick && (
          <div className="DroidRelay__target">
            <span role="status">{clickAdvice}</span>
            {(!dropArmed || page === 'squad') && (
              <RelayButton
                tone="transparent"
                onClick={() => act('cancel_order')}
              >
                Отмена
              </RelayButton>
            )}
          </div>
        )}

        <div
          className="DroidRelay__scroll"
          id="relay-squad"
          hidden={page !== 'squad'}
        >
          <Section title="Дроиды">
            {!data.units.length && (
              <div className="DroidRelay__empty">
                Отряд пуст.{' '}
                <RelayButton
                  tone="transparent"
                  onClick={() => setPage('deployment')}
                >
                  К высадке
                </RelayButton>
              </div>
            )}
            {data.units.map((entry, index) => {
              const name = `${index + 1}. ${entry.name}`;
              const status =
                entry.reachable || entry.status === 'transit'
                  ? statusLabels[entry.status]
                  : 'Нет связи';
              return (
                <div className="DroidRelay__unit" key={entry.id}>
                  <RelayButton
                    className="DroidRelay__unitSelect"
                    tone="transparent"
                    aria-pressed={!!entry.selected}
                    disabled={!entry.reachable}
                    onClick={(event) =>
                      act('select', {
                        unit: entry.id,
                        additive: event.shiftKey,
                      })
                    }
                  >
                    <strong>{name}</strong>
                    <span>{status}</span>
                  </RelayButton>
                  <div className="DroidRelay__health" title="Прочность корпуса">
                    <span>
                      {entry.health}/{entry.maxHealth}
                    </span>
                    <ProgressBar
                      empty
                      value={entry.health / Math.max(1, entry.maxHealth)}
                      ranges={{
                        good: [0.6, 1],
                        average: [0.25, 0.6],
                        bad: [0, 0.25],
                      }}
                    />
                  </div>
                  <RelayButton
                    icon="video"
                    tone="transparent"
                    aria-label={`Камера: ${name}`}
                    title={`Камера: ${name}`}
                    aria-pressed={!!entry.viewing}
                    disabled={!entry.reachable}
                    onClick={() => act('camera', { unit: entry.id })}
                  />
                </div>
              );
            })}
            {watching && (
              <div className="DroidRelay__row DroidRelay__row--spaced">
                <RelayButton
                  icon="expand"
                  onClick={() => act('select_visible')}
                >
                  Выбрать видимых
                </RelayButton>
                <RelayButton
                  icon="eye-slash"
                  tone="transparent"
                  onClick={() => act('home')}
                >
                  Закрыть камеру
                </RelayButton>
              </div>
            )}
          </Section>

          <Section>
            <div className="DroidRelay__hostileActions">
              <RelayButton
                tone="transparent"
                icon={hostileListOpen ? 'chevron-down' : 'chevron-right'}
                aria-expanded={hostileListOpen}
                aria-controls="relay-hostile-list"
                onClick={() => setHostileListOpen(!hostileListOpen)}
              >
                Враждебные цели · {data.hostileTargets.length}
              </RelayButton>
              <RelayButton
                icon="flag"
                disabled={!watching}
                title={watching ? undefined : 'Откройте камеру дроида'}
                aria-pressed={markArmed}
                onClick={() => act(markArmed ? 'cancel_order' : 'mark_hostile')}
              >
                Отметить врага
              </RelayButton>
            </div>
            <div id="relay-hostile-list" hidden={!hostileListOpen}>
              {data.hostileTargets.length ? (
                <ul className="DroidRelay__hostiles">
                  {data.hostileTargets.map((target) => (
                    <li key={target.id}>
                      <span>{target.name}</span>
                      <RelayButton
                        tone="transparent"
                        aria-label={`Снять отметку с цели ${target.name}`}
                        onClick={() => act('unmark_hostile', { id: target.id })}
                      >
                        Снять
                      </RelayButton>
                    </li>
                  ))}
                </ul>
              ) : (
                <p>
                  {watching
                    ? 'Отметок нет.'
                    : 'Откройте камеру дроида, чтобы отметить цель.'}
                </p>
              )}
            </div>
          </Section>

          <Section
            title={
              selected.length
                ? `Приказы · выбрано ${selected.length}`
                : 'Приказы'
            }
          >
            <div className="DroidRelay__row">
              {orders.map(([command, label, icon]) => (
                <RelayButton
                  key={command}
                  icon={icon}
                  disabled={!canOrder || (command !== 'hold' && !watching)}
                  aria-pressed={
                    command === 'hold' ? undefined : data.armedClick === command
                  }
                  onClick={() => act('order', { command })}
                >
                  {label}
                </RelayButton>
              ))}
            </div>
            {!selected.length && <p>Выберите дроидов в списке или на карте.</p>}
            {!!selected.length && !canOrder && (
              <p>Приказы доступны дроидам под управлением ИИ.</p>
            )}
            {canOrder && !watching && (
              <p>Откройте камеру, чтобы указать цель.</p>
            )}
          </Section>

          {unit && (
            <Section title="Корпус">
              <div className="DroidRelay__row">
                <RelayButton
                  icon="gamepad"
                  disabled={!freePilot}
                  onClick={() => act('control', { unit: unit.id })}
                >
                  Управлять
                </RelayButton>
                <RelayButton
                  icon="ghost"
                  disabled={!freePilot}
                  onClick={() => act('recruit', { unit: unit.id })}
                >
                  Розыгрыш
                </RelayButton>
                <RelayButton
                  icon="undo"
                  title={transport?.name || 'Отозвать к реле'}
                  disabled={!unit.reachable || (!!transportId && !transport)}
                  onClick={() =>
                    act('recover', { unit: unit.id, transport: transport?.id })
                  }
                >
                  Отозвать
                </RelayButton>
                <RelayButton
                  icon="bomb"
                  tone="danger"
                  disabled={!unit.reachable || unit.status === 'detonating'}
                  onClick={() => act('detonate', { unit: unit.id })}
                >
                  Подорвать
                </RelayButton>
              </div>
            </Section>
          )}

          <details className="DroidRelay__help">
            <summary>Клавиши и мышь</summary>
            <p>
              WASD — камера. ЛКМ — выбрать. Рамка или Shift + ЛКМ — выделить
              группу.
            </p>
            <p>
              ПКМ — идти или атаковать. СКМ — сопровождать или патрулировать.
            </p>
          </details>
        </div>

        <div
          className="DroidRelay__scroll"
          id="relay-deployment"
          hidden={page !== 'deployment'}
        >
          <Section
            title={`Корпуса · ${data.stock.length}/${data.storageLimit}`}
          >
            {!data.stock.length && <p>В реле нет готовых корпусов.</p>}
            <div className="DroidRelay__stock">
              {data.stock.map((entry, index) => (
                <label className="DroidRelay__stockItem" key={entry.id}>
                  <input
                    type="checkbox"
                    checked={!!entry.prepared}
                    onChange={() => act('prepare', { chassis: entry.id })}
                  />
                  {entry.portrait && (
                    <img
                      alt=""
                      src={`data:image/png;base64,${entry.portrait}`}
                      width={24}
                      height={24}
                    />
                  )}
                  <span>
                    {entry.name} {index + 1}
                    {entry.guest ? ' · игрок' : ''}
                  </span>
                </label>
              ))}
            </div>
          </Section>

          <Section title="Маршрут высадки">
            <div className="DroidRelay__form">
              <label htmlFor="relay-transport">Транспорт</label>
              <select
                id="relay-transport"
                value={transportId}
                onChange={(event) => {
                  if (dropArmed) act('cancel_order');
                  setTransport(event.currentTarget.value);
                }}
              >
                <option value="">Рядом с реле</option>
                {!!transportId && !transport && (
                  <option value={transportId} disabled>
                    Нет связи
                  </option>
                )}
                {data.transports.map((entry) => (
                  <option key={entry.id} value={entry.id}>
                    {entry.name}
                  </option>
                ))}
              </select>
              {transport && (
                <>
                  <label htmlFor="relay-site">Объект</label>
                  <select
                    id="relay-site"
                    title={site?.name}
                    value={site?.id ?? ''}
                    onChange={(event) =>
                      act('site', { id: event.currentTarget.value })
                    }
                  >
                    <option value="" disabled>
                      Выбрать объект
                    </option>
                    {availableSites.map((entry) => (
                      <option key={entry.id} value={entry.id}>
                        {entry.name === '???' ? entry.type : entry.name}
                      </option>
                    ))}
                  </select>
                  <label htmlFor="relay-mode">Точка</label>
                  <select
                    id="relay-mode"
                    value={mode}
                    onChange={(event) => {
                      if (dropArmed) act('cancel_order');
                      setMode(event.currentTarget.value);
                    }}
                  >
                    <option value="random">Случайная точка</option>
                    <option value="beacon">Маяк</option>
                    <option value="aimed">По камере</option>
                  </select>
                  {mode === 'beacon' && (
                    <>
                      <label htmlFor="relay-beacon">Маяк</label>
                      <select
                        id="relay-beacon"
                        title={beacon?.name}
                        value={beacon?.id ?? ''}
                        onChange={(event) =>
                          setBeacon(event.currentTarget.value)
                        }
                      >
                        <option value="" disabled>
                          {data.beacons.length
                            ? 'Выбрать маяк'
                            : 'Нет действующих маяков'}
                        </option>
                        {data.beacons.map((entry) => (
                          <option key={entry.id} value={entry.id}>
                            {entry.name}
                          </option>
                        ))}
                      </select>
                    </>
                  )}
                </>
              )}
            </div>
          </Section>
        </div>

        {page === 'deployment' && (
          <footer className="DroidRelay__footer">
            <p id="relay-launch-status">
              {dropArmed
                ? `К высадке: ${launchCount} из ${prepared}`
                : launchAdvice ||
                  `К высадке: ${launchCount} из ${prepared} · свободных мест: ${slots}`}
            </p>
            <RelayButton
              icon={dropArmed ? 'times' : chooseDrop ? 'crosshairs' : 'rocket'}
              aria-describedby="relay-launch-status"
              disabled={!!launchAdvice && !dropArmed}
              onClick={() => {
                if (dropArmed) {
                  act('cancel_order');
                  return;
                }
                act(chooseDrop ? 'choose_drop' : 'deploy', {
                  transport: transport?.id,
                  mode,
                  beacon: beacon?.id,
                });
              }}
            >
              {dropArmed
                ? 'Отменить выбор точки'
                : chooseDrop
                  ? 'Выбрать точку'
                  : 'Развернуть'}
            </RelayButton>
          </footer>
        )}
      </Window.Content>
    </Window>
  );
}
