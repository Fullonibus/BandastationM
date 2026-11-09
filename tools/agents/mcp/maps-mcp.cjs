'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { spawnSync } = require('node:child_process');

async function main() {
  if (Number(process.versions.node.split('.')[0]) < 20) throw new Error('Maps MCP requires Node.js >=20.');
  if (!process.env.LOCALAPPDATA) throw new Error('LOCALAPPDATA is required.');
  const root = fs.realpathSync(path.resolve(__dirname, '../../..'));
  const installed = path.join(process.env.LOCALAPPDATA, 'BandaStation/agent-tools/maps');
  for (const file of ['package-lock.json', 'index.mjs', 'worker-runner.py']) {
    if (!fs.existsSync(path.join(installed, file)) || !fs.readFileSync(path.join(installed, file)).equals(fs.readFileSync(path.join(__dirname, 'maps', file)))) {
      throw new Error('Maps MCP runtime/source changed; run tools/agents/setup-maps.ps1.');
    }
  }
  const sdk = JSON.parse(fs.readFileSync(path.join(installed, 'node_modules/@modelcontextprotocol/sdk/package.json'), 'utf8'));
  if (sdk.version !== '1.29.0') throw new Error('Maps MCP SDK does not match pinned 1.29.0.');
  const version = fs.readFileSync(path.join(root, 'dependencies.sh'), 'utf8').match(/^export PYTHON_VERSION=([^\r\n]+)$/m)?.[1];
  if (!version || !/^\d+\.\d+\.\d+$/.test(version)) throw new Error('Missing pinned project PYTHON_VERSION.');
  const python = path.resolve(process.env.TG_BOOTSTRAP_CACHE || path.join(root, 'tools/bootstrap/.cache'), 'python-'+version, 'python.exe');
  if (!fs.existsSync(python)) throw new Error('Project cached Python is missing; run tools/bootstrap/python.bat once before maps setup.');
  process.env.BANDASTATION_WORKSPACE = root;
  process.env.BANDASTATION_MAPS_PYTHON = python;
  if (process.argv.includes('--check')) {
    const checked = spawnSync(python, ['-B', '-X', 'utf8', '-c', 'import bidict, PIL, yaml; print("Python dependencies available")'], { encoding: 'utf8', cwd: root, windowsHide: true, shell: false, timeout: 20000 });
    if (checked.error || checked.status !== 0) throw new Error('Project Python dependencies unavailable; run tools/bootstrap/python.bat once.');
    console.log(`PASS: maps MCP pinned source; SDK ${sdk.version}; cached Python ${version}; ${checked.stdout.trim()}; checkout ${root}`);
    return;
  }
  await import(pathToFileURL(path.join(installed, 'index.mjs')).href);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
