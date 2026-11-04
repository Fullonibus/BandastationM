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

type Candidate = Pick<
  Specimen,
  'ref' | 'name' | 'generation' | 'stage' | 'alive'
>;

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

const treatmentStates: Record<
  TreatmentStatus,
  { label: string; color: string }
> = {
  empty: { label: 'Нет образца для лечения', color: 'label' },
  dead: { label: 'Образец погиб. Восстановление невозможно.', color: 'bad' },
  offline: {
    label: 'Капсула не работает. Лечение приостановлено.',
    color: 'bad',
  },
  inactive: {
    label: 'Стазис не действует. Лечение приостановлено.',
    color: 'bad',
  },
  healthy: { label: 'Образец здоров. Лечение не требуется.', color: 'good' },
  no_medicine: {
    label: 'Лечение приостановлено: добавьте либитал.',
    color: 'average',
  },
  treating: { label: 'Идёт восстановление образца.', color: 'good' },
};

export const PhoenixCapsule = () => {
  const { act, data } = useBackend<Data>();
  const { specimen, candidates = [], operational } = data;
  const treatment = treatmentStates[data.treatment_status];
  const otherReagents = Math.max(0, data.total_volume - data.medicine_amount);
  const healthFraction = specimen ? specimen.health / specimen.max_health : 0;
  const requiresReleaseConfirmation =
    !!specimen?.alive && specimen.health < specimen.max_health;
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
          title="Образец"
          buttons={
            specimen &&
            (requiresReleaseConfirmation ? (
              <Button.Confirm
                key={specimen.ref}
                icon="sign-out-alt"
                confirmIcon="sign-out-alt"
                confirmColor="average"
                confirmContent="Прервать лечение и пробудить?"
                disabled={!operational}
                onClick={() => act('release', { specimen: specimen.ref })}
              >
                Пробудить
              </Button.Confirm>
            ) : (
              <Button
                icon="sign-out-alt"
                disabled={!operational}
                tooltip={
                  specimen.alive
                    ? 'Перед пробуждением подготовьте безопасный вольер'
                    : undefined
                }
                onClick={() => act('release', { specimen: specimen.ref })}
              >
                {specimen.alive ? 'Пробудить' : 'Извлечь'}
              </Button>
            ))
          }
        >
          {specimen ? (
            <>
              <Box bold fontSize="1.3em" mb={0.5}>
                {specimen.name}
              </Box>
              <Box color="label" mb={1.5}>
                {specimen.stage} ·{' '}
                {specimen.generation === 0
                  ? 'Архивный основатель'
                  : `Поколение ${specimen.generation}`}
              </Box>
              <ProgressBar
                value={specimen.health}
                minValue={0}
                maxValue={specimen.max_health}
                color={healthColor}
                height={2.5}
                fontSize="1.25em"
                mb={1}
              >
                Здоровье: {Math.round(Math.max(0, 100 * healthFraction))}%
              </ProgressBar>
              <ProgressBar
                value={specimen.nutrition}
                minValue={0}
                maxValue={100}
                color={specimen.nutrition < 25 ? 'average' : 'teal'}
                height={1.5}
                mb={1}
              >
                Питание: {Math.round(specimen.nutrition)}%
                {specimen.nutrition < 25 && ' — низкий запас'}
              </ProgressBar>
              <LabeledList>
                <LabeledList.Item
                  label="Стазис"
                  color={specimen.stasis ? 'good' : 'bad'}
                >
                  {specimen.stasis
                    ? 'Активен — развитие приостановлено'
                    : 'Не действует'}
                </LabeledList.Item>
              </LabeledList>
              <NoticeBox color={treatment.color} mt={1} mb={0}>
                {treatment.label}
              </NoticeBox>
              {requiresReleaseConfirmation && (
                <Box color="average" mt={1}>
                  Пробуждение прекратит лечение. Подготовьте безопасный вольер.
                </Box>
              )}
            </>
          ) : (
            <>
              <NoticeBox color={operational ? 'label' : 'bad'}>
                {operational
                  ? 'Капсула пуста'
                  : 'Капсула не работает — сохранение недоступно'}
              </NoticeBox>
              <Box color="label" mb={1}>
                Подведите ткача к капсуле и выберите особь для сохранения.
              </Box>
              {candidates.length > 0 ? (
                <Table>
                  {candidates.map((candidate) => (
                    <Table.Row key={candidate.ref}>
                      <Table.Cell py={0.5}>
                        <Box bold>{candidate.name}</Box>
                        <Box color="label" fontSize="0.9em">
                          {candidate.stage} · Поколение {candidate.generation}
                          {!candidate.alive && ' · погибшая особь'}
                        </Box>
                      </Table.Cell>
                      <Table.Cell collapsing>
                        <Button
                          icon="snowflake"
                          disabled={!operational}
                          onClick={() =>
                            act('preserve', { specimen: candidate.ref })
                          }
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
        <Section title="Резервуар">
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
              Прочие растворы: {toFixed(otherReagents, 1)} ед. Занимают место,
              но не лечат образец.
            </Box>
          )}
        </Section>
        {!!data.goal_active && (
          <Section title="Биоволокно проекта">
            <ProgressBar
              value={data.fiber_delivered}
              minValue={0}
              maxValue={data.fiber_target}
              color="yellow"
            >
              Принято {data.fiber_delivered} / {data.fiber_target} ед.
            </ProgressBar>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
