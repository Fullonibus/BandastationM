import { useState } from 'react';
import { Box, Icon, NoticeBox, Section, Stack } from 'tgui-core/components';
import { type BooleanLike, classes } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const dockStatuses = {
  free: { label: 'Свободен', color: 'good' },
  approved: { label: 'Заход разрешён', color: 'average' },
  reserved: { label: 'Зарезервирован', color: 'average' },
  occupied: { label: 'Занят', color: 'label' },
  unavailable: { label: 'Недоступен', color: 'bad' },
} as const;

const shipClassLabels = {
  small: 'Класс S',
  medium: 'Класс M',
  capital: 'Крупный корабль',
} as const;

type Dock = {
  id: string;
  name: string;
  dock_class: string | null;
  status: keyof typeof dockStatuses;
  ship: string | null;
};

type DockingRequest = {
  ship_id: string;
  token: string;
  ship: string;
  ship_class: keyof typeof shipClassLabels;
  dock_id: string | null;
  dock: string | null;
  approved: BooleanLike;
  seconds_left: number;
  compatible_docks: string[];
};

type TrafficData = {
  sector?: string;
  target?: string;
  docks: Dock[];
  requests: DockingRequest[];
};

const trafficStyles = `
  .StationTrafficControl__name,
  .StationTrafficControl__docks td {
    overflow-wrap: anywhere;
  }

  .StationTrafficControl__request + .StationTrafficControl__request {
    border-top: var(--divider-border);
    margin-top: var(--space-m);
    padding-top: var(--space-m);
  }

  .StationTrafficControl__time {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
  }

  .StationTrafficControl__sectionMeta {
    display: inline-block;
    font-weight: normal;
  }

  .StationTrafficControl__actions {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-s);
  }

  .StationTrafficControl__select {
    box-sizing: border-box;
    width: 100%;
  }

  .StationTrafficControl .Button {
    border: 0;
  }

  .StationTrafficControl__select,
  .StationTrafficControl .Button {
    font-family: inherit;
    font-size: inherit;
    min-height: 2.25rem;
  }

  .StationTrafficControl__select:focus-visible,
  .StationTrafficControl .Button:focus-visible {
    outline: 2px solid var(--color-text);
    outline-offset: -2px;
  }

  .StationTrafficControl__docks td {
    border-top: var(--divider-border);
    padding-block: var(--space-s);
    vertical-align: top;
  }

  .StationTrafficControl__docks td:first-child {
    width: 40%;
  }
`;

function formatDeadline(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  const remainder = String(seconds % 60).padStart(2, '0');
  return `${minutes}:${remainder}`;
}

function RequestRow({
  request,
  docks,
}: {
  request: DockingRequest;
  docks: Dock[];
}) {
  const { act } = useBackend<TrafficData>();
  const [dockId, setDockId] = useState('');
  const candidates = docks.filter(
    (dock) =>
      dock.status === 'free' && request.compatible_docks.includes(dock.id),
  );
  const shipClass = shipClassLabels[request.ship_class];
  const selectedDock = candidates.find((dock) => dock.id === dockId);
  const actionParams = { ship_id: request.ship_id, token: request.token };

  return (
    <div className="StationTrafficControl__request">
      <Stack align="baseline">
        <Stack.Item grow minWidth={0}>
          <Box bold fontSize={1.125} className="StationTrafficControl__name">
            {request.ship}
          </Box>
          <Box color="label">
            {shipClass && `${shipClass} · `}
            {request.approved ? 'Заход разрешён' : 'Ожидает назначения'}
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Box
            color={request.seconds_left <= 15 ? 'average' : 'label'}
            className="StationTrafficControl__time"
          >
            Истекает через {formatDeadline(request.seconds_left)}
          </Box>
        </Stack.Item>
      </Stack>
      <Stack align="center" wrap="wrap" mt={0.75}>
        <Stack.Item grow basis="14rem" minWidth={0}>
          {request.approved ? (
            <Box bold className="StationTrafficControl__name">
              {request.dock}
            </Box>
          ) : candidates.length ? (
            <>
              <select
                aria-label={`Причал для корабля «${request.ship}»`}
                className="Input StationTrafficControl__select"
                onChange={(event) => setDockId(event.currentTarget.value)}
                title={selectedDock?.name}
                value={selectedDock?.id ?? ''}
              >
                <option value="" disabled>
                  Выберите причал
                </option>
                {candidates.map((dock) => (
                  <option key={dock.id} value={dock.id}>
                    {dock.dock_class
                      ? `${dock.name} · класс ${dock.dock_class}`
                      : dock.name}
                  </option>
                ))}
              </select>
              {dockId && !selectedDock && (
                <div role="status">
                  <Box color="average" mt={0.5}>
                    Выбранный причал стал недоступен.
                  </Box>
                </div>
              )}
            </>
          ) : (
            <Box color="average">Нет свободных совместимых причалов.</Box>
          )}
        </Stack.Item>
        <Stack.Item className="StationTrafficControl__actions">
          {!request.approved && (
            <button
              type="button"
              className={classes([
                'Button Button--color--default',
                !selectedDock && 'Button--disabled',
              ])}
              aria-label={`Назначить причал кораблю «${request.ship}»`}
              disabled={!selectedDock}
              onClick={() => {
                if (selectedDock) {
                  act('approve', { ...actionParams, dock_id: selectedDock.id });
                }
              }}
            >
              <Icon name="check" mr={0.5} aria-hidden="true" />
              Назначить причал
            </button>
          )}
          <button
            type="button"
            className="Button Button--color--transparent"
            aria-label={
              request.approved
                ? `Отозвать разрешение корабля «${request.ship}»`
                : `Отклонить заявку корабля «${request.ship}»`
            }
            onClick={() => act('deny', actionParams)}
          >
            {request.approved ? 'Отозвать разрешение' : 'Отклонить'}
          </button>
        </Stack.Item>
      </Stack>
    </div>
  );
}

function DockInventory({ docks }: { docks: Dock[] }) {
  if (!docks.length) {
    return <Box color="label">Зарегистрированных причалов нет.</Box>;
  }

  return (
    <table className="Table StationTrafficControl__docks">
      <thead>
        <tr className="Table__row--header">
          <th scope="col" className="Table__cell">
            Причал
          </th>
          <th scope="col" className="Table__cell">
            Состояние
          </th>
          <th scope="col" className="Table__cell">
            Корабль
          </th>
        </tr>
      </thead>
      <tbody>
        {docks.map((dock) => (
          <tr key={dock.id}>
            <td className="Table__cell">
              <Box bold>{dock.name}</Box>
              <Box color="label">
                {dock.dock_class ? `Класс ${dock.dock_class}` : 'Штатный'}
              </Box>
            </td>
            <td className="Table__cell">
              <Box color={dockStatuses[dock.status].color}>
                {dockStatuses[dock.status].label}
              </Box>
            </td>
            <td className="Table__cell">{dock.ship || '—'}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export function StationTrafficControl() {
  const { data } = useBackend<TrafficData>();
  const { docks = [], requests = [], sector, target } = data;
  const pending = requests.filter((request) => !request.approved);
  const approved = requests.filter((request) => request.approved);
  const freeDocks = docks.filter((dock) => dock.status === 'free').length;

  return (
    <Window title="Центр управления полётами" width={680} height={520}>
      <Window.Content scrollable className="StationTrafficControl">
        <style>{trafficStyles}</style>
        {!sector ? (
          <NoticeBox danger>Нет связи с диспетчерской сетью.</NoticeBox>
        ) : (
          <>
            <Box mb={1.25} className="StationTrafficControl__name">
              <Box bold fontSize={1.4}>
                {target || sector}
              </Box>
              {target && target !== sector && <Box color="label">{sector}</Box>}
            </Box>
            <Section
              title={
                <>
                  Заявки на стыковку
                  {!!pending.length && (
                    <Box
                      as="span"
                      className="StationTrafficControl__sectionMeta"
                      color="label"
                      fontSize={0.9}
                      ml={1.5}
                    >
                      {pending.length} в очереди
                    </Box>
                  )}
                </>
              }
            >
              {!requests.length ? (
                <Box color="label">Активных заявок на стыковку нет.</Box>
              ) : (
                [...pending, ...approved].map((request) => (
                  <RequestRow
                    key={request.token}
                    request={request}
                    docks={docks}
                  />
                ))
              )}
            </Section>
            <Section
              title={
                <>
                  Причалы
                  {!!docks.length && (
                    <Box
                      as="span"
                      className="StationTrafficControl__sectionMeta"
                      color={freeDocks ? 'good' : 'label'}
                      fontSize={0.9}
                      ml={1.5}
                    >
                      Свободно {freeDocks} из {docks.length}
                    </Box>
                  )}
                </>
              }
            >
              <DockInventory docks={docks} />
            </Section>
          </>
        )}
      </Window.Content>
    </Window>
  );
}
