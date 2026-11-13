import { afterEach, expect, it } from 'bun:test';
import { render, screen } from '@testing-library/react';

import { gameDataAtom, resetStore, store } from '../events/store';
import { StationTraumaFusionCore } from './StationTraumaFusionCore';

afterEach(resetStore);

const source = {
  active: true,
  auto: true,
  interlock: true,
  level: 100,
  max_level: 100,
  target: 100,
  output: 100,
  heat: 0,
  power: 165,
  fuel_flow: 2.6,
  injection_limit: 3.9,
  injection_max: 3.9,
  grid: true,
  batteries: [],
  fuel: [],
  exhaust_pressure: 100,
  room_temperature: 293,
  radiation: 0,
};

it('identifies electrical consumption and a real plasma leak', () => {
  store.set(gameDataAtom, { ...source, electric: true, leaking: true });
  render(<StationTraumaFusionCore />);
  expect(screen.getByText('Нагрев плазмы')).toBeDefined();
  expect(screen.getByText('Потребление:')).toBeDefined();
  expect(screen.getByText(/утечка плазмы/)).toBeDefined();
  expect(screen.queryByText('Впрыск трития:')).toBeNull();
});

it('retains fusion terminology for an existing reactor', () => {
  store.set(gameDataAtom, source);
  render(<StationTraumaFusionCore />);
  expect(screen.getByText('Впрыск трития:')).toBeDefined();
  expect(screen.getByText('Выработка:')).toBeDefined();
  expect(screen.queryByText('Потребление:')).toBeNull();
});
