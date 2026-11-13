import { useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Input,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Tabs,
  TextArea,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { NtosWindow } from '../layouts';

type JournalRecord = {
  id: string;
  origin: string;
  observations: string[];
};

type Goal = {
  id: string;
  text: string;
  author: string;
  created: string;
  status: string;
  conclusion: string;
  records: string[];
};

type ContractStep = {
  text: string;
  progress: number;
  required: number;
  done: boolean;
  current: boolean;
};

type Contract = {
  id: string;
  name: string;
  customer: string;
  nanotrasen: boolean;
  state: string;
  target: string;
  x: number;
  y: number;
  reward: number;
  credits: number;
  decided_by: string | null;
  parent: string | null;
  steps: ContractStep[];
};

type Data = {
  records: JournalRecord[];
  goals: Goal[];
  contracts: Contract[];
  can_decide: boolean;
  connected: boolean;
};

const CONTRACT_STATES: Record<string, string> = {
  offered: 'Предложение',
  active: 'Выполняется',
  done: 'Выполнен',
  declined: 'Отклонён',
  expired: 'Снят',
  failed: 'Провален',
};

const STATUSES = {
  open: 'Открыта',
  done: 'Выполнена',
  failed: 'Не выполнена',
};

export const NtosExpeditionJournal = () => {
  const { data } = useBackend<Data>();
  const [tab, setTab] = useState(0);

  return (
    <NtosWindow width={600} height={640}>
      <NtosWindow.Content scrollable>
        <NoticeBox info={data.connected}>
          {data.connected
            ? 'Связь с архивом станции: записи синхронизированы.'
            : 'Нет связи со станцией: записи хранятся в памяти устройства и выгрузятся на станции.'}
        </NoticeBox>
        <Tabs>
          <Tabs.Tab
            icon="clipboard-list"
            selected={tab === 0}
            onClick={() => setTab(0)}
          >
            Задания
          </Tabs.Tab>
          <Tabs.Tab
            icon="bullseye"
            selected={tab === 1}
            onClick={() => setTab(1)}
          >
            Цели
          </Tabs.Tab>
          <Tabs.Tab
            icon="book"
            selected={tab === 2}
            onClick={() => setTab(2)}
          >
            Протоколы находок
          </Tabs.Tab>
        </Tabs>
        {tab === 0 && <Contracts />}
        {tab === 1 && <Goals />}
        {tab === 2 && <Records />}
      </NtosWindow.Content>
    </NtosWindow>
  );
};

const Goals = () => {
  const { act, data } = useBackend<Data>();
  const [text, setText] = useState('');

  const add = () => {
    if (!text.trim()) {
      return;
    }
    act('add_goal', { text });
    setText('');
  };

  return (
    <>
      <Section title="Новая цель">
        <Stack>
          <Stack.Item grow>
            <Input
              fluid
              maxLength={256}
              placeholder="Формулировка цели..."
              value={text}
              onChange={setText}
            />
          </Stack.Item>
          <Stack.Item>
            <Button onClick={add}>Добавить цель</Button>
          </Stack.Item>
        </Stack>
      </Section>
      {data.goals.length === 0 && <NoticeBox>Целей пока нет.</NoticeBox>}
      {data.goals.map((goal) => (
        <GoalSection key={goal.id} goal={goal} />
      ))}
    </>
  );
};

const GoalSection = (props: { goal: Goal }) => {
  const { act, data } = useBackend<Data>();
  const { goal } = props;
  const unlinked = data.records
    .map((record) => record.id)
    .filter((id) => !goal.records.includes(id));

  return (
    <Section
      title={`${goal.id}: ${goal.text}`}
      buttons={
        <Button icon="print" onClick={() => act('print', { goal: goal.id })}>
          Печать отчёта
        </Button>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Поставлена">
          {goal.created} — {goal.author}
        </LabeledList.Item>
        <LabeledList.Item label="Статус">
          {Object.entries(STATUSES).map(([key, label]) => (
            <Button
              key={key}
              selected={goal.status === key}
              onClick={() =>
                act('set_status', { goal: goal.id, status: key })
              }
            >
              {label}
            </Button>
          ))}
        </LabeledList.Item>
        <LabeledList.Item label="Протоколы">
          {goal.records.map((id) => (
            <Button
              key={id}
              icon="times"
              onClick={() =>
                act('unlink_record', { goal: goal.id, record: id })
              }
            >
              {id}
            </Button>
          ))}
          {unlinked.length > 0 && (
            <Dropdown
              placeholder="Привязать протокол..."
              selected=""
              options={unlinked}
              onSelected={(id) =>
                act('link_record', { goal: goal.id, record: id })
              }
            />
          )}
        </LabeledList.Item>
      </LabeledList>
      <Box mt={1}>
        <TextArea
          fluid
          height="80px"
          maxLength={1024}
          placeholder="Гипотезы и выводы..."
          value={goal.conclusion}
          onBlur={(value) =>
            value !== goal.conclusion &&
            act('set_conclusion', { goal: goal.id, text: value })
          }
        />
      </Box>
    </Section>
  );
};

const Contracts = () => {
  const { data } = useBackend<Data>();

  if (data.contracts.length === 0) {
    return <NoticeBox>Заказов пока нет.</NoticeBox>;
  }
  return (
    <>
      {data.contracts.map((contract) => (
        <ContractSection key={contract.id} contract={contract} />
      ))}
    </>
  );
};

const ContractSection = (props: { contract: Contract }) => {
  const { act, data } = useBackend<Data>();
  const { contract } = props;
  // A side task is taken with its order, but can be dropped on its own.
  const canAccept = contract.state === 'offered' && !contract.parent;
  const canDrop =
    contract.state === 'active' ||
    (contract.state === 'offered' && !contract.parent);

  return (
    <Section
      title={`${contract.id}: ${contract.name}${contract.parent ? ` (к ${contract.parent})` : ''}`}
      buttons={
        data.can_decide &&
        canDrop && (
          <>
            {canAccept && (
              <Button
                icon="check"
                color="good"
                onClick={() =>
                  act('accept_contract', { contract: contract.id })
                }
              >
                Принять
              </Button>
            )}
            <Button
              icon="times"
              color="bad"
              onClick={() => act('decline_contract', { contract: contract.id })}
            >
              Отказаться
            </Button>
          </>
        )
      }
    >
      <LabeledList>
        <LabeledList.Item label="Заказчик">
          {contract.customer}
          {contract.nanotrasen ? ' (заказ НТ)' : ' (контракт)'}
        </LabeledList.Item>
        <LabeledList.Item label="Объект">
          {contract.target} — координаты {contract.x}, {contract.y}
        </LabeledList.Item>
        <LabeledList.Item label="Статус">
          {CONTRACT_STATES[contract.state]}
          {contract.decided_by && ` — ${contract.decided_by}`}
        </LabeledList.Item>
        {contract.reward > 0 && (
          <LabeledList.Item label="Награда">
            {contract.reward} очков исследований станции
          </LabeledList.Item>
        )}
        {contract.credits > 0 && (
          <LabeledList.Item label="Награда">
            {contract.credits} кредитов в бюджет снабжения
          </LabeledList.Item>
        )}
      </LabeledList>
      <Box mt={1}>
        {contract.steps.map((step, index) => (
          <Box
            key={index}
            color={step.done ? 'good' : step.current ? 'average' : 'label'}
          >
            {step.done ? '✓' : step.current ? '▶' : '•'} {step.text} (
            {step.progress}/{step.required})
          </Box>
        ))}
      </Box>
    </Section>
  );
};

const Records = () => {
  const { data } = useBackend<Data>();

  if (data.records.length === 0) {
    return <NoticeBox>Протоколов пока нет.</NoticeBox>;
  }
  return (
    <>
      {data.records.map((record) => (
        <Section key={record.id} title={`Протокол ${record.id}`}>
          <Box color="label">Место обнаружения: {record.origin}</Box>
          {record.observations.map((line, index) => (
            <Box key={index}>{line}</Box>
          ))}
        </Section>
      ))}
    </>
  );
};
