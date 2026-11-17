import {
  Box,
  Button,
  Icon,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Role = { id: string; name: string };
type Data = {
  roles: Role[];
  tokens: number | null;
  available: BooleanLike;
  storage_enabled: BooleanLike;
  loading: BooleanLike;
  next_token_at: string | null;
  selected: string | null;
  enabled: BooleanLike;
  can_select: BooleanLike;
  message: string | null;
};

const roleDetails: Record<string, { icon: string; description: string }> = {
  traitor: {
    icon: 'user-secret',
    description: 'Тайный агент Синдиката с аплинком и личными целями.',
  },
  brother: {
    icon: 'people-arrows',
    description: 'Пробудите кровных братьев и выполните общие цели.',
  },
  changeling: {
    icon: 'dna',
    description: 'Поглощайте ДНК и меняйте облик, скрывая свою природу.',
  },
  blood_worm: {
    icon: 'worm',
    description: 'Начните червём внутри носителя и развивайте заражение.',
  },
  heretic: {
    icon: 'book-skull',
    description: 'Изучайте запретные знания и проводите ритуалы.',
  },
  vampire: {
    icon: 'droplet',
    description: 'Питайтесь кровью и открывайте вампирские способности.',
  },
};

export const AntagTokens = () => {
  const { act, data } = useBackend<Data>();
  const {
    roles,
    tokens,
    available,
    storage_enabled,
    loading,
    next_token_at,
    selected,
    enabled,
    can_select,
    message,
  } = data;
  const selectedRole = roles.find((role) => role.id === selected);
  const disabled = !!loading || !available || !can_select || (tokens ?? 0) < 1;

  return (
    <Window width={620} height={660} theme="syndicate">
      <Window.Content scrollable className="AntagTokens">
        <Section>
          <Stack align="center">
            <Stack.Item>
              <Icon name="coins" size={2} color="yellow" />
            </Stack.Item>
            <Stack.Item grow>
              <Box fontSize={1.35} bold>
                Антаг токены
              </Box>
              <Box color="label" mt={0.5}>
                Дополнительная роль на следующую смену
              </Box>
            </Stack.Item>
            <Stack.Item className="AntagTokens__balance">
              {available ? tokens : '—'}{' '}
              <Box as="span" fontSize={1} color="label">
                ток.
              </Box>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="rotate"
                tooltip="Обновить баланс"
                disabled={!!loading || !storage_enabled}
                onClick={() => act('refresh')}
              />
            </Stack.Item>
          </Stack>
        </Section>

        {!enabled ? (
          <NoticeBox>
            Антагонисты за антаг токены отключены администрацией. Заявки
            отменены, баланс сохранён.
          </NoticeBox>
        ) : !can_select ? (
          <NoticeBox info>
            Заявки принимаются до начала раунда. Токены можно использовать на
            следующей смене.
          </NoticeBox>
        ) : !available ? (
          <NoticeBox>
            {loading
              ? 'Загружаем баланс…'
              : !storage_enabled
                ? 'Хранилище токенов отключено на сервере. Обратитесь к администрации.'
                : 'Не удалось получить баланс. Попробуйте обновить его.'}
          </NoticeBox>
        ) : !tokens ? (
          <NoticeBox info>
            Пока нет токенов. Администратор может пополнить баланс.
          </NoticeBox>
        ) : null}
        {!!message && <NoticeBox>{message}</NoticeBox>}

        <Section title="Выберите роль" className="AntagTokens__roles">
          {roles.map((role) => {
            const details = roleDetails[role.id];
            const isSelected = role.id === selected;
            return (
              <Stack
                key={role.id}
                align="center"
                className={`AntagTokens__role${isSelected ? ' AntagTokens__role--selected' : ''}`}
              >
                <Stack.Item className="AntagTokens__icon">
                  <Icon name={details?.icon ?? 'user-secret'} size={1.5} />
                </Stack.Item>
                <Stack.Item grow>
                  <Box bold>{role.name}</Box>
                  <Box className="AntagTokens__description">
                    {details?.description}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    selected={isSelected}
                    disabled={disabled || isSelected}
                    icon={isSelected ? 'check' : 'plus'}
                    onClick={() => act('select', { role: role.id })}
                  >
                    {isSelected ? 'Выбрано' : '1 токен'}
                  </Button>
                </Stack.Item>
              </Stack>
            );
          })}
        </Section>

        {selectedRole && (
          <Section>
            <Stack align="center">
              <Stack.Item grow>
                <Box bold>Заявка: {selectedRole.name}</Box>
                <Box color="label" mt={0.5}>
                  Для участия нажмите «Готов» в лобби.
                </Box>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="xmark"
                  disabled={!can_select || !!loading}
                  onClick={() => act('cancel')}
                >
                  Отменить заявку
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        )}
        <Box className="AntagTokens__note">
          Один токен спишется только при выдаче роли. Баны и ограничения
          персонажа действуют. Если выдать роль не получится, токен останется на
          балансе.
        </Box>
        <Box className="AntagTokens__note" mt={1}>
          T4 даёт 1 токен в месяц, T5 — 3. Токены начисляются при входе.
          Пропущенные начисления не компенсируются.
          {next_token_at && (
            <Box mt={0.5}>
              Следующее начисление — при входе с T4 или T5 начиная с{' '}
              {next_token_at}.
            </Box>
          )}
        </Box>
      </Window.Content>
    </Window>
  );
};
