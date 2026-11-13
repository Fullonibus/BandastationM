import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

export const PortableGenerator = (props) => {
  const { act, data } = useBackend();
  const { stack_percent } = data;
  const stackPercentState =
    (stack_percent > 50 && 'good') ||
    (stack_percent > 15 && 'average') ||
    'bad';
  return (
    <Window width={450} height={data.ship_generator ? 470 : 340}>
      <Window.Content scrollable>
        {!data.anchored && <NoticeBox>Generator not anchored.</NoticeBox>}
        {!!data.ship_generator && (
          <Section title="Корабельный режим">
            <Button
              role="button"
              selected={data.auto_mode}
              onClick={() => act('ship_auto')}
            >
              {data.auto_mode ? 'Авто · до 200 кВт' : 'Ручной режим'}
            </Button>
            <Button
              role="button"
              selected={data.overload}
              disabled={
                !data.overload &&
                (data.tripped || (data.interlock && data.current_heat > 50))
              }
              onClick={() => act('ship_overload')}
            >
              Перегрузка · 300 кВт
            </Button>
            <Button
              role="button"
              selected={data.interlock}
              color={data.interlock ? undefined : 'bad'}
              onClick={() => act('ship_interlock')}
            >
              {data.interlock ? 'Защита включена' : 'Защита отключена'}
            </Button>
            <Box mt={1}>Нагрев: {Math.round(data.current_heat)} %</Box>
            {!!data.tripped && (
              <NoticeBox danger>
                Остановка по перегреву. Для повторного пуска дождитесь охлаждения
                до 50 %.
              </NoticeBox>
            )}
            {!data.interlock && (
              <NoticeBox danger>
                Защита отключена. Предельный перегрев приведёт к взрыву.
              </NoticeBox>
            )}
          </Section>
        )}
        <Section title="Status">
          <LabeledList>
            <LabeledList.Item label="Power switch">
              <Button
                icon={data.active ? 'power-off' : 'times'}
                onClick={() => act('toggle_power')}
                disabled={!data.ready_to_boot}
              >
                {data.active ? 'On' : 'Off'}
              </Button>
            </LabeledList.Item>
            <LabeledList.Item label={`${data.sheet_name} sheets`}>
              <Box inline color={stackPercentState}>
                {data.sheets}
              </Box>
              {data.sheets >= 1 && (
                <Button
                  ml={1}
                  icon="eject"
                  disabled={data.active}
                  onClick={() => act('eject')}
                >
                  Eject
                </Button>
              )}
            </LabeledList.Item>
            <LabeledList.Item label="Current sheet level">
              <ProgressBar
                value={data.stack_percent / 100}
                ranges={{
                  good: [0.1, Infinity],
                  average: [0.01, 0.1],
                  bad: [-Infinity, 0.01],
                }}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Heat level">
              {data.current_heat < 100 ? (
                <Box inline color="good">
                  Nominal
                </Box>
              ) : data.current_heat < 200 ? (
                <Box inline color="average">
                  Caution
                </Box>
              ) : (
                <Box inline color="bad">
                  DANGER
                </Box>
              )}
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section title="Output">
          <LabeledList>
            <LabeledList.Item label="Current output">
              {data.power_output}
            </LabeledList.Item>
            <LabeledList.Item label="Adjust output">
              <Button
                icon="minus"
                aria-label={data.ship_generator ? 'Уменьшить мощность' : undefined}
                role={data.ship_generator ? 'button' : undefined}
                disabled={data.ship_generator && data.auto_mode}
                onClick={() =>
                  act(data.ship_generator ? 'ship_lower_power' : 'lower_power')
                }
              >
                {data.power_generated}
              </Button>
              <Button
                icon="plus"
                aria-label={data.ship_generator ? 'Увеличить мощность' : undefined}
                role={data.ship_generator ? 'button' : undefined}
                disabled={data.ship_generator && data.auto_mode}
                onClick={() =>
                  act(data.ship_generator ? 'ship_higher_power' : 'higher_power')
                }
              >
                {data.power_generated}
              </Button>
              {!!data.ship_generator && !data.auto_mode && (
                <Box inline ml={1}>
                  Задание: {data.manual_percent} %
                </Box>
              )}
            </LabeledList.Item>
            <LabeledList.Item label="Power available">
              <Box inline color={!data.connected && 'bad'}>
                {data.connected ? data.power_available : 'Unconnected'}
              </Box>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
