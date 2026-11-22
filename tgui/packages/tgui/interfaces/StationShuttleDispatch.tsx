import { type ComponentProps, useRef, useState } from 'react';
import { Box, Icon, NoticeBox, Section, Stack } from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import { type BooleanLike, classes } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Offer = {
  id: string;
  name: string;
  ship_class: 'S' | 'M';
  price: number;
};

type Dock = {
  id: string;
  name: string;
  dock_class: 'S' | 'M' | null;
  status: 'free' | 'occupied' | 'reserved' | 'unavailable';
  ship: string | null;
  seconds_left: number | null;
  compatible_offers: string[];
};

type Data = {
  available: BooleanLike;
  balance: number | null;
  delivery_seconds: number;
  offers: Offer[];
  docks: Dock[];
  order_result?: { id: number; message: string; failed: BooleanLike };
};

function credits(amount: number) {
  return `${formatMoney(amount)} кр.`;
}

function arrivalTime(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  const remainder = seconds % 60;
  return `${minutes}:${String(remainder).padStart(2, '0')}`;
}

function DispatchButton({ className, ...props }: ComponentProps<'button'>) {
  return (
    <button
      {...props}
      type="button"
      className={classes([
        'Button Button--color--default',
        props['aria-pressed'] && 'Button--selected',
        props.disabled && 'Button--disabled',
        className,
      ])}
    />
  );
}

function DockStatus({ dock, compatible }: { dock: Dock; compatible: boolean }) {
  if (dock.status === 'reserved' && dock.seconds_left != null) {
    return (
      <Box color="average">
        {dock.ship ? `${dock.ship} · ` : ''}
        {dock.seconds_left > 0
          ? `Прибытие через ${arrivalTime(dock.seconds_left)}`
          : 'Прибывает'}
      </Box>
    );
  }

  switch (dock.status) {
    case 'occupied':
      return <Box color="label">Занят{dock.ship ? ` · ${dock.ship}` : ''}</Box>;
    case 'reserved':
      return (
        <Box color="average">
          Зарезервирован{dock.ship ? ` · ${dock.ship}` : ''}
        </Box>
      );
    case 'unavailable':
      return <Box>Недоступен</Box>;
    case 'free':
      return compatible ? (
        <Box color="good">Свободен</Box>
      ) : (
        <Box color="label">Не подходит выбранному кораблю</Box>
      );
  }
}

function orderBlocker(
  offer: Offer | undefined,
  selectedPrice: number | undefined,
  dock: Dock | undefined,
  docks: Dock[],
  balance: number | null,
) {
  if (!offer) {
    return 'Выберите корабль.';
  }
  if (selectedPrice !== offer.price) {
    return 'Цена изменилась. Выберите корабль снова.';
  }
  if (!dock) {
    return docks.some(
      (entry) =>
        entry.status === 'free' && entry.compatible_offers.includes(offer.id),
    )
      ? 'Выберите свободный причал.'
      : 'Для этого корабля нет свободных причалов.';
  }
  if (dock.status !== 'free' || !dock.compatible_offers.includes(offer.id)) {
    return 'Выбранный причал больше недоступен. Выберите другой.';
  }
  if (offer.price > 0) {
    if (balance == null) {
      return 'Бюджет карго недоступен.';
    }
    if (balance < offer.price) {
      return `В бюджете карго не хватает ${credits(offer.price - balance)}`;
    }
  }
}

export function StationShuttleDispatch() {
  const { act, data } = useBackend<Data>();
  const {
    available,
    balance,
    delivery_seconds,
    offers = [],
    docks = [],
    order_result,
  } = data;
  const [quote, setQuote] = useState<Pick<Offer, 'id' | 'price'>>();
  const [dockId, setDockId] = useState<string>();
  const offer = offers.find(({ id }) => id === quote?.id);
  const dock = docks.find(({ id }) => id === dockId);
  const nextRequest = useRef(0);
  const [requestId, setRequestId] = useState<number>();
  const response = order_result?.id === requestId ? order_result : undefined;
  const awaitingResponse = requestId !== undefined && !response;
  const blocker = orderBlocker(offer, quote?.price, dock, docks, balance);

  return (
    <Window title="Терминал вызова кораблей" width={620} height={520}>
      <Window.Content scrollable>
        <style>{`
          .StationShuttleDispatch .Button {
            --adjust-hover: 4;
            --button-background-selected: hsl(from var(--color-green) h s calc(l - 10));
            min-height: 2rem;
          }
          .StationShuttleDispatch .Button:focus-visible {
            outline: 2px solid var(--color-text);
            outline-offset: -2px;
          }
        `}</style>
        {!available ? (
          <NoticeBox danger>Нет связи со службой доставки кораблей.</NoticeBox>
        ) : (
          <div className="StationShuttleDispatch">
            <Section
              title="Корабли"
              buttons={
                <Box bold>
                  <Icon name="coins" mr={0.5} aria-hidden="true" />
                  Бюджет карго{' '}
                  <Box as="span" color={balance == null ? 'label' : 'good'}>
                    {balance == null ? 'недоступен' : credits(balance)}
                  </Box>
                </Box>
              }
            >
              {!offers.length ? (
                <Box color="label">Сейчас нет кораблей для заказа.</Box>
              ) : (
                <Stack wrap="wrap">
                  {offers.map((entry) => {
                    const selected =
                      quote?.id === entry.id && quote.price === entry.price;
                    return (
                      <Stack.Item key={entry.id} grow basis="10rem">
                        <DispatchButton
                          aria-pressed={selected}
                          style={{
                            minHeight: '3.5rem',
                            textAlign: 'left',
                            whiteSpace: 'normal',
                            width: '100%',
                          }}
                          onClick={() => {
                            setRequestId(undefined);
                            setQuote({ id: entry.id, price: entry.price });
                            if (quote?.id !== entry.id) {
                              setDockId(undefined);
                            }
                          }}
                        >
                          <Box as="span" bold style={{ display: 'block' }}>
                            {entry.name}
                            {selected && (
                              <Icon name="check" ml={0.5} aria-hidden="true" />
                            )}
                          </Box>
                          <Box as="span">
                            Класс {entry.ship_class} ·{' '}
                            {entry.price === 0
                              ? 'Бесплатно'
                              : credits(entry.price)}
                          </Box>
                        </DispatchButton>
                      </Stack.Item>
                    );
                  })}
                </Stack>
              )}
            </Section>

            <Section
              title="Причалы"
              buttons={
                <Box color="label">
                  <Icon name="clock" mr={0.5} aria-hidden="true" />
                  Доставка за {delivery_seconds / 60} мин
                </Box>
              }
            >
              {!docks.length ? (
                <Box color="label">
                  На станции нет зарегистрированных причалов.
                </Box>
              ) : (
                <Stack vertical>
                  {docks.map((entry) => {
                    const compatible =
                      !offer || entry.compatible_offers.includes(offer.id);
                    const selectable =
                      !!offer && compatible && entry.status === 'free';
                    return (
                      <Stack.Item key={entry.id}>
                        <Stack align="center">
                          <Stack.Item grow minWidth={0}>
                            <Box bold style={{ overflowWrap: 'anywhere' }}>
                              {entry.name}
                            </Box>
                            <Stack wrap="wrap">
                              <Stack.Item color="label">
                                {entry.dock_class
                                  ? `Класс ${entry.dock_class}`
                                  : 'Штатный причал'}
                              </Stack.Item>
                              <Stack.Item>
                                <DockStatus
                                  dock={entry}
                                  compatible={compatible}
                                />
                              </Stack.Item>
                            </Stack>
                          </Stack.Item>
                          {selectable && (
                            <Stack.Item>
                              <DispatchButton
                                aria-label={`Выбрать причал «${entry.name}»`}
                                aria-pressed={entry.id === dockId}
                                onClick={() => {
                                  setRequestId(undefined);
                                  setDockId(entry.id);
                                }}
                              >
                                {entry.id === dockId ? 'Выбран' : 'Выбрать'}
                              </DispatchButton>
                            </Stack.Item>
                          )}
                        </Stack>
                      </Stack.Item>
                    );
                  })}
                </Stack>
              )}
            </Section>

            <Section title="Подтверждение заказа">
              <Stack align="center" wrap="wrap">
                <Stack.Item grow minWidth={0}>
                  <div aria-live="polite">
                    {response ? (
                      <Box color={response.failed ? undefined : 'good'}>
                        {response.message}
                      </Box>
                    ) : awaitingResponse ? (
                      <Box>Проверка заказа…</Box>
                    ) : blocker ? (
                      <Box color="label">{blocker}</Box>
                    ) : (
                      <Box style={{ overflowWrap: 'anywhere' }}>
                        {offer?.name} · {dock?.name}
                      </Box>
                    )}
                  </div>
                </Stack.Item>
                {!(response && !response.failed) && (
                  <Stack.Item>
                    <DispatchButton
                      disabled={!!blocker || awaitingResponse}
                      onClick={() => {
                        if (!blocker && !awaitingResponse && quote && dock) {
                          const id = ++nextRequest.current;
                          setRequestId(id);
                          act('order', {
                            offer_id: quote.id,
                            dock_id: dock.id,
                            expected_price: quote.price,
                            request_id: id,
                          });
                        }
                      }}
                    >
                      {offer?.price === 0
                        ? 'Вызвать бесплатно'
                        : offer
                          ? `Заказать за ${credits(offer.price)}`
                          : 'Заказать корабль'}
                    </DispatchButton>
                  </Stack.Item>
                )}
              </Stack>
            </Section>
          </div>
        )}
      </Window.Content>
    </Window>
  );
}
