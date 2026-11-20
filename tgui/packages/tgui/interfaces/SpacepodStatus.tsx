import type { ReactNode } from 'react';
import { AnimatedNumber, Button, Icon, ProgressBar } from 'tgui-core/components';
import { classes } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type SpacepodStatusData = {
  name: string;
  battery_present: boolean;
  charge_percent: number | null;
  integrity_percent: number | null;
  cabin_oxygen_kpa: number | null;
  cabin_oxygen_liters: number | null;
  cabin_pressure_kpa: number | null;
  active_oxygen_kpa: number | null;
  tank_pressure_kpa: number | null;
  using_internal_air: boolean;
  cabin_temperature_k: number | null;
  lights_on: boolean;
  locked: boolean;
  occupant_count: number;
  occupant_capacity: number;
  pilot_controls: boolean;
  turbo: boolean;
  parking: boolean;
  parked: boolean;
  passengers: { name: string; ref: string }[];
};

const MINIMUM_OXYGEN_KPA = 16;
const formatReading = (value: number, digits = 1) =>
  value.toFixed(digits).replace('.', ',');

const Reading = (props: { value: number | null; unit?: string }) => (
  <>
    {props.value !== null && Number.isFinite(props.value) ? (
      <AnimatedNumber value={props.value} format={formatReading} />
    ) : (
      '—'
    )}
    {props.unit && <span className="SpacepodStatus__unit">{props.unit}</span>}
  </>
);

export const SpacepodStatus = () => {
  const { act, data } = useBackend<SpacepodStatusData>();
  const oxygenLow =
    data.active_oxygen_kpa !== null &&
    data.active_oxygen_kpa < MINIMUM_OXYGEN_KPA;
  const hullCritical =
    data.integrity_percent !== null && data.integrity_percent <= 25;
  const batteryLow =
    !data.battery_present ||
    (data.charge_percent !== null && data.charge_percent <= 20);
  const alerts = [
    oxygenLow && 'Недостаточно кислорода в выбранном источнике воздуха.',
    hullCritical && 'Критические повреждения корпуса.',
    !data.battery_present
      ? 'Батарея не установлена.'
      : batteryLow && 'Низкий заряд батареи.',
  ].filter(Boolean);

  return (
    <Window
      title="Состояние челнока"
      width={760}
      height={650}
      theme="ntos_darkmode"
    >
      <Window.Content fitted scrollable className="SpacepodStatus">
        <div className="SpacepodStatus__dashboard">
          <header className="SpacepodStatus__header">
            <div>
              <div className="SpacepodStatus__eyebrow">БОРТОВАЯ ТЕЛЕМЕТРИЯ</div>
              <h1>{data.name}</h1>
            </div>
            <div
              className={classes([
                'SpacepodStatus__badge',
                alerts.length > 0 && 'SpacepodStatus__badge--alert',
              ])}
            >
              <Icon
                name={alerts.length ? 'triangle-exclamation' : 'satellite-dish'}
              />
              {alerts.length ? 'Требует внимания' : 'Текущие показатели'}
            </div>
          </header>

          {data.pilot_controls && (
            <section aria-label="Управление челноком">
              <Button
                icon="square-parking"
                selected={data.parking}
                tooltip="Гасит движение и вращение. После остановки фиксирует челнок и освобождает руки пилота."
                onClick={() => act('parking')}
              >
                {data.parked
                  ? 'Снять с парковки'
                  : data.parking
                    ? 'Отменить парковку'
                    : 'Парковка'}
              </Button>
              <Button
                icon="gauge-high"
                selected={data.turbo}
                disabled={data.parking}
                tooltip="Удваивает скорость и ускорение. Тяга расходует вдвое больше заряда."
                onClick={() => act('turbo')}
              >
                Турбо
              </Button>
              <Button
                icon={data.locked ? 'lock-open' : 'lock'}
                onClick={() => act('lock')}
              >
                {data.locked ? 'Разблокировать двери' : 'Заблокировать двери'}
              </Button>
              <Button icon="door-open" onClick={() => act('doors')}>
                Шлюз отсека
              </Button>
              <Button icon="box" onClick={() => act('unload')}>
                Сбросить груз
              </Button>
              <Button icon="chair" onClick={() => act('check_seat')}>
                Проверить под сиденьем
              </Button>
              <Button icon="satellite-dish" onClick={() => act('scan')}>
                Сканировать сектор
              </Button>
              {data.passengers.map((passenger) => (
                <Button.Confirm
                  key={passenger.ref}
                  icon="person-walking-arrow-right"
                  confirmContent="Подтвердить высадку"
                  onClick={() =>
                    act('eject_passenger', { passenger: passenger.ref })
                  }
                >
                  Высадить: {passenger.name}
                </Button.Confirm>
              ))}
            </section>
          )}

          <div className="SpacepodStatus__overview">
            <div className="SpacepodStatus__systems">
              <SystemCard
                label="Батарея"
                icon="bolt"
                value={data.battery_present ? data.charge_percent : null}
                alert={batteryLow}
                note={
                  data.battery_present ? 'Оставшийся заряд' : 'Не установлена'
                }
              />
              <SystemCard
                label="Корпус"
                icon="shield-halved"
                value={data.integrity_percent}
                alert={hullCritical}
                note="Остаточная прочность"
              />
            </div>

            <div className="SpacepodStatus__schematic">
              <span className="SpacepodStatus__eyebrow">СХЕМА КОРПУСА</span>
              <PodSchematic damaged={hullCritical} />
              <span className="SpacepodStatus__schematicCaption">
                Вид сверху
              </span>
            </div>

            <section
              className={classes([
                'SpacepodStatus__oxygen',
                data.cabin_oxygen_kpa !== null &&
                  data.cabin_oxygen_kpa < MINIMUM_OXYGEN_KPA &&
                  'SpacepodStatus__oxygen--low',
              ])}
              aria-label="Кислород в салоне"
            >
              <div className="SpacepodStatus__label">
                <Icon name="wind" /> Кислород салона
              </div>
              <div className="SpacepodStatus__oxygenValue">
                <Reading value={data.cabin_oxygen_liters} unit="л O₂" />
              </div>
              <div className="SpacepodStatus__standard">
                Объём при 20 °C и 1 атм
              </div>
              <div className="SpacepodStatus__oxygenPressure">
                <span>Парциальное давление O₂</span>
                <strong>
                  <Reading value={data.cabin_oxygen_kpa} unit="кПа" />
                </strong>
              </div>
              <div className="SpacepodStatus__oxygenNote">
                Запас воздуха в салоне, отдельно от резервного баллона.
              </div>
            </section>
          </div>

          <div className="SpacepodStatus__metrics">
            <Metric label="Давление салона" icon="gauge-high">
              <Reading value={data.cabin_pressure_kpa} unit="кПа" />
            </Metric>
            <Metric label="Резервный баллон" icon="database">
              <Reading value={data.tank_pressure_kpa} unit="кПа" />
            </Metric>
            <Metric label="Температура салона" icon="temperature-half">
              <Reading
                value={
                  data.cabin_temperature_k === null
                    ? null
                    : data.cabin_temperature_k - 273.15
                }
                unit="°C"
              />
            </Metric>
            <Metric label="На борту" icon="user-group">
              {data.occupant_count}
              <span className="SpacepodStatus__capacity">
                {' '}
                / {data.occupant_capacity}
              </span>
            </Metric>
          </div>

          <section
            className={classes([
              'SpacepodStatus__airSource',
              oxygenLow && 'SpacepodStatus__airSource--alert',
            ])}
            aria-label="Выбранный источник воздуха"
          >
            <div className="SpacepodStatus__sourceIcon">
              <Icon
                name={
                  data.using_internal_air
                    ? 'arrows-spin'
                    : 'arrow-up-right-from-square'
                }
              />
            </div>
            <div className="SpacepodStatus__sourceName">
              <span className="SpacepodStatus__label">Подача воздуха</span>
              <strong>
                {data.using_internal_air ? 'Из салона' : 'Снаружи'}
              </strong>
            </div>
            <div className="SpacepodStatus__activeOxygen">
              <span className="SpacepodStatus__label">
                O₂ в выбранном источнике
              </span>
              <strong>
                <Reading value={data.active_oxygen_kpa} unit="кПа" />
              </strong>
            </div>
            {oxygenLow && <Icon name="triangle-exclamation" size={1.5} />}
          </section>

          {alerts.length > 0 && (
            <div className="SpacepodStatus__alerts" role="status">
              <Icon name="triangle-exclamation" />
              <span>{alerts.join(' ')}</span>
            </div>
          )}

          <footer className="SpacepodStatus__footer">
            <span>
              <Icon name={data.lights_on ? 'lightbulb' : 'moon'} /> Свет{' '}
              {data.lights_on ? 'включён' : 'выключен'}
            </span>
            <span>
              <Icon name={data.locked ? 'lock' : 'lock-open'} />{' '}
              {data.locked ? 'Доступ закрыт' : 'Доступ открыт'}
            </span>
            {data.parking && (
              <span>
                <Icon name="square-parking" />{' '}
                {data.parked ? 'Припаркован' : 'Торможение'}
              </span>
            )}
          </footer>
        </div>
      </Window.Content>
    </Window>
  );
};

const SystemCard = (props: {
  label: string;
  icon: string;
  value: number | null;
  alert: boolean;
  note: string;
}) => (
  <section
    className={classes([
      'SpacepodStatus__system',
      props.alert && 'SpacepodStatus__system--alert',
    ])}
  >
    <div className="SpacepodStatus__label">
      <Icon name={props.icon} /> {props.label}
    </div>
    <div className="SpacepodStatus__systemValue">
      <Reading value={props.value} unit="%" />
    </div>
    <ProgressBar
      className="SpacepodStatus__progress"
      value={props.value ?? 0}
      maxValue={100}
      color={props.alert ? '#f16baa' : '#61def2'}
      empty
    />
    <div className="SpacepodStatus__systemNote">{props.note}</div>
  </section>
);

const Metric = (props: {
  label: string;
  icon: string;
  children: ReactNode;
}) => (
  <section className="SpacepodStatus__metric">
    <div className="SpacepodStatus__label">
      <Icon name={props.icon} /> {props.label}
    </div>
    <div className="SpacepodStatus__metricValue">{props.children}</div>
  </section>
);

const PodSchematic = (props: { damaged: boolean }) => (
  <svg
    className={classes([
      'SpacepodStatus__pod',
      props.damaged && 'SpacepodStatus__pod--damaged',
    ])}
    viewBox="0 0 320 300"
    role="img"
    aria-label="Схема корпуса космического челнока, вид сверху"
  >
    <g className="SpacepodStatus__guides">
      <path d="M160 12V288M22 150H298" strokeDasharray="3 7" />
      <circle cx="160" cy="150" r="112" strokeDasharray="2 9" />
      <path d="M22 54V26H50M270 26H298V54M22 246V274H50M270 274H298V246" />
    </g>
    <g className="SpacepodStatus__hull">
      <path d="M117 41H203L239 80V205L211 252H109L81 205V80Z" />
      <path d="M119 55H201L225 85V201L202 238H118L95 201V85Z" />
      <path d="M81 96H62L49 113V218L62 234H96M239 96H258L271 113V218L258 234H224" />
      <path d="M62 108V214H88M258 108V214H232M49 136H81M49 184H81M239 136H271M239 184H271" />
      <path d="M109 252V266H137V252M183 252V266H211V252M112 62L130 82M208 62L190 82" />
      <path d="M95 176L119 190H201L225 176M118 238L129 213H191L202 238M129 213V190M191 213V190" />
    </g>
    <g className="SpacepodStatus__cabin">
      <path d="M130 82H190L207 102V159L192 176H128L113 159V102Z" />
      <path d="M130 82L136 99H184L190 82M113 116H207M160 99V164M128 176L138 158H182L192 176" />
      <path d="M129 129H146V150H129ZM174 129H191V150H174Z" />
    </g>
    <g className="SpacepodStatus__details">
      <path d="M105 202H115M205 202H215M145 225H175M145 230H175M62 119V127M258 119V127" />
      <path d="M87 85H56L41 70H22M233 85H264L279 70H298M89 219H64L45 247H22M231 219H256L275 247H298" />
      <circle cx="87" cy="85" r="3" />
      <circle cx="233" cy="85" r="3" />
      <circle cx="89" cy="219" r="3" />
      <circle cx="231" cy="219" r="3" />
    </g>
  </svg>
);
