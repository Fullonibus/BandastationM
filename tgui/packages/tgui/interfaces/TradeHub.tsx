import {
  type KeyboardEvent,
  type ReactNode,
  useId,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import { Box, Icon, ProgressBar, Section } from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import type { BooleanLike } from 'tgui-core/react';
import { createSearch } from 'tgui-core/string';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import '../styles/themes/trade-hub.scss';

type Receipt = {
  action: string;
  id: string;
  success: BooleanLike;
  message: string;
  sequence: number;
};

type Data = {
  name: string;
  specialization: string;
  connected: BooleanLike;
  operational: BooleanLike;
  balance: number;
  status: string | null;
  receipt?: Receipt | null;
  terminal_reason: string | null;
  input_reason: string | null;
  output_reason: string | null;
  input_ready: BooleanLike;
  output_ready: BooleanLike;
  offers: {
    id: string;
    name: string;
    description: string;
    group: string;
    price: number;
    stock: number;
    capacity: number;
  }[];
  requests: {
    id: string;
    name: string;
    icon: string;
    group: string | null;
    category: string;
    base_unit_reward: number;
    regular_unit_reward: number;
    price_multiplier: number;
    highDemand: BooleanLike;
    high_demand_bonus: number;
    delivered: number;
    required: number | null;
    remaining: number | null;
    unit_reward: number;
    restock_amount: number;
    restock_pending: BooleanLike;
    renewal_pending: BooleanLike;
    waiting_for_power: BooleanLike;
    waiting_for_core: BooleanLike;
    ready_in: number;
    renew_in: number;
  }[];
  contracts?: {
    id: string;
    name: string;
    customer: string;
    target: string;
    credits: number;
  }[];
};

const tabs = [
  { id: 'buy', label: 'Купить' },
  { id: 'sell', label: 'Сдать груз' },
] as const;
type Tab = (typeof tabs)[number]['id'];
type TradeRequest = Data['requests'][number];

export function TradeHub() {
  const { act, data } = useBackend<Data>();
  const { offers = [], requests = [], contracts = [], receipt } = data;
  const [tab, setTab] = useState<Tab>('buy');
  const [searchText, setSearchText] = useState('');
  const [group, setGroup] = useState('');
  const nav = useRef<HTMLDivElement>(null);
  const lastAction = useRef<{
    action: TradeCommand;
    id: string;
    button: HTMLButtonElement;
    focused: boolean;
  } | null>(null);
  const lastSequence = useRef(receipt?.sequence);
  const submitTrade: SubmitTrade = (action, id, button) => {
    lastAction.current = {
      action,
      id,
      button,
      focused: document.activeElement === button,
    };
    act(action, { id });
  };
  function selectTab(next: Tab) {
    if (next !== tab) lastAction.current = null;
    setTab(next);
  }
  const groups = [...new Set(offers.map((offer) => offer.group))].sort();
  const search = createSearch(searchText, (offer: Data['offers'][number]) =>
    [offer.name, offer.description, offer.group].join(' '),
  );
  const filtered = offers.filter(
    (offer) => (!group || group === offer.group) && search(offer),
  );
  const receiptInView =
    receipt &&
    (tab === 'buy'
      ? receipt.action === 'buy' &&
        filtered.some((offer) => offer.id === receipt.id)
      : (receipt.action === 'accept' &&
          requests.some((request) => request.id === receipt.id)) ||
        (receipt.action === 'deliver_contract' &&
          contracts.some((contract) => contract.id === receipt.id)));
  const terminalReason =
    data.terminal_reason ||
    (!data.connected
      ? 'Нет связи с узлом.'
      : !data.operational
        ? 'Терминал недоступен.'
        : null);
  const outputReason =
    data.output_reason ||
    (!data.output_ready ? 'Площадка выдачи недоступна.' : null);
  const inputReason =
    data.input_reason ||
    (!data.input_ready ? 'Площадка приёма недоступна.' : null);

  const sharedReason =
    terminalReason || (tab === 'buy' ? outputReason : inputReason);
  useLayoutEffect(() => {
    if (!receipt || lastSequence.current === receipt.sequence) return;
    lastSequence.current = receipt.sequence;
    const submitted = lastAction.current;
    if (
      !submitted ||
      submitted.action !== receipt.action ||
      submitted.id !== receipt.id
    )
      return;
    lastAction.current = null;
    const result = document.getElementById('trade-result');
    if (
      !result ||
      (document.activeElement !== submitted.button &&
        document.activeElement !== document.body)
    )
      return;
    if (submitted.focused && !submitted.button.isConnected)
      result.focus({ preventScroll: true });
    const scroller = result.closest('.Layout__content--scrollable');
    if (!scroller) return;
    const viewport = scroller.getBoundingClientRect();
    const row = result.getBoundingClientRect();
    if (row.bottom > viewport.bottom)
      scroller.scrollTop += row.bottom - viewport.bottom;
    else if (row.top < viewport.top)
      scroller.scrollTop += row.top - viewport.top;
  }, [receipt]);

  function navigateTabs(event: KeyboardEvent<HTMLButtonElement>) {
    let next: Tab;
    switch (event.key) {
      case 'ArrowLeft':
      case 'ArrowRight':
        next = tab === 'buy' ? 'sell' : 'buy';
        break;
      case 'Home':
        next = 'buy';
        break;
      case 'End':
        next = 'sell';
        break;
      default:
        return;
    }
    event.preventDefault();
    selectTab(next);
    nav.current
      ?.querySelector<HTMLButtonElement>(`#trade-tab-${next}`)
      ?.focus();
  }

  return (
    <Window title="Торговый узел" width={820} height={660} theme="trade-hub">
      <Window.Content fitted className="TradeHub">
        <div className="TradeHub__toolbar">
          <div role="tablist" aria-label="Торговля" ref={nav}>
            {tabs.map(({ id, label }) => (
              <button
                key={id}
                id={`trade-tab-${id}`}
                type="button"
                role="tab"
                aria-selected={tab === id}
                aria-controls={`trade-panel-${id}`}
                tabIndex={tab === id ? 0 : -1}
                onKeyDown={navigateTabs}
                onClick={() => selectTab(id)}
              >
                {label}
              </button>
            ))}
          </div>
          <strong>Бюджет карго: {formatMoney(data.balance)} кр.</strong>
        </div>
        {sharedReason && (
          <div id="trade-unavailable" className="TradeHub__unavailable">
            {sharedReason}
          </div>
        )}
        <div className="TradeHub__sr-only" role="status" aria-atomic="true">
          {receipt && <span key={receipt.sequence}>{receipt.message}</span>}
        </div>
        {receipt && !receiptInView && <ReceiptMessage receipt={receipt} />}
        {tabs.map(({ id }) => (
          <div
            className="TradeHub__screen"
            key={id}
            role="tabpanel"
            id={`trade-panel-${id}`}
            aria-labelledby={`trade-tab-${id}`}
            hidden={tab !== id}
          >
            {tab === id && (
              <Window.Content scrollable>
                <Section title={data.name}>
                  <Box color="label">{data.specialization}</Box>
                  {!sharedReason && (
                    <Box color="good">
                      {id === 'buy'
                        ? 'Площадка выдачи свободна'
                        : 'Площадка приёма готова'}
                    </Box>
                  )}
                  {id === 'sell' && data.status && (
                    <Box color="label">{data.status}</Box>
                  )}
                </Section>
                {id === 'buy' ? (
                  <Section
                    title="Предложения узла"
                    buttons={
                      <span>
                        Показано: {filtered.length}/{offers.length}
                      </span>
                    }
                  >
                    <Box mb={1}>
                      Один заказ — один ящик на площадке выдачи. Оплата из
                      бюджета карго.
                    </Box>
                    <div className="TradeHub__filters">
                      <label>
                        Поиск товара
                        <input
                          type="search"
                          value={searchText}
                          placeholder="Название, описание или группа"
                          onChange={(event) => {
                            lastAction.current = null;
                            setSearchText(event.currentTarget.value);
                          }}
                        />
                      </label>
                      <label>
                        Группа
                        <select
                          value={group}
                          onChange={(event) => {
                            lastAction.current = null;
                            setGroup(event.currentTarget.value);
                          }}
                        >
                          <option value="">Все группы</option>
                          {groups.map((name) => (
                            <option key={name}>{name}</option>
                          ))}
                        </select>
                      </label>
                      <button
                        type="button"
                        disabled={!searchText && !group}
                        onClick={() => {
                          lastAction.current = null;
                          setSearchText('');
                          setGroup('');
                        }}
                      >
                        Сбросить
                      </button>
                    </div>
                    {!offers.length ? (
                      <Box color="label">Нет доступных предложений.</Box>
                    ) : !filtered.length ? (
                      <Box color="label">
                        По заданным фильтрам ничего не найдено. Измените поиск
                        или сбросьте фильтры.
                      </Box>
                    ) : (
                      <OffersTable
                        offers={filtered}
                        balance={data.balance}
                        reason={sharedReason}
                        submitTrade={submitTrade}
                        receipt={receipt}
                      />
                    )}
                  </Section>
                ) : (
                  <>
                    <ContractsTable
                      contracts={contracts}
                      reason={sharedReason}
                      submitTrade={submitTrade}
                      receipt={receipt}
                    />
                    <Section title="Местные потребности">
                      <Box mb={1}>
                        Положите товар на площадку приёма отдельно или в
                        открытом ящике. Излишки останутся на месте. Выплата
                        поступит в бюджет карго.
                      </Box>
                      <Box color="label" mb={1}>
                        У сменных заявок есть квота. Когда она исчерпана, узел
                        запросит другой товар той же группы.
                      </Box>
                      {!requests.length ? (
                        <Box color="label">Активных заявок нет.</Box>
                      ) : (
                        <TradeTable
                          name="Местные потребности"
                          headings={[
                            'Товар',
                            'Партия и пополнение',
                            'За единицу',
                            'Действие',
                          ]}
                        >
                          {requests.map((request) => (
                            <RequestRow
                              key={request.id}
                              request={request}
                              reason={sharedReason}
                              submitTrade={submitTrade}
                              receipt={
                                receipt?.action === 'accept' &&
                                receipt.id === request.id
                                  ? receipt
                                  : null
                              }
                            />
                          ))}
                        </TradeTable>
                      )}
                    </Section>
                  </>
                )}
              </Window.Content>
            )}
          </div>
        ))}
      </Window.Content>
    </Window>
  );
}

function TradeTable({
  name,
  headings,
  children,
}: {
  name: string;
  headings: string[];
  children: ReactNode;
}) {
  return (
    <table className="TradeHub__table" aria-label={name}>
      <thead>
        <tr>
          {headings.map((heading) => (
            <th key={heading} scope="col">
              {heading}
            </th>
          ))}
        </tr>
      </thead>
      {children}
    </table>
  );
}

function ReceiptMessage({ receipt }: { receipt: Receipt }) {
  return (
    <div
      id="trade-result"
      tabIndex={-1}
      className={`TradeHub__receipt ${receipt.success ? 'color-good' : 'color-bad'}`}
    >
      <Icon
        name={receipt.success ? 'check' : 'exclamation-triangle'}
        aria-hidden="true"
      />{' '}
      {receipt.message}
    </div>
  );
}

function TradeAction({
  action,
  id,
  name,
  label,
  reason,
  describedBy,
  sharedReason,
  submitTrade,
}: {
  action: TradeCommand;
  id: string;
  name: string;
  label: string;
  reason: string | null;
  describedBy?: string;
  sharedReason: string | null;
  submitTrade: SubmitTrade;
}) {
  const reasonId = useId();
  return (
    <>
      <button
        type="button"
        aria-label={`${label}: ${name}`}
        aria-disabled={!!sharedReason || !!reason}
        aria-describedby={
          [
            sharedReason && 'trade-unavailable',
            reason && (describedBy || reasonId),
          ]
            .filter(Boolean)
            .join(' ') || undefined
        }
        onClick={(event) => {
          if (!sharedReason && !reason)
            submitTrade(action, id, event.currentTarget);
        }}
      >
        {label}
      </button>
      {reason && !describedBy && (
        <div id={reasonId} className="TradeHub__reason">
          {reason}
        </div>
      )}
    </>
  );
}

function ReceiptRow({
  receipt,
  columns,
}: {
  receipt: Receipt;
  columns: number;
}) {
  return (
    <tr>
      <td colSpan={columns}>
        <ReceiptMessage receipt={receipt} />
      </td>
    </tr>
  );
}

type TradeCommand = 'buy' | 'accept' | 'deliver_contract';
type SubmitTrade = (
  action: TradeCommand,
  id: string,
  button: HTMLButtonElement,
) => void;
type TradeListProps = {
  reason: string | null;
  receipt?: Receipt | null;
  submitTrade: SubmitTrade;
};

function OffersTable({
  offers,
  balance,
  reason,
  receipt,
  submitTrade,
}: TradeListProps & { offers: Data['offers']; balance: number }) {
  return (
    <TradeTable
      name="Предложения узла"
      headings={['Товар', 'Запас', 'Цена за ящик', 'Действие']}
    >
      {offers.map((offer) => (
        <tbody key={offer.id}>
          <tr>
            <th scope="row">
              {offer.name}
              <small>{offer.group}</small>
              <small>{offer.description}</small>
            </th>
            <td>
              {offer.stock}/{offer.capacity}
            </td>
            <td>{formatMoney(offer.price)} кр.</td>
            <td>
              <TradeAction
                action="buy"
                id={offer.id}
                name={offer.name}
                label="Купить"
                sharedReason={reason}
                submitTrade={submitTrade}
                reason={
                  offer.stock <= 0
                    ? 'Товара нет в наличии.'
                    : balance < offer.price
                      ? 'В бюджете карго недостаточно средств.'
                      : null
                }
              />
            </td>
          </tr>
          {receipt?.action === 'buy' && receipt.id === offer.id && (
            <ReceiptRow receipt={receipt} columns={4} />
          )}
        </tbody>
      ))}
    </TradeTable>
  );
}

function ContractsTable({
  contracts,
  reason,
  receipt,
  submitTrade,
}: TradeListProps & { contracts: NonNullable<Data['contracts']> }) {
  if (!contracts.length) return null;
  return (
    <Section title="Контракты экспедиционного корпуса">
      <Box mb={1}>
        Поместите находку в закрытый ящик на площадке приёма. Для аномальной
        находки нужен ящик для образцов. Выплата поступит в бюджет карго.
      </Box>
      <TradeTable
        name="Контракты экспедиционного корпуса"
        headings={['Контракт', 'Награда', 'Действие']}
      >
        {contracts.map((contract) => (
          <tbody key={contract.id}>
            <tr>
              <th scope="row">
                {contract.id}: {contract.name}
                <small>
                  {contract.customer} · {contract.target}
                </small>
              </th>
              <td>{formatMoney(contract.credits)} кр.</td>
              <td>
                <TradeAction
                  action="deliver_contract"
                  id={contract.id}
                  name={contract.name}
                  label="Сдать контракт"
                  sharedReason={reason}
                  reason={null}
                  submitTrade={submitTrade}
                />
              </td>
            </tr>
            {receipt?.action === 'deliver_contract' &&
              receipt.id === contract.id && (
                <ReceiptRow receipt={receipt} columns={3} />
              )}
          </tbody>
        ))}
      </TradeTable>
    </Section>
  );
}

function requestPause(request: TradeRequest) {
  if (request.restock_pending || request.renewal_pending) {
    const operation = request.restock_pending ? 'Пополнение' : 'Смена заявки';
    if (request.waiting_for_power) return `${operation} ожидает питания ядра.`;
    if (request.waiting_for_core)
      return `${operation} ожидает восстановления ядра.`;
    const seconds = request.restock_pending
      ? request.ready_in
      : request.renew_in;
    return seconds > 0
      ? `${operation} через ${Math.ceil(seconds)} с.`
      : `${operation} выполняется.`;
  }
  return request.remaining !== null && request.remaining <= 0
    ? 'Квота исчерпана.'
    : null;
}

function RequestRow({
  request,
  reason,
  receipt,
  submitTrade,
}: TradeListProps & { request: TradeRequest }) {
  const pause = requestPause(request);
  const pauseId = useId();
  const { required, remaining } = request;
  return (
    <tbody>
      <tr>
        <th scope="row">
          <div className="TradeHub__commodity">
            <img
              src={`data:image/png;base64,${request.icon}`}
              alt=""
              width="32"
              height="32"
            />
            <div>
              {request.name}
              <small>{request.group || request.category}</small>
              {request.group && <small>{request.category}</small>}
            </div>
          </div>
        </th>
        <td>
          {required === null ? (
            <>
              <b>Постоянная закупка</b>
              <small>Без лимита и пополнения запасов</small>
            </>
          ) : (
            <>
              <div
                role="progressbar"
                aria-label={`Партия: ${request.name}`}
                aria-valuemin={0}
                aria-valuemax={required}
                aria-valuenow={request.delivered}
              >
                <ProgressBar value={request.delivered} maxValue={required}>
                  {request.delivered}/{required}
                </ProgressBar>
              </div>
              <small>Осталось квоты: {remaining}</small>
              <small>
                Полная партия: +{request.restock_amount} к запасу каждого товара
                группы до вместимости склада.
              </small>
              {pause && (
                <div id={pauseId} className="TradeHub__reason">
                  {pause}
                </div>
              )}
            </>
          )}
        </td>
        <td>
          <strong className={request.highDemand ? 'color-good' : undefined}>
            {formatMoney(request.unit_reward)} кр.
          </strong>
          {remaining === null ? (
            <small>за открытый пустой ящик</small>
          ) : (
            <>
              {!!request.highDemand && (
                <>
                  <small className="color-good">
                    Высокий спрос +{request.high_demand_bonus}%
                  </small>
                  <small>
                    Обычно: {formatMoney(request.regular_unit_reward)} кр.
                  </small>
                </>
              )}
              {request.price_multiplier !== 1 && (
                <details>
                  <summary>Расчёт цены</summary>
                  <small>
                    База: {formatMoney(request.base_unit_reward)} кр. ·
                    Коэффициент категории ×
                    {request.price_multiplier.toLocaleString('ru-RU')}
                  </small>
                </details>
              )}
            </>
          )}
        </td>
        <td>
          <TradeAction
            action="accept"
            id={request.id}
            name={request.name}
            label="Сдать груз"
            sharedReason={reason}
            reason={pause}
            submitTrade={submitTrade}
            describedBy={pause ? pauseId : undefined}
          />
        </td>
      </tr>
      {receipt && <ReceiptRow receipt={receipt} columns={4} />}
    </tbody>
  );
}
