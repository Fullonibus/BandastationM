import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Table,
} from 'tgui-core/components';
import { toFixed } from 'tgui-core/math';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Specimen = {
  ref: string;
  name: string;
  generation: number;
  stage: string;
  health: number;
  max_health: number;
  nutrition: number;
  alive: BooleanLike;
  stasis: BooleanLike;
};

type Candidate = Pick<Specimen, 'ref' | 'name' | 'generation' | 'stage' | 'alive'>;

type TreatmentStatus =
  | 'empty'
  | 'dead'
  | 'offline'
  | 'inactive'
  | 'healthy'
  | 'no_medicine'
  | 'treating';

type Data = {
  specimen: Specimen | null;
  candidates: Candidate[];
  operational: BooleanLike;
  medicine_amount: number;
  total_volume: number;
  capacity: number;
  treatment_status: TreatmentStatus;
  goal_active: BooleanLike;
  fiber_delivered: number;
  fiber_target: number;
};

const treatmentStates: Record<TreatmentStatus, { label: string; color: string }> = {
  empty: { label: 'Нет образца для лечения', color: 'label' },
  dead: { label: 'Образец погиб — восстановление невозможно', color: 'bad' },
  offline: { label: 'Капсула не работает — лечение приостановлено', color: 'bad' },
  inactive: { label: 'Стазис не действует — лечение приостановлено', color: 'bad' },
  healthy: { label: 'Образец здоров — лекарство не расходуется', color: 'good' },
  no_medicine: { label: 'Нет либитала — лечение приостановлено', color: 'average' },
  treating: { label: 'Идёт восстановление образца', color: 'good' },
};

export const PhoenixCapsule = () => {
  const { act, data } = useBackend<Data>();
  const { specimen, candidates = [], operational } = data;
  const treatment = treatmentStates[data.treatment_status];
  const otherReagents = Math.max(0, data.total_volume - data.medicine_amount);
  const healthFraction = specimen ? specimen.health / specimen.max_health : 0;
  const healthColor =
    !specimen?.alive || healthFraction <= 0.3
      ? 'bad'
      : healthFraction < 0.8
        ? 'average'
        : 'good';

  return (
    <Window width={520} height={650}>
      <Window.Content scrollable>
        <Section
          title="Архивный образец"
          buttons={
            specimen && (
              <Button
                icon="sign-out-alt"
                disabled={!operational}
                tooltip="Перед пробуждением подготовьте безопасный вольер"
                onClick={() => act('release', { specimen: specimen.ref })}
              >
                {specimen.alive ? 'Пробудить' : 'Извлечь'}
              </Button>
            )
          }
        >
          {specimen ? (
            <>
              <LabeledList>
                <LabeledList.Item label="Особь">{specimen.name}</LabeledList.Item>
                <LabeledList.Item label="Поколение">
                  {specimen.generation === 0
                    ? '0 — архивный основатель'
                    : specimen.generation}
                </LabeledList.Item>
                <LabeledList.Item label="Стадия">{specimen.stage}</LabeledList.Item>
                <LabeledList.Item label="Стазис" color={specimen.stasis ? 'good' : 'bad'}>
                  {specimen.stasis ? 'Активен' : 'Не действует'}
                </LabeledList.Item>
                <LabeledList.Item label="Здоровье">
                  <ProgressBar
                    value={specimen.health}
                    minValue={0}
                    maxValue={specimen.max_health}
                    color={healthColor}
                  >
                    {Math.round(Math.max(0, 100 * healthFraction))}%
                  </ProgressBar>
                </LabeledList.Item>
                <LabeledList.Item label="Запас питания">
                  <ProgressBar
                    value={specimen.nutrition}
                    minValue={0}
                    maxValue={100}
                    color={specimen.nutrition < 25 ? 'average' : 'good'}
                  >
                    {Math.round(specimen.nutrition)}%
                  </ProgressBar>
                </LabeledList.Item>
              </LabeledList>
              <Box color="label" mt={1}>
                Стазис останавливает рост, размножение и производство волокна.
                Лечение продолжает работать.
              </Box>
            </>
          ) : (
            <>
              <NoticeBox info>Капсула пуста</NoticeBox>
              <Box color="label" mb={1}>
                Подведите ткача к капсуле и выберите особь для сохранения.
              </Box>
              {candidates.length > 0 ? (
                <Table>
                  {candidates.map((candidate) => (
                    <Table.Row key={candidate.ref}>
                      <Table.Cell py={0.5}>
                        <Box>{candidate.name}</Box>
                        <Box color="label" fontSize="0.9em">
                          Поколение {candidate.generation}
                          {!candidate.alive && ' · погибшая особь'}
                        </Box>
                      </Table.Cell>
                      <Table.Cell collapsing>
                        <Button
                          icon="snowflake"
                          disabled={!operational}
                          onClick={() => act('preserve', { specimen: candidate.ref })}
                        >
                          Сохранить
                        </Button>
                      </Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              ) : (
                <Box color="label">Рядом нет доступных особей</Box>
              )}
            </>
          )}
        </Section>
        <Section title="Лечение и резервуар">
          <NoticeBox color={treatment.color}>{treatment.label}</NoticeBox>
          <LabeledList>
            <LabeledList.Item label="Либитал">
              <Box bold color={data.medicine_amount > 0 ? 'good' : 'average'}>
                {toFixed(data.medicine_amount, 1)} ед.
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Заполнение">
              <ProgressBar
                value={data.total_volume}
                minValue={0}
                maxValue={data.capacity}
                color="teal"
              >
                {toFixed(data.total_volume, 1)} / {data.capacity} ед.
              </ProgressBar>
            </LabeledList.Item>
          </LabeledList>
          {otherReagents > 0 && (
            <Box color="average" mt={1}>
              Посторонний раствор: {toFixed(otherReagents, 1)} ед. Занимает место,
              но не лечит образец.
            </Box>
          )}
          <Box color="label" mt={1}>
            Залейте либитал из мензурки. Лечение начинается автоматически и
            восстанавливает тяжёлые повреждения примерно за три минуты.
          </Box>
        </Section>
        {!!data.goal_active && (
          <Section title="Биоволокно проекта">
            <ProgressBar
              value={data.fiber_delivered}
              minValue={0}
              maxValue={data.fiber_target}
              color="yellow"
            >
              Принято {data.fiber_delivered} / {data.fiber_target}
            </ProgressBar>
            <Box color="label" mt={1}>
              Сдайте собранное биоволокно в капсулу.
            </Box>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
