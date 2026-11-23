import {
  Box,
  Button,
  Icon,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  anchor: [number, number, number] | null;
  can_configure: BooleanLike;
  can_register: BooleanLike;
  can_rename: BooleanLike;
  configured: BooleanLike;
  dock_class: string;
  dock_name: string;
  facing: number;
  hangar: BooleanLike;
  height: number;
  layout_key: string;
  offset: number;
  registered: BooleanLike;
  retiring: BooleanLike;
  status: string;
  width: number;
  report?: {
    layout_key: string;
    message: string;
    failed: BooleanLike;
  };
};

const directions = {
  1: { label: 'Север', angle: 0 },
  2: { label: 'Юг', angle: 180 },
  4: { label: 'Восток', angle: 90 },
  8: { label: 'Запад', angle: -90 },
} as const;

export function DockController() {
  const { act, data } = useBackend<Data>();
  const {
    anchor,
    can_configure,
    can_register,
    can_rename,
    configured,
    dock_class,
    dock_name,
    facing,
    hangar,
    height,
    layout_key,
    offset,
    registered,
    report,
    retiring,
    status,
    width,
  } = data;
  const direction = directions[facing as keyof typeof directions];
  const maxOffset = height - 1;
  const command = (action: string) => act(action, { layout_key });
  const setOffset = (value: number) => act('set_offset', { layout_key, value });
  const currentReport = report?.layout_key === layout_key ? report : null;

  return (
    <Window
      title={hangar ? 'Контроллер ангара' : 'Контроллер причала'}
      width={540}
      height={450}
    >
      <Window.Content scrollable>
        <style>{styles}</style>
        <Section
          className="DockController__header"
          title={dock_name}
          buttons={
            !!can_rename && (
              <Button icon="pen" onClick={() => command('rename')}>
                Переименовать
              </Button>
            )
          }
        >
          <Box color={retiring ? 'average' : registered ? 'good' : undefined}>
            {status}
          </Box>
        </Section>
        <div className="DockController__layout">
          <Section
            className="DockController__header"
            title={hangar ? 'Настил ангара' : `Площадка ${dock_class}`}
            buttons={
              <Box bold>
                {width} × {height}
              </Box>
            }
          >
            <DockPlan
              angle={direction?.angle ?? 0}
              hangar={!!hangar}
              height={height}
              offset={offset}
              width={width}
            />
          </Section>
          <Section title="Настройки площадки" fill>
            <Box color="label">Направление</Box>
            <Stack align="center" mt={0.5} mb={1.5}>
              <Stack.Item grow>
                <Icon name="compass" mr={0.5} aria-hidden="true" />
                <Box as="span" bold>
                  {direction?.label ?? 'Не задано'}
                </Box>
              </Stack.Item>
              {!!can_configure && (
                <Stack.Item>
                  <Button icon="rotate-right" onClick={() => command('rotate')}>
                    Повернуть
                  </Button>
                </Stack.Item>
              )}
            </Stack>
            <Box color="label">Офсет вдоль {hangar ? 'края' : 'стены'}</Box>
            {can_configure ? (
              <>
                <Stack align="center" mt={0.5}>
                  <Stack.Item>
                    <button
                      type="button"
                      className="DockController__step"
                      aria-label="Уменьшить офсет"
                      disabled={offset <= 0}
                      onClick={() => setOffset(offset - 1)}
                    >
                      <Icon name="minus" />
                    </button>
                  </Stack.Item>
                  <Stack.Item>
                    <NumberInput
                      value={offset}
                      minValue={0}
                      maxValue={maxOffset}
                      step={1}
                      width={3}
                      onChange={setOffset}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <button
                      type="button"
                      className="DockController__step"
                      aria-label="Увеличить офсет"
                      disabled={offset >= maxOffset}
                      onClick={() => setOffset(offset + 1)}
                    >
                      <Icon name="plus" />
                    </button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button disabled={!offset} onClick={() => setOffset(0)}>
                      Сбросить
                    </Button>
                  </Stack.Item>
                </Stack>
                <Box color="label" mt={0.5}>
                  0–{maxOffset} клеток
                </Box>
              </>
            ) : (
              <>
                <Box bold mt={0.5}>
                  {offset} кл.
                </Box>
                <Box color="label" mt={0.5}>
                  {configured
                    ? 'Офсет задан на карте.'
                    : registered
                      ? 'Чтобы изменить офсет, снимите площадку с регистрации.'
                      : 'Закрепите контроллер для настройки.'}
                </Box>
              </>
            )}
            <Box color="label" mt={1.5}>
              Начальный угол площадки
            </Box>
            <Box className="DockController__coordinates" mt={0.5}>
              {anchor ? `(${anchor.join(', ')})` : 'За пределами палубы'}
            </Box>
          </Section>
        </div>
        <Section>
          <Stack align="center" wrap="wrap">
            <Stack.Item>
              <Button icon="layer-group" onClick={() => command('preview')}>
                Подсветить на карте
              </Button>
            </Stack.Item>
            <Stack.Item grow>
              <Button icon="clipboard-check" onClick={() => command('check')}>
                Проверить площадку
              </Button>
            </Stack.Item>
            <Stack.Item>
              {registered ? (
                <Button.Confirm
                  icon="ban"
                  disabled={!!retiring}
                  confirmContent="Закрыть новые заходы?"
                  onClick={() => command('retire')}
                >
                  Снять с регистрации
                </Button.Confirm>
              ) : (
                <Button
                  color="good"
                  icon="check"
                  disabled={!can_register}
                  onClick={() => command('register')}
                >
                  Зарегистрировать
                </Button>
              )}
            </Stack.Item>
          </Stack>
          {currentReport && (
            <div className="DockController__report" role="status">
              <NoticeBox
                {...(currentReport.failed ? { danger: true } : { info: true })}
              >
                {currentReport.message}
              </NoticeBox>
            </div>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
}

function DockPlan({
  angle,
  hangar,
  height,
  offset,
  width,
}: {
  angle: number;
  hangar: boolean;
  height: number;
  offset: number;
  width: number;
}) {
  const columns = width + (hangar ? 1 : 4);
  const cellSize = Math.max(
    1,
    Math.min(10, Math.floor(156 / Math.max(columns, height))),
  );
  const consoleRow = height - offset;

  return (
    <>
      <div className="DockController__canvas" aria-hidden="true">
        <span className="DockController__north">С</span>
        <div
          className="DockController__plan"
          style={{
            gridTemplateColumns: `repeat(${columns}, ${cellSize}px)`,
            gridTemplateRows: `repeat(${height}, ${cellSize}px)`,
            transform: `rotate(${angle}deg)`,
            backgroundSize: `${cellSize}px ${cellSize}px`,
          }}
        >
          <span
            className="DockController__hull"
            style={{ gridArea: `1 / 1 / -1 / ${width + 1}` }}
          />
          {!hangar && (
            <>
              <span
                className="DockController__gangway"
                style={{ gridArea: `1 / ${width + 1} / -1 / ${width + 2}` }}
              />
              <span
                className="DockController__wall"
                style={{ gridArea: `1 / ${width + 2} / -1 / ${width + 3}` }}
              />
            </>
          )}
          <span
            className="DockController__origin"
            style={{ gridArea: `${height} / 1` }}
          />
          {consoleRow >= 1 && consoleRow <= height && (
            <span
              className="DockController__console"
              style={{ gridArea: `${consoleRow} / ${columns}` }}
            />
          )}
        </div>
      </div>
      <div className="DockController__legend">
        <span>
          <i className="DockController__hull" />
          {hangar ? 'Настил' : 'Корпус'}
        </span>
        {!hangar && (
          <>
            <span>
              <i className="DockController__gangway" />
              Трап
            </span>
            <span>
              <i className="DockController__wall" />
              Стена
            </span>
          </>
        )}
        <span>
          <i className="DockController__origin" />
          Угол
        </span>
        <span>
          <i className="DockController__console" />
          Консоль
        </span>
      </div>
    </>
  );
}

const styles = `
  .DockController__header > .Section__title {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.6rem;
  }
  .DockController__header > .Section__title > .Section__titleText {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .DockController__header > .Section__title > .Section__buttons {
    position: static;
    margin-top: 0;
    flex-shrink: 0;
  }
  .DockController__layout {
    display: grid;
    grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr);
    gap: 0.5rem;
    margin-bottom: 0.5rem;
  }
  .DockController__layout > .Section { margin-bottom: 0; }
  .DockController__step {
    width: 2.2rem;
    height: 2rem;
    color: inherit;
    background-color: #334a5c;
    border: 1px solid #587286;
    cursor: pointer;
  }
  .DockController__step:hover:not(:disabled) { background-color: #436176; }
  .DockController__step:focus-visible { outline: 2px solid #e6f2fa; outline-offset: 1px; }
  .DockController__step:disabled { opacity: 0.45; cursor: default; }
  .DockController__report { margin-top: 0.5rem; }
  .DockController__canvas {
    position: relative;
    display: grid;
    place-items: center;
    height: 176px;
    background: #111d27;
    border: 1px solid #374c5c;
  }
  .DockController__north {
    position: absolute;
    top: 0.45rem;
    left: 0.55rem;
    color: #c8d9e2;
    font-weight: 600;
  }
  .DockController__plan {
    display: grid;
    background-image: linear-gradient(#647b8c54 1px, transparent 1px),
      linear-gradient(90deg, #647b8c54 1px, transparent 1px);
    outline: 1px solid #647b8c70;
  }
  .DockController__hull { background: #56bba74a; box-shadow: inset 0 0 0 1px #68c6b4; }
  .DockController__gangway { background: #5eabebb3; }
  .DockController__wall { background: #e28e80; }
  .DockController__origin { background: #ecf4f8; }
  .DockController__console { background: #ffd08b; }
  .DockController__legend {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem 0.6rem;
    margin-top: 0.5rem;
  }
  .DockController__legend i { display: inline-block; width: 0.65rem; height: 0.65rem; margin-right: 0.25rem; }
  .DockController__coordinates { font-variant-numeric: tabular-nums; }
  @media (max-width: 420px) {
    .DockController__layout { grid-template-columns: minmax(0, 1fr); }
  }
`;
