import { useState } from 'react';
import {
  Box,
  Button,
  Input,
  NoticeBox,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

enum CallStatus {
  Idle,
  Incoming,
  Outgoing,
  Connected,
}

type Data = {
  display_name: string;
  phone_id: string;
  status: CallStatus;
  do_not_disturb: BooleanLike;
  is_advanced: BooleanLike;
  is_free: BooleanLike;
  is_paid: BooleanLike;
  call_price: number;
  online: BooleanLike;
  handset_held: BooleanLike;
  current_call: { display_name: string; phone_id: string } | null;
  callers_list: { dir: 'in' | 'out'; id: string; name: string }[];
  transmitters: {
    phone_id: string;
    display_name: string;
    phone_category: string;
    phone_icon: string;
  }[];
};

const callLabels = {
  [CallStatus.Idle]: 'Линия свободна',
  [CallStatus.Incoming]: 'Входящий вызов',
  [CallStatus.Outgoing]: 'Ожидание ответа',
  [CallStatus.Connected]: 'Соединение установлено',
};

export const PhoneMenu = () => {
  const { act, data } = useBackend<Data>();
  const [category, setCategory] = useState('');
  const [search, setSearch] = useState('');
  const categories = [
    ...new Set(data.transmitters.map((phone) => phone.phone_category)),
  ];
  const activeCategory = categories.includes(category) ? category : '';
  const searchText = search.toLocaleLowerCase();
  const phones = data.transmitters
    .filter(
      (phone) =>
        (!activeCategory || phone.phone_category === activeCategory) &&
        `${phone.display_name} ${phone.phone_id}`
          .toLocaleLowerCase()
          .includes(searchText),
    )
    .sort((a, b) => a.display_name.localeCompare(b.display_name));
  const canCall =
    !!data.online &&
    !!data.handset_held &&
    data.status === CallStatus.Idle &&
    !data.current_call &&
    !!(data.is_free || data.is_paid);

  return (
    <Window title="Телефон" width={580} height={480} theme="retro">
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item>
            <Section
              title={`${data.display_name} (${data.phone_id})`}
              buttons={
                <Button.Checkbox
                  checked={data.do_not_disturb}
                  onClick={() => act('toggle_dnd')}
                >
                  Не беспокоить
                </Button.Checkbox>
              }
            >
              <Stack align="center">
                <Stack.Item grow>
                  {callLabels[data.status]}
                  {!!data.is_advanced && data.current_call && (
                    <Box>{data.current_call.display_name}</Box>
                  )}
                </Stack.Item>
                {data.current_call && (
                  <Stack.Item>
                    <Button
                      icon="phone-slash"
                      color="bad"
                      onClick={() => act('hangup')}
                    >
                      Завершить
                    </Button>
                  </Stack.Item>
                )}
              </Stack>
            </Section>
            {!data.online && (
              <NoticeBox danger>Телефонная сеть недоступна.</NoticeBox>
            )}
            {!data.handset_held && (
              <NoticeBox>Поднимите трубку, чтобы позвонить.</NoticeBox>
            )}
            {!data.is_free && (
              <NoticeBox success={!!data.is_paid}>
                {data.is_paid
                  ? 'Следующий вызов оплачен.'
                  : `Стоимость вызова — ${data.call_price} кредитов. Вставьте монету или проведите картой.`}
              </NoticeBox>
            )}
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item grow>
                <Section title="Телефонная книга" fill>
                  <Stack vertical fill>
                    <Stack.Item>
                      <Input
                        fluid
                        placeholder="Найти телефон"
                        value={search}
                        onChange={setSearch}
                      />
                    </Stack.Item>
                    {categories.length > 1 && (
                      <Stack.Item>
                        <Tabs>
                          <Tabs.Tab
                            selected={!activeCategory}
                            onClick={() => setCategory('')}
                          >
                            Все
                          </Tabs.Tab>
                          {categories.map((name) => (
                            <Tabs.Tab
                              key={name}
                              selected={activeCategory === name}
                              onClick={() => setCategory(name)}
                            >
                              {name}
                            </Tabs.Tab>
                          ))}
                        </Tabs>
                      </Stack.Item>
                    )}
                    <Stack.Item grow>
                      <Section fill scrollable>
                        {!phones.length && (
                          <Box color="label">Нет доступных телефонов.</Box>
                        )}
                        {phones.map((phone) => (
                          <Button
                            key={phone.phone_id}
                            fluid
                            textAlign="left"
                            icon={phone.phone_icon || 'phone'}
                            disabled={!canCall}
                            onClick={() =>
                              act('call_phone', { phone_id: phone.phone_id })
                            }
                          >
                            {phone.display_name} ({phone.phone_id})
                          </Button>
                        ))}
                      </Section>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
              {!!data.is_advanced && (
                <Stack.Item width="32%">
                  <Section
                    title="История"
                    fill
                    scrollable
                    buttons={
                      <Button.Confirm
                        icon="trash"
                        tooltip="Очистить историю"
                        onClick={() => act('clear_history')}
                      />
                    }
                  >
                    {!data.callers_list.length && (
                      <Box color="label">Звонков ещё нет.</Box>
                    )}
                    {data.callers_list.map((call, index) => (
                      <Box key={`${call.id}-${index}`} mb={1}>
                        <Box color={call.dir === 'in' ? 'label' : 'good'}>
                          {call.dir === 'in' ? 'Входящий' : 'Исходящий'}
                        </Box>
                        {call.name} ({call.id})
                      </Box>
                    ))}
                  </Section>
                </Stack.Item>
              )}
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
