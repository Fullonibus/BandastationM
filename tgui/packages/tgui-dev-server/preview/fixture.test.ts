import { describe, expect, it } from 'bun:test';
import { normalizeFixture } from './fixture';

describe('TGUI preview fixture boundary', () => {
  it('opens a chosen interface from data without requiring game-generated config', () => {
    const fixture = normalizeFixture(
      {
        data: { frequency: 0, specimen: null },
        static_data: { channels: ['Common'] },
        shared: { tab: '"status"' },
      },
      'Radio',
    );
    expect(fixture.config.interface.name).toBe('Radio');
    expect(fixture.config.window.size).toEqual([600, 600]);
    expect(fixture.config.user.observer).toBe(0);
    expect(fixture.data).toEqual({ frequency: 0, specimen: null });
    expect(fixture.static_data).toEqual({ channels: ['Common'] });
    expect(fixture.shared).toEqual({ tab: '"status"' });
  });

  it('preserves explicit read-only status and requested geometry', () => {
    const fixture = normalizeFixture({
      config: {
        interface: { name: 'Radio' },
        status: 0,
        window: { size: [330, 250] },
      },
      data: {},
    });
    expect(fixture.config.status).toBe(0);
    expect(fixture.config.window.size).toEqual([330, 250]);
    expect(fixture.config.interface.layout).toBe('default');
  });

  it.each([
    { name: 'null envelope', value: null },
    { name: 'array envelope', value: [] },
    { name: 'array data', value: { data: [] } },
    {
      name: 'zero window width',
      value: { config: { window: { size: [0, 600] } }, data: {} },
    },
    {
      name: 'infinite window height',
      value: {
        config: { window: { size: [600, Number.POSITIVE_INFINITY] } },
        data: {},
      },
    },
    { name: 'array static data', value: { data: {}, static_data: [] } },
    {
      name: 'malformed shared JSON',
      value: { data: {}, shared: { tab: 'invalid JSON' } },
    },
  ])('rejects $name before it reaches the real renderer', ({ value }) => {
    expect(() => normalizeFixture(value, 'Radio')).toThrow();
  });

  it('requires a routed interface name', () => {
    expect(() => normalizeFixture({ data: {} })).toThrow();
    expect(() => normalizeFixture({ data: {} }, '../Radio')).toThrow();
  });
});
