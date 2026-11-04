import {
  Box,
  Button,
  Collapsible,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import { useBackend, useLocalState } from '../backend';
import { Window } from '../layouts';

type ObjectiveStatus = 'assigned' | 'accepted' | 'completed' | 'blocked';

type ThrallData = {
  name: string;
  ref: string;
  status: string;
  health: number;
  location: string;
  objective: string;
  has_mob: boolean;
  has_objective: boolean;
  objective_status: ObjectiveStatus;
  objective_revision: number;
  objective_reply: string;
};

type HiveEvent = {
  id: number;
  time: string;
  text: string;
  kind: 'info' | 'warning' | 'danger' | 'task';
};

type HivemindData = {
  can_manage: boolean;
  thralls: ThrallData[];
  thrall_count: number;
  events?: HiveEvent[];
};

const STATUS_COLORS: Record<string, string> = {
  Активен: 'good',
  Критическое: 'average',
  'Без сознания': 'yellow',
  Мёртв: 'bad',
};

const OBJECTIVE_STATUS = {
  assigned: { label: 'Поставлена', color: 'label' },
  accepted: { label: 'Принята', color: 'average' },
  completed: { label: 'Выполнена', color: 'good' },
  blocked: { label: 'Не могу выполнить', color: 'bad' },
} as const;

const EVENT_COLORS = {
  info: undefined,
  warning: 'average',
  danger: 'bad',
  task: undefined,
} as const;

export function KhaarootHivemind() {
  const { act, data } = useBackend<HivemindData>();
  const { can_manage, thralls = [], thrall_count, events = [] } = data;
  const [tab, setTab] = useLocalState('hivemindTab', 'thralls');

  return (
    <Box className="KhaarootHivemind">
      <Window width={620} height={500} title="Улей Кхаарут">
        <Window.Content scrollable>
          <Stack align="center" mb={1}>
            <Stack.Item grow>
              {can_manage ? `Заражённых: ${thrall_count}` : 'Личная цель'}
            </Stack.Item>
            <Stack.Item>
              <Button icon="sync" onClick={() => act('refresh')}>
                Обновить
              </Button>
            </Stack.Item>
          </Stack>
          {can_manage ? (
            <>
              <Tabs>
                <Tabs.Tab
                  icon="users"
                  selected={tab === 'thralls'}
                  onClick={() => setTab('thralls')}
                >
                  Участники
                </Tabs.Tab>
                <Tabs.Tab
                  icon="list"
                  selected={tab === 'events'}
                  onClick={() => setTab('events')}
                >
                  События
                </Tabs.Tab>
              </Tabs>
              {tab === 'events' ? (
                <Section title="Последние события">
                  {events.length === 0 ? (
                    <NoticeBox>В улье пока нет событий.</NoticeBox>
                  ) : (
                    <LabeledList>
                      {events.map((event) => (
                        <LabeledList.Item key={event.id} label={event.time}>
                          <Box
                            color={EVENT_COLORS[event.kind]}
                            style={{
                              whiteSpace: 'pre-wrap',
                              overflowWrap: 'anywhere',
                            }}
                          >
                            {event.text}
                          </Box>
                        </LabeledList.Item>
                      ))}
                    </LabeledList>
                  )}
                </Section>
              ) : thralls.length === 0 ? (
                <NoticeBox>Нет заражённых в улье.</NoticeBox>
              ) : (
                thralls.map((thrall) => (
                  <ThrallDetails key={thrall.ref} thrall={thrall} />
                ))
              )}
            </>
          ) : (
            <MemberObjective thrall={thralls[0]} />
          )}
        </Window.Content>
      </Window>
    </Box>
  );
}

function ThrallDetails(props: { thrall: ThrallData }) {
  const { thrall } = props;
  const { act } = useBackend<HivemindData>();

  return (
    <Section>
      <Box bold fontSize="1.2rem" mb={1} style={{ overflowWrap: 'anywhere' }}>
        {thrall.name}
      </Box>
      <LabeledList>
        <LabeledList.Item label="Статус" color={STATUS_COLORS[thrall.status]}>
          {thrall.status}
        </LabeledList.Item>
        <LabeledList.Item label="Здоровье">
          {thrall.has_mob ? (
            <ProgressBar
              value={Math.max(0, Math.min(1, thrall.health / 100))}
              ranges={{
                good: [0.7, 1],
                average: [0.4, 0.7],
                bad: [0, 0.4],
              }}
            >
              {thrall.health}%
            </ProgressBar>
          ) : (
            'Нет тела'
          )}
        </LabeledList.Item>
        <LabeledList.Item label="Локация">
          <Box style={{ overflowWrap: 'anywhere' }}>{thrall.location}</Box>
        </LabeledList.Item>
      </LabeledList>
      <Box mt={1}>
        <ObjectiveDetails thrall={thrall} />
      </Box>
      <Box mt={1}>
        <Button
          icon="comment"
          disabled={!thrall.has_mob}
          onClick={() => act('send_command', { ref: thrall.ref })}
        >
          Команда
        </Button>
        <Button
          icon="bullseye"
          onClick={() => act('set_objective', { ref: thrall.ref })}
        >
          Назначить цель
        </Button>
      </Box>
      <Collapsible title="Подробности" mt={1}>
        <Button
          icon="skull"
          color="bad"
          disabled={!thrall.has_mob || thrall.status === 'Мёртв'}
          tooltip="Необратимое действие. Потребуется подтверждение."
          onClick={() => act('kill_thrall', { ref: thrall.ref })}
        >
          Умертвить
        </Button>
      </Collapsible>
    </Section>
  );
}

function ObjectiveDetails(props: { thrall: ThrallData }) {
  const { thrall } = props;
  const status = OBJECTIVE_STATUS[thrall.objective_status];

  if (!thrall.has_objective) {
    return <Box color="label">Источник пока не назначил цель.</Box>;
  }

  return (
    <LabeledList>
      <LabeledList.Item label="Цель">
        <Box style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>
          {thrall.objective}
        </Box>
      </LabeledList.Item>
      <LabeledList.Item label="Состояние" color={status.color}>
        {status.label}
      </LabeledList.Item>
      {!!thrall.objective_reply && (
        <LabeledList.Item label="Причина">
          <Box style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>
            {thrall.objective_reply}
          </Box>
        </LabeledList.Item>
      )}
    </LabeledList>
  );
}

function MemberObjective(props: { thrall?: ThrallData }) {
  const { thrall } = props;
  const { act } = useBackend<HivemindData>();

  if (!thrall?.has_objective) {
    return <NoticeBox>Источник пока не назначил вам цель.</NoticeBox>;
  }

  const respond = (status: ObjectiveStatus) =>
    act('respond_objective', {
      status,
      revision: thrall.objective_revision,
    });

  return (
    <Section title="Ваша цель">
      <ObjectiveDetails thrall={thrall} />
      <Box mt={2}>
        {(thrall.objective_status === 'assigned' ||
          thrall.objective_status === 'blocked') && (
          <Button icon="check" onClick={() => respond('accepted')}>
            Принять
          </Button>
        )}
        {thrall.objective_status === 'accepted' && (
          <Button
            icon="flag-checkered"
            color="good"
            onClick={() => respond('completed')}
          >
            Выполнена
          </Button>
        )}
        {(thrall.objective_status === 'assigned' ||
          thrall.objective_status === 'accepted') && (
          <Button
            icon="ban"
            onClick={() => respond('blocked')}
            tooltip="Можно указать причину. Отмена оставит ответ без изменений."
          >
            Не могу выполнить
          </Button>
        )}
      </Box>
      {thrall.objective_status === 'assigned' && (
        <Box mt={1} color="label">
          Чтобы отметить выполнение, сначала примите цель.
        </Box>
      )}
    </Section>
  );
}
