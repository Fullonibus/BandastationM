import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';

import * as actions from '../events/act';
import { gameDataAtom, resetStore, store } from '../events/store';
import { DockController } from './DockController';

const draft = {
  anchor: [132, 44, 1],
  can_configure: true,
  can_register: true,
  can_rename: true,
  dock_class: 'S',
  dock_name: 'Контроллер причала S',
  facing: 1,
  height: 15,
  layout_key: 'draft:2',
  offset: 2,
  status: 'Площадка ещё не зарегистрирована.',
  width: 7,
};

afterEach(resetStore);

it('requests an offset change for the layout shown in the console', () => {
  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, draft);
    render(<DockController />);
    fireEvent.click(screen.getByRole('button', { name: 'Увеличить офсет' }));
    expect(sendAct).toHaveBeenLastCalledWith('set_offset', {
      layout_key: 'draft:2',
      value: 3,
    });
    fireEvent.click(screen.getByText('Сбросить'));
    expect(sendAct).toHaveBeenLastCalledWith('set_offset', {
      layout_key: 'draft:2',
      value: 0,
    });
  } finally {
    sendAct.mockRestore();
  }
});

it('locks layout controls for mapped docks and shows only current reports', () => {
  store.set(gameDataAtom, {
    ...draft,
    can_configure: false,
    can_register: false,
    configured: true,
    registered: true,
    report: { layout_key: 'old', message: 'Старая ошибка', failed: true },
  });
  render(<DockController />);
  expect(screen.getByText('Офсет задан на карте.')).toBeDefined();
  expect(screen.queryByRole('button', { name: 'Увеличить офсет' })).toBeNull();
  expect(screen.queryByText('Старая ошибка')).toBeNull();
  expect(screen.getByText('Подсветить на карте')).toBeDefined();
});
