'use strict';
// Exercise the actual SDK stdio boundary and a transaction on a disposable TGM.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
assert.ok(fs.existsSync(path.join(__dirname, '../mcp/maps-mcp.cjs')), 'Maps MCP launcher is not implemented');
const cache = path.join(process.env.LOCALAPPDATA, 'BandaStation/agent-tools');
const sdk = ['maps', 'ripgrep'].map(name => path.join(cache, name, 'node_modules/@modelcontextprotocol/sdk/dist/cjs')).find(name => fs.existsSync(name));
assert.ok(sdk, 'Install tools/agents/setup-maps.ps1 before the SDK smoke');
const { Client } = require(path.join(sdk, 'client/index.js'));
const { StdioClientTransport } = require(path.join(sdk, 'client/stdio.js'));

async function lifecycle(earlyExit = false) {
  const { spawnSync } = require('node:child_process');
  const root = path.resolve(__dirname, '../../..');
  const fixture = path.join(root, 'task_state', 'maps-mcp-lifecycle-'+randomUUID());
  const worker = path.join(fixture, 'tools/agents/maps/worker.py');
  fs.mkdirSync(path.dirname(worker), { recursive: true });
  const marker = path.join(fixture, 'pids.json');
  fs.writeFileSync(worker, 'import json, os, subprocess, sys, time\nfrom pathlib import Path\nchild=subprocess.Popen([sys.executable,"-B","-c","import time; time.sleep(120)"], stdout=sys.stdout, stderr=sys.stderr)\n(Path(__file__).resolve().parents[3]/"pids.json").write_text(json.dumps({"parent":os.getpid(),"descendant":child.pid}))\n'+(earlyExit ? 'os._exit(0)\n' : 'time.sleep(120)\n'));
  const version = fs.readFileSync(path.join(root, 'dependencies.sh'), 'utf8').match(/^export PYTHON_VERSION=([^\r\n]+)/m)[1];
  const python = path.resolve(process.env.TG_BOOTSTRAP_CACHE || path.join(root, 'tools/bootstrap/.cache'), 'python-'+version, 'python.exe');
  const client = new Client({ name: 'maps-owned-process-lifecycle', version: '1.0.0' });
  const transport = new StdioClientTransport({ command: process.execPath, args: [path.join(cache, 'maps/index.mjs')], cwd: root, env: { ...process.env, BANDASTATION_WORKSPACE: fixture, BANDASTATION_MAPS_PYTHON: python }, stderr: 'pipe' });
  let pids;
  try {
    await client.connect(transport);
    const pending = client.callTool({ name: 'dmm_capabilities', arguments: {} }).catch(error => error);
    const deadline = Date.now()+10000;
    while (!fs.existsSync(marker) && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 50));
    assert.ok(fs.existsSync(marker), 'Owned worker did not start its descendant');
    pids = JSON.parse(fs.readFileSync(marker, 'utf8'));
    if (earlyExit) {
      const exitedDeadline = Date.now()+10000;
      let alive = true;
      while (alive && Date.now() < exitedDeadline) {
        try { process.kill(pids.parent, 0); } catch { alive = false; }
        if (alive) await new Promise(resolve => setTimeout(resolve, 25));
      }
      assert.ok(!alive, 'Early-exit worker did not exit before MCP shutdown');
    } else process.kill(pids.descendant, 0);
    await client.close();
    await pending;
    assert.throws(() => process.kill(pids.descendant, 0), 'MCP shutdown left its owned worker descendant alive');
    assert.throws(() => process.kill(pids.parent, 0), 'MCP shutdown left its owned Python worker alive');
    console.log(earlyExit ? 'PASS: real SDK cleanup after early worker exit with inherited descendant pipes' : 'PASS: real SDK shutdown terminates only its owned Python worker process tree');
  } finally {
    await client.close();
    if (pids) for (const pid of [pids.parent, pids.descendant]) spawnSync('taskkill.exe', ['/PID', String(pid), '/T', '/F'], { shell: false, windowsHide: true, stdio: 'ignore', timeout: 5000 });
    if (path.dirname(fixture) !== path.join(root, 'task_state') || !path.basename(fixture).startsWith('maps-mcp-lifecycle-') || fs.lstatSync(fixture).isSymbolicLink()) throw new Error('Unexpected lifecycle cleanup path');
    fs.rmSync(fixture, { recursive: true, force: true });
  }
}

async function main() {
  const root = path.resolve(__dirname, '../../..');
  const fixture = path.join(root, '_maps', '.maps-mcp-smoke-'+randomUUID());
  const filename = path.join(fixture, "owner's map with spaces.dmm");
  fs.mkdirSync(fixture, { recursive: true });
  const original = '//MAP CONVERTED BY dmm2tgm.py THIS HEADER COMMENT PREVENTS RECONVERSION, DO NOT REMOVE\n"a" = (\n/turf/open/space,\n/area/space)\n\n(1,1,1) = {"\na\na\n"}\n(2,1,1) = {"\na\na\n"}\n';
  fs.writeFileSync(filename, original);
  const source = { path: path.relative(root, filename) };
  const client = new Client({ name: 'bandastation-maps-smoke', version: '1.0.0' });
  const transport = new StdioClientTransport({ command: process.execPath, args: [path.join(__dirname, '../mcp/maps-mcp.cjs')], cwd: root, stderr: 'pipe' });
  let diagnostics = '';
  transport.stderr?.on('data', data => { diagnostics = (diagnostics+data).slice(-8000); });
  async function call(name, args) {
    const result = await client.callTool({ name, arguments: args }, undefined, { timeout: 240000 });
    assert.ok(!result.isError, JSON.stringify(result));
    const parsed = JSON.parse(result.content.find(item => item.type === 'text').text);
    assert.deepEqual(result.structuredContent, parsed, 'Text and structured result disagree');
    return { data: parsed, content: result.content };
  }
  try {
    await client.connect(transport);
    const { tools } = await client.listTools();
    const expected = ['dmm_capabilities', 'dmm_info', 'dmm_read', 'dmm_find', 'dmm_render', 'dmm_prepare_patch', 'dmm_apply_patch', 'dmm_diff', 'dmm_validate'];
    assert.deepEqual(tools.map(tool => tool.name).sort(), expected.sort());
    for (const tool of tools) {
      assert.equal(tool.inputSchema.additionalProperties, false);
      assert.equal(tool.annotations.openWorldHint, false);
      assert.equal(tool.annotations.readOnlyHint, tool.name !== 'dmm_apply_patch');
    }
    for (const invalid of [
      { name: 'dmm_info', arguments: { path: source.path, extra: true } },
      { name: 'dmm_read', arguments: { source: { ...source, extra: true } } },
      { name: 'dmm_read', arguments: { source, coordinates: [[true,1,1]] } },
      { name: 'dmm_render', arguments: { requests: [{ source, context: 9 }] } },
      { name: 'dmm_prepare_patch', arguments: { path: source.path, expected_sha256: '0'.repeat(64), operations: [{ op: 'add_atom', at: [1,1,1], atom: '/obj/item/wrench', command: 'unsafe' }] } }
    ]) assert.ok((await client.callTool(invalid)).isError, 'Invalid schema arguments accepted');
    if (process.argv.includes('--schema-only')) {
      console.log('PASS: maps MCP real SDK initialize/list; strict nested schemas and bounds');
      return;
    }
    await call('dmm_capabilities', {});
    const { data: info } = await call('dmm_info', { path: source.path });
    assert.match(info.sha256, /^[0-9a-f]{64}$/);
    const { data: read } = await call('dmm_read', { source, coordinates: [[1,1,1]], limit: 1 });
    assert.equal(read.items.length, 1);
    assert.deepEqual(read.items[0].at, [1,1,1]);
    assert.ok(read.items[0].atoms.some(atom => atom.raw === '/turf/open/space'));
    const { data: found } = await call('dmm_find', { source, typepath: '/turf/open/space', limit: 1 });
    assert.equal(found.items.length, 1);
    const { data: plan } = await call('dmm_prepare_patch', { path: source.path, expected_sha256: info.sha256, operations: [{ op: 'add_atom', at: [1,1,1], atom: '/obj/item/wrench' }] });
    assert.ok(plan.plan_id);
    assert.equal(fs.readFileSync(filename, 'utf8'), original, 'Prepare changed the source');
    const before = { plan_id: plan.plan_id, side: 'before' };
    const after = { plan_id: plan.plan_id, side: 'after' };
    await call('dmm_diff', { left: before, right: after, limit: 10 });
    const { data: candidate } = await call('dmm_read', { source: after, coordinates: [[1,1,1]] });
    assert.ok(candidate.items[0].atoms.some(atom => atom.raw === '/obj/item/wrench'));
    const { content } = await call('dmm_render', { requests: [source, after].map(source => ({ source, region: { min: [1,1,1], max: [2,2,1] }, scale: 1 })) });
    const images = content.filter(item => item.type === 'image');
    assert.equal(images.length, 2, 'Both current-source and staged-plan renders must reach MCP image content');
    for (const image of images) {
      assert.equal(image.mimeType, 'image/png');
      assert.equal(Buffer.from(image.data, 'base64').subarray(0,8).toString('hex'), '89504e470d0a1a0a');
    }
    assert.equal(fs.readFileSync(filename, 'utf8'), original, 'Render changed the source');
    await call('dmm_validate', { source: after });
    await call('dmm_apply_patch', { plan_id: plan.plan_id });
    const { data: current } = await call('dmm_read', { source, coordinates: [[1,1,1], [2,1,1]] });
    assert.ok(current.items.find(item => item.at[0] === 1).atoms.some(atom => atom.raw === '/obj/item/wrench'));
    assert.ok(!current.items.find(item => item.at[0] === 2).atoms.some(atom => atom.raw === '/obj/item/wrench'), 'Shared key edit leaked');
    for (const args of [{ path: '../outside.dmm' }, { path: '.git/config' }, { path: source.path, extra: true }]) {
      assert.ok((await client.callTool({ name: 'dmm_info', arguments: args })).isError, 'Invalid input accepted');
    }
    assert.ok((await client.callTool({ name: 'dmm_read', arguments: { source, limit: 999999 } })).isError);
    assert.ok((await client.callTool({ name: 'dmm_read', arguments: { source: { ...source, extra: true } } })).isError);
    console.log('PASS: maps MCP initialize/list/schema; info/read/find/render image; prepare/diff/validate/apply; strict arguments and checkout paths');
  } catch (error) {
    if (diagnostics) console.error(diagnostics);
    throw error;
  } finally {
    await client.close();
    if (path.dirname(fixture) !== path.join(root, '_maps') || !path.basename(fixture).startsWith('.maps-mcp-smoke-') || fs.lstatSync(fixture).isSymbolicLink()) throw new Error('Unexpected fixture cleanup path');
    fs.rmSync(fixture, { recursive: true, force: true });
  }
  assert.ok(!fs.existsSync(fixture));
  console.log('PASS: maps MCP shutdown and fixture cleanup');
}
(process.argv.includes('--lifecycle-only') ? lifecycle().then(() => lifecycle(true)) : main()).catch(error => { console.error(error.stack); process.exitCode = 1; });
