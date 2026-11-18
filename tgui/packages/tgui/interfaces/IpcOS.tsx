import '../styles/interfaces/IpcOS.scss';

import { useEffect, useRef, useState } from 'react';
import {
  Box,
  Button,
  Icon,
  Input,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Program = {
  id: string;
  name: string;
  description: string;
  icon: string;
  size: number;
  illegal: BooleanLike;
  installed: BooleanLike;
  running: BooleanLike;
  passive: BooleanLike;
  ready: BooleanLike;
};

type Data = {
  programs: Program[];
  used: number;
  capacity: number;
  charge: number;
  error?: string;
  frequency: number;
  code: number;
  minFrequency: number;
  maxFrequency: number;
  temperature?: number;
  spoof_name?: string;
  spoof_job?: string;
  stunned?: BooleanLike;
  malware?: {
    id: string;
    name: string;
    os_curable: BooleanLike;
    treatments: number;
    cleaning?: BooleanLike;
    clean_seconds?: number;
    clean_duration?: number;
  }[];
  virus_choices?: { id: string; name: string }[];
  selected_virus?: string;
  armed?: BooleanLike;
  hijack_targets?: { ref: string; name: string; can_control: BooleanLike }[];
  can_manage?: BooleanLike;
  neural_available?: BooleanLike;
  neural_cooldown?: number;
  download_id?: string;
  download_progress?: number;
};

const virusDetails: Record<string, string> = {
  display_glitch:
    'Галлюцинации каждые 8–15 секунд. Очистка средствами ОС занимает 30 секунд.',
  sensor_noise:
    'При движении корпус может повернуть в сторону. Очистка средствами ОС занимает 60 секунд.',
  core_rot:
    'Блокирует ОС. Для удаления нужны пять успешных нейронных отладок мультитулом.',
  neural_hijack:
    'Удалённый перехват управления без ограничения расстояния и времени. Ваш корпус получает 5 ожогов каждые 2 секунды.',
};

type SystemApp = Pick<Program, 'id' | 'name' | 'icon' | 'description'> & {
  size?: never;
  illegal?: never;
};

const systemApps: SystemApp[] = [
  {
    id: 'net',
    name: 'NET',
    icon: 'download',
    description: 'Каталог программ и обновлений.',
  },
  {
    id: 'diagnostics',
    name: 'Диагностика',
    icon: 'heart-pulse',
    description: 'Состояние корпуса и очистка вредоносного ПО.',
  },
];

function AppWindow({
  name,
  icon,
  black,
  layer,
  raise,
  close,
  children,
}: {
  name: string;
  icon: string;
  black: boolean;
  layer: number;
  raise: () => void;
  close: () => void;
  children: React.ReactNode;
}) {
  const [position, setPosition] = useState(() => ({
    x: 24 + (layer % 6) * 22,
    y: 68 + (layer % 6) * 24,
  }));
  const drag = useRef<{ x: number; y: number } | null>(null);
  return (
    <dialog
      open
      aria-label={name}
      onPointerDownCapture={raise}
      onFocusCapture={raise}
      className={`IpcOS__window ${black ? 'IpcOS--black' : ''}`}
      style={{
        left: `clamp(0px, ${position.x}px, calc(100% - min(600px, 92%)))`,
        top: `clamp(32px, ${position.y}px, calc(100% - 44px))`,
        zIndex: 2 + layer,
      }}
    >
      <header
        onPointerDown={(event) => {
          if (
            event.button !== 0 ||
            (event.target as HTMLElement).closest('button')
          )
            return;
          const rect =
            event.currentTarget.parentElement!.getBoundingClientRect();
          drag.current = {
            x: event.clientX - rect.left,
            y: event.clientY - rect.top,
          };
          event.currentTarget.setPointerCapture(event.pointerId);
        }}
        onPointerMove={(event) => {
          if (drag.current)
            setPosition({
              x: event.clientX - drag.current.x,
              y: event.clientY - drag.current.y,
            });
        }}
        onLostPointerCapture={() => {
          drag.current = null;
        }}
      >
        <Icon name={icon} />
        <strong>{name}</strong>
        <button type="button" aria-label="Закрыть окно" onClick={close}>
          ×
        </button>
      </header>
      {children}
    </dialog>
  );
}

export const IpcOS = () => {
  const { act, data } = useBackend<Data>();
  const [selected, setSelected] = useState('net');
  const [windows, setWindows] = useState<string[]>([]);
  const openWindow = (id: string) =>
    setWindows((ids) =>
      ids[ids.length - 1] === id
        ? ids
        : [...ids.filter((entry) => entry !== id), id],
    );
  const installed = data.programs.filter((entry) => entry.installed);
  const apps: (SystemApp | Program)[] = [...systemApps, ...installed];
  const selection =
    apps.find((entry) => entry.id === selected) ?? systemApps[0];
  const system = !('size' in selection);
  const canManage = data.can_manage === undefined || Boolean(data.can_manage);
  const downloading = data.programs.find(
    (entry) => entry.id === data.download_id,
  );
  useEffect(() => {
    setWindows((ids) => {
      const valid = ids.filter(
        (id) =>
          systemApps.some((app) => app.id === id) ||
          data.programs.some((app) => app.id === id && app.installed),
      );
      return valid.length === ids.length ? ids : valid;
    });
  }, [data.programs]);
  const meters = (
    <div className="IpcOS__meters">
      <Icon name="hard-drive" /> Память{' '}
      <ProgressBar value={data.used / data.capacity}>
        {data.used} / {data.capacity} GB
      </ProgressBar>
      <Icon name="battery-half" /> Заряд{' '}
      <ProgressBar value={data.charge / 100}>{data.charge}%</ProgressBar>
    </div>
  );
  return (
    <Window width={840} height={610} theme="generic" title="Positronic OS">
      <Window.Content scrollable className="IpcOS">
        {meters}
        <div className="IpcOS__tab">
          <Icon name="desktop" /> Рабочий стол
        </div>
        {!!data.error && !windows.length && (
          <NoticeBox danger>{data.error}</NoticeBox>
        )}
        <div className="IpcOS__desktop">
          <div className="IpcOS__tiles">
            {apps.map((entry) => (
              <button
                type="button"
                key={entry.id}
                aria-label={entry.name}
                aria-pressed={entry.id === selection.id}
                className={`IpcOS__tile ${'illegal' in entry && entry.illegal ? 'IpcOS--black' : ''}`}
                onClick={() => setSelected(entry.id)}
              >
                {!('size' in entry) && (
                  <span className="IpcOS__gear" title="Системная программа">
                    <Icon name="gear" />
                  </span>
                )}
                <Icon name={entry.icon} size={2} />
                <span>{entry.name}</span>
              </button>
            ))}
          </div>
          <aside
            className={`IpcOS__details ${'illegal' in selection && selection.illegal ? 'IpcOS--black' : ''}`}
          >
            <div className="IpcOS__heading">
              <Icon name={selection.icon} size={2} />
              <strong>{selection.name}</strong>
              {system && <Icon name="gear" />}
            </div>
            {system ? (
              <p>{selection.description}</p>
            ) : (
              <p>{selection.size} GB</p>
            )}
            <dl className="IpcOS__facts">
              <dt>Статус</dt>
              <dd>
                {system || ('running' in selection && selection.running)
                  ? 'Онлайн'
                  : 'Офлайн'}
              </dd>
              <dt>Доступ</dt>
              <dd>{selection.illegal ? 'BlackWall' : 'WhiteWall'}</dd>
            </dl>
            <div className="IpcOS__actions">
              <Button
                fluid
                icon="up-right-from-square"
                onClick={() => openWindow(selection.id)}
              >
                Открыть
              </Button>
              {!system && (
                <Button
                  fluid
                  icon="trash"
                  disabled={!canManage}
                  onClick={() => act('uninstall', { id: selection.id })}
                >
                  Удалить
                </Button>
              )}
            </div>
          </aside>
        </div>
        {apps.map((app) => {
          const opened = app.id;
          const index = windows.indexOf(opened);
          if (index === -1) return null;
          const program = installed.find((entry) => entry.id === opened);
          return (
            <AppWindow
              key={opened}
              name={app.name}
              icon={app.icon}
              black={Boolean(program?.illegal)}
              layer={index}
              raise={() => openWindow(opened)}
              close={() =>
                setWindows((ids) => ids.filter((id) => id !== opened))
              }
            >
              {' '}
              <div className="IpcOS__body">
                {!!data.error && <NoticeBox danger>{data.error}</NoticeBox>}
                {program ? (
                  <>
                    <div className="IpcOS__summary">
                      <Icon name={program.icon} size={2} />
                      <div>{program.description}</div>
                    </div>
                    {program.id === 'overclock' && (
                      <Box mb={1}>
                        Нагрев: +12 K/с. Температура корпуса: {data.temperature}{' '}
                        °C.
                      </Box>
                    )}
                    {program.id === 'pda' && (
                      <Box mb={1}>
                        Хранилище КПК: 64 GQ. Приложения NT Software Hub
                        доступны по стартовой профессии.
                      </Box>
                    )}
                    {program.id === 'wall_breaker' && (
                      <Box mb={1}>
                        Подойдите к шлюзу и примените кабель питания.
                        Удерживайте соединение 13 секунд.
                      </Box>
                    )}
                    <Box color="label">Занимает {program.size} GB.</Box>
                    {program.ready ? (
                      <>
                        <Box my={1} color={program.running ? 'good' : 'label'}>
                          {program.running ? 'Работает' : 'Остановлена'}
                        </Box>
                        {!program.passive && (
                          <Button
                            icon={program.running ? 'stop' : 'play'}
                            disabled={!canManage}
                            onClick={() => act('toggle', { id: program.id })}
                          >
                            {program.running ? 'Остановить' : 'Запустить'}
                          </Button>
                        )}
                        {!!program.passive && (
                          <Box color="label">
                            Работает автоматически при включённой ОС.
                          </Box>
                        )}
                        {program.id === 'neural_crack' && (
                          <Box mt={1}>
                            <Button
                              icon="bolt"
                              disabled={!data.neural_available}
                              onClick={() => act('neural_crack')}
                            >
                              Снять оглушение
                            </Button>
                            {!!data.neural_cooldown && (
                              <Box mt={1}>Откат: {data.neural_cooldown} с.</Box>
                            )}
                            <Box color="label">
                              Во время стана используйте отдельную кнопку
                              NeuralCrack в HUD.
                            </Box>
                          </Box>
                        )}
                        {program.id === 'id_spoof' && (
                          <Section title="Отображаемая личность">
                            <Box mb={1}>
                              Имя{' '}
                              <Input
                                disabled={!canManage}
                                value={data.spoof_name ?? ''}
                                onBlur={(value) =>
                                  act('spoof_text', { field: 'name', value })
                                }
                              />
                            </Box>
                            <Box>
                              Должность{' '}
                              <Input
                                disabled={!canManage}
                                value={data.spoof_job ?? ''}
                                onBlur={(value) =>
                                  act('spoof_text', { field: 'job', value })
                                }
                              />
                            </Box>
                            <Box mt={1} color="label">
                              Только отображаемый текст. Реальные ID, доступы и
                              должность не меняются.
                            </Box>
                          </Section>
                        )}
                        {!!program.running && program.id === 'virus_kit' && (
                          <Section title="Передача вируса">
                            <div className="IpcOS__virus">
                              <div className="IpcOS__choices">
                                {(data.virus_choices ?? []).map((virus) => (
                                  <Button
                                    key={virus.id}
                                    disabled={!canManage}
                                    selected={data.selected_virus === virus.id}
                                    onClick={() =>
                                      act('virus_select', { id: virus.id })
                                    }
                                  >
                                    {virus.name}
                                  </Button>
                                ))}
                              </div>
                              <p>{virusDetails[data.selected_virus ?? '']}</p>
                            </div>
                            <Button
                              icon="plug"
                              disabled={!canManage}
                              color={data.armed ? 'bad' : undefined}
                              selected={data.armed}
                              onClick={() => act('virus_arm')}
                            >
                              {data.armed
                                ? 'Снять готовность'
                                : 'Подготовить передачу'}
                            </Button>
                            <Box my={1}>
                              Примените зарядный кабель к другому КПБ. Оба
                              должны оставаться неподвижны 10 секунд.
                            </Box>
                            {!!data.hijack_targets?.length && (
                              <Section title="NeuralHijack">
                                <Box mb={1}>
                                  Для возврата используйте кнопку завершения в
                                  HUD.
                                </Box>
                                {data.hijack_targets.map((target) => (
                                  <Button
                                    key={target.ref}
                                    icon="link"
                                    disabled={!canManage || !target.can_control}
                                    onClick={() =>
                                      act('hijack_start', { ref: target.ref })
                                    }
                                  >
                                    {target.name}
                                  </Button>
                                ))}
                              </Section>
                            )}
                          </Section>
                        )}
                        {!!program.running && program.id === 'pda' && (
                          <Button
                            icon="tablet"
                            disabled={!canManage}
                            onClick={() => act('pda_open')}
                          >
                            Открыть КПК
                          </Button>
                        )}
                        {!!program.running && program.id === 'signal_boost' && (
                          <Section title="Передатчик">
                            <Stack align="center">
                              <Stack.Item>Частота</Stack.Item>
                              <Stack.Item>
                                <NumberInput
                                  disabled={!canManage}
                                  value={data.frequency}
                                  minValue={data.minFrequency}
                                  maxValue={data.maxFrequency}
                                  step={2}
                                  onChange={(value) =>
                                    act('signal_freq', { value })
                                  }
                                />
                              </Stack.Item>
                              <Stack.Item>Код</Stack.Item>
                              <Stack.Item>
                                <NumberInput
                                  disabled={!canManage}
                                  value={data.code}
                                  minValue={1}
                                  maxValue={100}
                                  step={1}
                                  onChange={(value) =>
                                    act('signal_code', { value })
                                  }
                                />
                              </Stack.Item>
                              <Stack.Item>
                                <Button
                                  icon="satellite-dish"
                                  disabled={!canManage}
                                  onClick={() => act('signal_send')}
                                >
                                  Передать
                                </Button>
                              </Stack.Item>
                            </Stack>
                          </Section>
                        )}
                      </>
                    ) : (
                      <NoticeBox>Программа пока недоступна.</NoticeBox>
                    )}
                  </>
                ) : opened === 'diagnostics' ? (
                  <>
                    {meters}
                    <Box mb={1}>Температура тела: {data.temperature} °C</Box>
                    <Section title="Вредоносное ПО">
                      {!data.malware?.length && (
                        <Box color="good">Заражений не обнаружено.</Box>
                      )}
                      {(data.malware ?? []).map((infection) => (
                        <Section
                          key={infection.id}
                          title={infection.name}
                          buttons={
                            <Button
                              icon="shield-halved"
                              disabled={
                                !canManage ||
                                !infection.os_curable ||
                                Boolean(infection.cleaning)
                              }
                              onClick={() =>
                                act('cure_virus', { id: infection.id })
                              }
                            >
                              Удалить вирус
                            </Button>
                          }
                        >
                          {infection.cleaning ? (
                            <Box>
                              <Icon name="spinner" spin mr={1} />
                              Очистка: {infection.clean_seconds} с. Можно
                              передвигаться.
                            </Box>
                          ) : infection.os_curable ? (
                            `Очистка средствами ОС: ${infection.clean_duration ?? 0} с. Можно передвигаться.`
                          ) : (
                            `Требуется нейронная отладка мультитулом: ${infection.treatments}/5.`
                          )}
                        </Section>
                      ))}
                    </Section>
                  </>
                ) : (
                  <>
                    {downloading && (
                      <Section
                        title={downloading.name}
                        buttons={
                          <Button
                            disabled={!canManage}
                            onClick={() => act('cancel_download')}
                          >
                            Отменить
                          </Button>
                        }
                      >
                        <ProgressBar value={data.download_progress ?? 0}>
                          {Math.round((data.download_progress ?? 0) * 100)}%
                        </ProgressBar>
                      </Section>
                    )}
                    {[false, true].map((illegal) => (
                      <Section
                        key={String(illegal)}
                        className={illegal ? 'IpcOS--black' : undefined}
                        title={illegal ? 'Black Wall' : 'White Wall'}
                      >
                        {data.programs
                          .filter((entry) => Boolean(entry.illegal) === illegal)
                          .map((entry) => (
                            <Section
                              key={entry.id}
                              title={`${entry.name} · ${entry.size} GB`}
                              buttons={
                                <Button
                                  icon={entry.installed ? 'check' : 'download'}
                                  disabled={
                                    !canManage ||
                                    Boolean(data.download_id) ||
                                    entry.installed ||
                                    data.used + entry.size > data.capacity
                                  }
                                  onClick={() =>
                                    act('install', { id: entry.id })
                                  }
                                >
                                  {entry.installed
                                    ? 'Установлено'
                                    : 'Загрузить'}
                                </Button>
                              }
                            >
                              <Icon name={entry.icon} mr={1} />
                              {entry.description}
                            </Section>
                          ))}
                        {illegal &&
                          !data.programs.some((entry) => entry.illegal) && (
                            <Box color="label">
                              Каталог недоступен. Требуется нелегальное
                              обновление.
                            </Box>
                          )}
                      </Section>
                    ))}
                  </>
                )}
              </div>
            </AppWindow>
          );
        })}
      </Window.Content>
    </Window>
  );
};
