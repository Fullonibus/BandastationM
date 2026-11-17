import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen, within } from '@testing-library/react';
import type { ReactNode } from 'react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';

import { JoblessRole, JobPriority, type ServerData } from '../types';
import { ServerPrefs, useServerPrefs } from '../useServerPrefs';
import { JobsPage, PremiumJobsPage } from './JobsPage';

const jobs: ServerData['jobs'] = {
  departments: { Service: { color: '#86a928' } },
  jobs: {
    Bartender: { description: 'Serve drinks', department: 'Service' },
    Barber: { description: 'Cut hair', department: 'Service', donor_tier: 1 },
    'Bridge Assistant': {
      description: 'Assist the command staff',
      department: 'Service',
      donor_tier: 4,
    },
    Banker: { description: 'Run a bank', department: 'Service', donor_tier: 5 },
  },
  jobs_sorted: ['Bartender', 'Barber', 'Bridge Assistant', 'Banker'],
};

function JobCatalog(props: { children: ReactNode }) {
  const defaults = useServerPrefs();
  if (!defaults) {
    throw new Error('Preference context defaults are missing');
  }
  return (
    <ServerPrefs.Provider value={{ ...defaults, jobs }}>
      {props.children}
    </ServerPrefs.Provider>
  );
}

function jobRow(title: string) {
  const row = screen.getByText(title).parentElement;
  if (!row) {
    throw new Error(`No row for ${title}`);
  }
  return within(row);
}

afterEach(resetStore);

it('shows all premium roles only on their own page and honors server locks', () => {
  store.set(gameDataAtom, {
    active_slot: 1,
    character_profiles: ['Тестовый персонаж'],
    character_preferences: { misc: { joblessrole: JoblessRole.ReturnToLobby } },
    donator_level: 1,
    job_preferences: [],
    locked_donor_jobs: { Banker: 5 },
    overflow_role: 'Assistant',
  });

  const view = render(<JobsPage />, { wrapper: JobCatalog });
  expect(screen.getByText('Бармен')).toBeTruthy();
  expect(screen.queryByText('Парикмахер')).toBeNull();
  expect(screen.queryByText('Адъютант')).toBeNull();
  expect(screen.queryByText('Банкир')).toBeNull();

  view.rerender(<PremiumJobsPage />);
  expect(screen.queryByText('Бармен')).toBeNull();
  expect(jobRow('Банкир').getByText(/Уровень доната/)).toBeTruthy();
  expect(jobRow('Банкир').queryByText('Выс.')).toBeNull();
  expect(jobRow('Парикмахер').getByText('Выс.')).toBeTruthy();
  expect(jobRow('Адъютант').queryByText(/Уровень доната/)).toBeNull();

  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    fireEvent.click(jobRow('Адъютант').getByText('Выс.'));
    expect(sendAct).toHaveBeenLastCalledWith('set_job_preference', {
      job: 'Bridge Assistant',
      level: JobPriority.High,
    });
  } finally {
    sendAct.mockRestore();
  }
});
