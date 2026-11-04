import { describe, expect, it } from 'bun:test';

import { joinResearch, remapCatalogue } from './helpers';
import { type CatalogueFile, NodeFlag, type TechWebData } from './types';

const nodePath = '/datum/techweb_node/test';
const experimentPath = '/datum/experiment/test';

function catalogueFile(): CatalogueFile {
  return {
    version: 1,
    id_cache: [nodePath, 'General Research', 0, experimentPath, 'iron'],
    node_cache: {
      1: {
        name: 'Research',
        description: 'A node',
        costs: { 2: 1000 },
        unlocked_designs: [3],
        required_experiments: [4],
      },
    },
    design_cache: { 3: ['Design', [5, 2000], 1, 1, 'design_test'] },
    point_types_abbreviations: { 'General Research': 'Gen.' },
    build_types: { 1: 'Lathe' },
    department_flags: { 1: 'Science' },
    SHEET_MATERIAL_AMOUNT: 2000,
  };
}

function researchData(): TechWebData {
  return {
    stored_research: 1,
    locked: 0,
    sec_protocols: 1,
    nodes: [1, 1, NodeFlag.ExperimentsDone | NodeFlag.CanUnlock],
    queue_nodes: [],
    experiments: [4, [[2, 3]], 0],
    experiment_metadata: {
      4: {
        name: 'Scan',
        description: 'Scan samples',
        tag: 'Scan',
        performance_hint: '',
        ref: '[experiment]',
        stages: [['integer', 'Samples']],
      },
    },
    points: { 'General Research': 1000 },
    points_last_tick: { 'General Research': 10 },
    t_disk: [1],
    d_disk: [null, 3, null],
  };
}

describe('Techweb catalogue and live updates', () => {
  it('updates research and experiment progress without rebuilding the catalogue or losing disk slots', () => {
    const catalogue = remapCatalogue(catalogueFile());
    const data = researchData();
    const before = joinResearch(data, catalogue);
    expect(before.nodes[0].can_unlock).toBe(1);
    expect(before.experiments[experimentPath].progress).toEqual([
      ['integer', 'Samples', 2, 3],
    ]);
    expect(before.d_disk?.blueprints).toEqual([null, '3', null]);
    expect(before.t_disk?.stored_research).toEqual({ [nodePath]: 1 });
    expect(before.design_cache[3].cost).toEqual({ iron: 2000 });

    const after = joinResearch(
      {
        ...data,
        nodes: [1, 0, NodeFlag.Free | NodeFlag.ExperimentsDone],
        experiments: [4, [[3, 3]], 1],
        points: { 'General Research': 0 },
      },
      catalogue,
    );
    expect(after.nodes[0].tier).toBe(0);
    expect(after.experiments[experimentPath].completed).toBe(1);
    expect(after.experiments[experimentPath].progress).toEqual([
      ['integer', 'Samples', 3, 3],
    ]);
    expect(after.points).toEqual({ 'General Research': 0 });
    expect(after.node_cache).toBe(before.node_cache);
    expect(before.experiments[experimentPath].completed).toBe(0);
  });

  it('waits for an older catalogue to catch up with new ids and experiment stages', () => {
    const data = researchData();
    data.nodes.push(6, 1, NodeFlag.CanUnlock);
    data.queue_nodes = [6, 'Researcher'];
    data.d_disk = [null, 7, 3];
    data.experiments = [
      4,
      [
        [1, 2],
        [0, 1],
      ],
      0,
      8,
      [],
      0,
    ];
    data.experiment_metadata![8] = {
      ...data.experiment_metadata![4],
      stages: [],
    };
    const before = joinResearch(data, remapCatalogue(catalogueFile()));
    expect(before.nodes.map((node) => node.path)).toEqual([nodePath]);
    expect(Object.keys(before.queue_nodes)).toEqual([]);
    expect(before.d_disk?.blueprints).toEqual([null, null, '3']);
    expect(before.experiments).toEqual({});

    const file = catalogueFile();
    file.version = 2;
    file.id_cache.push('/datum/techweb_node/new', 0, '/datum/experiment/new');
    file.node_cache[6] = {
      name: 'New node',
      description: '',
      costs: {},
      unlocked_designs: [7],
    };
    file.design_cache[7] = ['New design', [], 1, 1, 'new_design'];
    data.experiment_metadata![4].stages.push(['bool', 'Approval']);
    const after = joinResearch(data, remapCatalogue(file));
    expect(after.nodes.map((node) => node.path)).toEqual([
      nodePath,
      '/datum/techweb_node/new',
    ]);
    expect(after.queue_nodes['/datum/techweb_node/new']).toBe('Researcher');
    expect(after.d_disk?.blueprints).toEqual([null, '7', '3']);
    expect(after.experiments[experimentPath].progress).toEqual([
      ['integer', 'Samples', 1, 2],
      ['bool', 'Approval', 0, 1],
    ]);
    expect(after.experiments['/datum/experiment/new'].completed).toBe(0);
  });

  it('keeps discount experiment order when catalogue ids are not sorted', () => {
    const file = catalogueFile();
    file.id_cache.push('/datum/experiment/other');
    file.node_cache[1].discount_experiments = [6, 100, 4, 200];
    const catalogue = remapCatalogue(file);
    expect(
      Object.entries(catalogue.node_cache[nodePath].discount_experiments),
    ).toEqual([
      ['/datum/experiment/other', 100],
      [experimentPath, 200],
    ]);
  });
});
