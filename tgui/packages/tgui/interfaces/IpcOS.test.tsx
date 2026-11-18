import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen, within } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';

import { IpcOS } from './IpcOS';

type FixtureData = {
  programs: { id: string; name: string; size: number }[];
  [key: string]: unknown;
};

const legal = (
  (await Bun.file(
    new URL(
      '../../tgui-dev-server/preview/fixtures/ipc-os.json',
      import.meta.url,
    ),
  ).json()) as { data: FixtureData }
).data;
const illegal = (
  (await Bun.file(
    new URL(
      '../../tgui-dev-server/preview/fixtures/ipc-os-black.json',
      import.meta.url,
    ),
  ).json()) as { data: FixtureData }
).data;

afterEach(resetStore);

describe('Positronic OS', () => {
  it('separates desktop selection from opening and protects both system utilities', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, legal);
      render(<IpcOS />);
      for (const name of ['NET', 'Диагностика']) {
        fireEvent.click(screen.getByRole('button', { name }));
        expect(screen.queryByText('Удалить', { exact: true })).toBeNull();
      }
      fireEvent.click(screen.getByRole('button', { name: 'DefragMaster' }));
      const description =
        'Восстанавливает 2 brute каждые 25 секунд; базовый расход питания +35%.';
      expect(screen.queryByText(description)).toBeNull();
      fireEvent.click(screen.getByText('Открыть', { exact: true }));
      expect(
        within(screen.getByRole('dialog')).getByText(description),
      ).toBeDefined();
      fireEvent.click(screen.getByRole('button', { name: 'Закрыть окно' }));
      expect(screen.queryByRole('dialog')).toBeNull();
      fireEvent.click(screen.getByText('Удалить', { exact: true }));
      expect(sendAct).toHaveBeenLastCalledWith('uninstall', { id: 'defrag' });
    } finally {
      sendAct.mockRestore();
    }
  });
  it('shows the background cleaning spinner and blocks duplicate cleaning requests', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, {
        ...legal,
        malware: [
          {
            id: 'sensor_noise',
            name: 'SensorNoise.worm',
            os_curable: 1,
            treatments: 0,
            cleaning: 1,
            clean_seconds: 59,
            clean_duration: 60,
          },
        ],
      });
      render(<IpcOS />);
      fireEvent.click(
        screen.getByRole('button', { name: 'Диагностика' }),
      );
      fireEvent.click(screen.getByText('Открыть', { exact: true }));
      expect(
        screen.getByText('Очистка: 59 с. Можно передвигаться.'),
      ).toBeDefined();
      expect(document.querySelector('.fa-spinner')).not.toBeNull();
      fireEvent.click(screen.getByText('Удалить вирус', { exact: true }));
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  it('displays the server cooldown and blocks NeuralCrack until it expires', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, {
        ...illegal,
        neural_available: 0,
        neural_cooldown: 30,
      });
      render(<IpcOS />);
      fireEvent.click(
        screen.getByRole('button', { name: 'NeuralCrack' }),
      );
      fireEvent.click(screen.getByText('Открыть', { exact: true }));
      expect(screen.getByText('Откат: 30 с.')).toBeDefined();
      fireEvent.click(screen.getByText('Снять оглушение', { exact: true }));
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  it('shows download percentage, prevents parallel installs and lets the owner cancel', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, {
        ...legal,
        programs: legal.programs.map((program) => ({
          ...program,
          installed: 0,
        })),
        download_id: 'signal_boost',
        download_progress: 0.4,
        can_manage: 1,
      });
      render(<IpcOS />);
      fireEvent.click(screen.getByRole('button', { name: 'NET' }));
      fireEvent.click(screen.getByText('Открыть', { exact: true }));
      expect(screen.getByText('40%', { exact: true })).toBeDefined();
      fireEvent.click(screen.getAllByText('Загрузить')[0]);
      expect(sendAct).not.toHaveBeenCalled();
      fireEvent.click(screen.getByText('Отменить', { exact: true }));
      expect(sendAct).toHaveBeenLastCalledWith('cancel_download');
    } finally {
      sendAct.mockRestore();
    }
  });

  it('keeps only NeuralCrack usable while the owner is incapacitated', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, {
        ...illegal,
        can_manage: 0,
        neural_available: 1,
      });
      render(<IpcOS />);
      fireEvent.click(
        screen.getByRole('button', { name: 'NeuralCrack' }),
      );
      fireEvent.click(screen.getByText('Удалить', { exact: true }));
      fireEvent.click(screen.getByText('Открыть', { exact: true }));
      expect(sendAct).not.toHaveBeenCalled();
      fireEvent.click(screen.getByText('Снять оглушение', { exact: true }));
      expect(sendAct).toHaveBeenLastCalledWith('neural_crack');
    } finally {
      sendAct.mockRestore();
    }
  });

  it('renders numeric BYOND flags before and after the server unlocks Black Wall', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const whitePrograms = legal.programs.map((program) => ({
        ...program,
        illegal: 0,
        installed: 0,
      }));
      const blackPrograms = illegal.programs.map((program) => ({
        ...program,
        illegal: 1,
        installed: 0,
      }));
      store.set(gameDataAtom, { ...legal, programs: whitePrograms, used: 0 });
      const view = render(<IpcOS />);
      fireEvent.click(screen.getByRole('button', { name: 'NET' }));
      fireEvent.click(screen.getByText('Открыть', { exact: true }));
      for (const program of whitePrograms) {
        expect(
          screen.getByText(`${program.name} · ${program.size} GB`),
        ).toBeDefined();
      }
      expect(
        screen.getByText(
          'Каталог недоступен. Требуется нелегальное обновление.',
        ),
      ).toBeDefined();

      store.set(gameDataAtom, {
        ...legal,
        programs: [...whitePrograms, ...blackPrograms],
        used: 0,
        capacity: 32,
      });
      view.rerender(<IpcOS />);
      for (const program of [...whitePrograms, ...blackPrograms]) {
        const title = screen.getByText(`${program.name} · ${program.size} GB`);
        expect(title).toBeDefined();
        const section = title.closest('.Section');
        if (!section) {
          throw new Error(`Missing NET entry for ${program.id}`);
        }
        fireEvent.click(within(section as HTMLElement).getByText('Загрузить'));
        expect(sendAct).toHaveBeenLastCalledWith('install', { id: program.id });
      }
      expect(
        screen.queryByText(
          'Каталог недоступен. Требуется нелегальное обновление.',
        ),
      ).toBeNull();
    } finally {
      sendAct.mockRestore();
    }
  });
});
