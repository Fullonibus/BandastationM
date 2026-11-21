import { Icon } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type MaterialStock = {
  name: string;
  icon: string | null;
  available: number;
};

type Design = {
  id: string;
  name: string;
  description: string | null;
  portrait: string | null;
  costs: { id: string; required: number }[];
  seconds: number;
  energy: number;
  enabled: number;
};

type Data = {
  designs: Design[];
  materials: Record<string, MaterialStock>;
  storage: { used: number; capacity: number } | null;
  blocked: string | null;
  printing: string | null;
  remaining: number;
  progress: number;
  delivery: string;
  productivity: number;
};

const formatSheets = new Intl.NumberFormat('ru-RU', {
  maximumFractionDigits: 3,
}).format;

function MaterialName({ material }: { material: MaterialStock }) {
  return (
    <span className="DroidFabricator__materialName">
      {material.icon ? (
        <img
          src={`data:image/png;base64,${material.icon}`}
          alt=""
          width={24}
          height={24}
        />
      ) : (
        <Icon name="cube" aria-hidden="true" />
      )}
      <span>{material.name}</span>
    </span>
  );
}

export function DroidFabricator() {
  const { act, data } = useBackend<Data>();
  const {
    blocked,
    delivery,
    designs = [],
    materials = {},
    printing,
    progress,
    productivity,
    remaining,
    storage,
  } = data;
  const stock = Object.entries(materials);

  return (
    <Window width={560} height={420}>
      <Window.Content scrollable fitted className="DroidRelay DroidFabricator">
        <header className="DroidFabricator__header">
          <div>
            <Icon name="database" aria-hidden="true" />
            {storage
              ? `Хранилище · ${formatSheets(storage.used)}/${formatSheets(storage.capacity)} лист.`
              : 'Хранилище отключено'}
          </div>
          <div className="DroidFabricator__delivery">
            <span>{delivery}</span>
            <span>Скорость ×{productivity}</span>
          </div>
          {storage &&
            (stock.length ? (
              <ul
                className="DroidFabricator__stock"
                aria-label="Запас хранилища"
              >
                {stock.map(([id, material]) => (
                  <li className="DroidFabricator__stockItem" key={id}>
                    <MaterialName material={material} />
                    <strong>{formatSheets(material.available)} лист.</strong>
                  </li>
                ))}
              </ul>
            ) : (
              <p>Хранилище пусто.</p>
            ))}
        </header>
        {printing && (
          <div className="DroidFabricator__job">
            <span>Сборка · {printing}</span>
            <strong>{remaining} сек.</strong>
            <progress aria-label="Прогресс сборки" max={1} value={progress} />
          </div>
        )}
        {blocked && <div role="status">{blocked}</div>}
        {!designs.length && <p>Нет совместимых чертежей.</p>}
        <div className="DroidFabricator__catalog">
          {designs.map((design) => (
            <article className="DroidFabricator__card" key={design.id}>
              <header className="DroidFabricator__cardHeader">
                <div className="DroidFabricator__portrait">
                  {design.portrait ? (
                    <img
                      src={`data:image/png;base64,${design.portrait}`}
                      alt=""
                      width={48}
                      height={48}
                    />
                  ) : (
                    <Icon name="robot" size={2} aria-hidden="true" />
                  )}
                </div>
                <div>
                  <h2>{design.name}</h2>
                  {design.description && <p>{design.description}</p>}
                </div>
              </header>
              <dl className="DroidFabricator__requirements">
                <dt>Время</dt>
                <dd>{design.seconds} сек.</dd>
                <dt>Энергия</dt>
                <dd>{design.energy} кДж</dd>
                {design.costs.map(({ id, required }) => {
                  const material = materials[id];
                  return (
                    material && (
                      <div
                        className="DroidFabricator__material"
                        data-shortage={required > material.available}
                        key={id}
                      >
                        <dt>
                          <MaterialName material={material} />
                        </dt>
                        <dd>
                          {formatSheets(required)} из{' '}
                          {formatSheets(material.available)} лист.
                        </dd>
                      </div>
                    )
                  );
                })}
              </dl>
              <button
                type="button"
                className="Button Button--color--default"
                aria-label={`Собрать корпус «${design.name}»`}
                disabled={!!(blocked || printing || !design.enabled)}
                onClick={() => act('print', { design: design.id })}
              >
                <Icon name="print" aria-hidden="true" />
                Собрать корпус
              </button>
            </article>
          ))}
        </div>
      </Window.Content>
    </Window>
  );
}
