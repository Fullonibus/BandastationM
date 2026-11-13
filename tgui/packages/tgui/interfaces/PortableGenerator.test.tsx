import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';

import * as actions from '../events/act';
import { gameDataAtom, resetStore, store } from '../events/store';
import { PortableGenerator } from './PortableGenerator';

afterEach(resetStore);

const generator = {
  active: true,
  anchored: true,
  connected: true,
  ready_to_boot: true,
  sheets: 25,
  sheet_name: 'Plasma',
  stack_percent: 80,
  current_heat: 0,
  power_generated: '50 kW',
  power_output: '200 kW',
  power_available: '200 kW',
};

it('keeps ship controls out of ordinary PACMAN interfaces', () => {
  store.set(gameDataAtom, generator);
  render(<PortableGenerator />);
  expect(screen.queryByText('Корабельный режим')).toBeNull();
  expect(screen.getByText('Adjust output:')).toBeDefined();
});

it('sends ship-only controls and displays the latched heat trip', () => {
  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, {
      ...generator,
      ship_generator: true,
      auto_mode: false,
      overload: false,
      interlock: true,
      tripped: true,
      current_heat: 110,
      manual_percent: 100,
    });
    render(<PortableGenerator />);
    expect(screen.getByText(/Остановка по перегреву/)).toBeDefined();
    const overload = screen.getByRole('button', { name: 'Перегрузка · 300 кВт' });
    fireEvent.click(overload);
    expect(sendAct).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: 'Ручной режим' }));
    expect(sendAct).toHaveBeenLastCalledWith('ship_auto');
    fireEvent.click(screen.getByRole('button', { name: 'Защита включена' }));
    expect(sendAct).toHaveBeenLastCalledWith('ship_interlock');
    fireEvent.click(screen.getByRole('button', { name: 'Увеличить мощность' }));
    expect(sendAct).toHaveBeenLastCalledWith('ship_higher_power');
  } finally {
    sendAct.mockRestore();
  }
});
