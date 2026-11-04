import type { Config } from '../../tgui/events/types';

export type PreviewFixture = {
  config: Config;
  data: Record<string, unknown>;
  static_data: Record<string, unknown>;
  shared: Record<string, string>;
};

function record(value: unknown, label: string): Record<string, any> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error(`${label} must be a JSON object`);
  }
  return value as Record<string, any>;
}

/** Complete the native update envelope without inventing interface data. */
export function normalizeFixture(
  value: unknown,
  interfaceName?: string,
): PreviewFixture {
  const input = record(value, 'Fixture');
  const config = record(input.config ?? {}, 'config');
  const face = record(config.interface ?? {}, 'config.interface');
  const name = interfaceName ?? face.name;
  if (typeof name !== 'string' || !/^[A-Za-z_]\w*$/.test(name)) {
    throw new Error('Choose a valid TGUI interface name');
  }
  const windowConfig = record(config.window ?? {}, 'config.window');
  const size = windowConfig.size ?? [600, 600];
  if (
    !Array.isArray(size) ||
    size.length !== 2 ||
    size.some((n) => !Number.isInteger(n) || n < 1 || n > 4096)
  ) {
    throw new Error(
      'config.window.size must contain two integers between 1 and 4096',
    );
  }
  const shared = record(input.shared ?? {}, 'shared');
  for (const [key, encoded] of Object.entries(shared)) {
    if (typeof encoded !== 'string') {
      throw new Error(`shared.${key} must be a JSON-encoded string`);
    }
    if (encoded !== '') JSON.parse(encoded);
  }
  return {
    config: {
      title: name,
      status: 2,
      refreshing: 0,
      user: { name: 'Preview operator', observer: 0 },
      client: { address: '', ckey: 'preview', computer_id: '' },
      ...config,
      interface: { layout: 'default', ...face, name },
      window: {
        key: `preview-${name}`,
        fancy: 1,
        locked: 0,
        scale: 1,
        ...windowConfig,
        size,
      },
    } as Config,
    data: record(input.data ?? {}, 'data'),
    static_data: record(input.static_data ?? {}, 'static_data'),
    shared,
  };
}
