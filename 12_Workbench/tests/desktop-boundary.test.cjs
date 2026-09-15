'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  sameOrigin, artifactAllowed, resourceAllowed, cleanEnvironment, hasActiveRun, pathsFor, requestJSON,
} = require('../desktop/main.js');

const origin = 'http://127.0.0.1:45678';

test('network boundary accepts only the owned loopback origin', () => {
  assert.equal(sameOrigin(origin + '/api/state', origin), true);
  for (const value of [
    'https://example.com', 'http://localhost:45678/', 'http://127.0.0.1:45679/',
    'http://127.0.0.1:45678.evil.example/', 'file:///C:/private.txt',
    'http://user:pass@127.0.0.1:45678/', 'javascript:alert(1)',
  ]) assert.equal(sameOrigin(value, origin), false, value);
});

test('secondary windows accept only valid research artifact URLs', () => {
  assert.equal(artifactAllowed(origin + '/artifacts/09_Report/Study%20report.pdf', origin), true);
  assert.equal(artifactAllowed(origin + '/artifacts/12_Workbench/runs/test/plot.png', origin), true);
  for (const relative of [
    '/api/state', '/', '/artifacts/', '/artifacts/%2e%2e/private.txt',
    '/artifacts/folder%2f..%2fprivate.txt', '/artifacts/folder%5cprivate.txt',
    '/artifacts/file%00.txt', '/artifacts/file.txt?url=https://example.com',
    '/artifacts/%XX', '/artifacts/a//file.txt',
  ]) assert.equal(artifactAllowed(origin + relative, origin), false, relative);
});

test('local rendering resources are permitted without remote/file access', () => {
  assert.equal(resourceAllowed(origin + '/styles.css', origin), true);
  assert.equal(resourceAllowed('data:image/png;base64,AAAA', origin), true);
  assert.equal(resourceAllowed(`blob:${origin}/abcd`, origin), true);
  assert.equal(resourceAllowed('chrome-extension://mhjfbmdgcfjbbpaeojofohoefgiehjai/index.html', origin), true);
  for (const value of ['https://example.com/font.woff2', 'file:///C:/secret', 'blob:https://example.com/id', 'ws://127.0.0.1:45678', 'chrome-extension://other/index.html']) {
    assert.equal(resourceAllowed(value, origin), false, value);
  }
});

test('Python launch environment cannot inherit another runtime configuration', () => {
  const source = { Path: 'keep', PYTHONPATH: 'bad', pythonhome: 'bad', ELECTRON_RUN_AS_NODE: '1', NODE_OPTIONS: '--inspect' };
  assert.deepEqual(cleanEnvironment(source), { Path: 'keep', PYTHONNOUSERSITE: '1', PYTHONDONTWRITEBYTECODE: '1' });
  assert.equal(source.PYTHONPATH, 'bad');
});

test('close gate preserves queued or active experiments', () => {
  assert.equal(hasActiveRun({ runs: [{ status: 'completed' }, { status: 'running' }] }), true);
  assert.equal(hasActiveRun({ runs: [{ status: 'queued' }] }), true);
  assert.equal(hasActiveRun({ runs: [{ status: 'completed' }, { status: 'failed' }] }), false);
  assert.equal(hasActiveRun({ runs: [] }), false);
});

test('distribution paths derive solely from relocated package paths', () => {
  const p = require('node:path');
  const root = p.resolve('relocated-package');
  const paths = pathsFor(p.join(root, 'Signal Lab.exe'), p.join(root, 'resources'));
  assert.equal(paths.workspace, p.join(root, 'workspace'));
  assert.equal(paths.python, p.join(root, 'resources', 'python', 'python.exe'));
  assert.equal(paths.local, p.join(root, 'local'));
  assert.equal(paths.server, p.join(root, 'workspace', '12_Workbench', 'server.py'));
});

test('smoke requests preserve the workbench route and authentication contract', async () => {
  const server = require('node:http').createServer((req, res) => {
    let content = '';
    req.on('data', chunk => { content += String(chunk); });
    req.on('end', () => {
      let status = 200;
      let value;
      if (req.url === '/api/state' && req.method === 'GET') value = { token: 'test-only-token', runs: [] };
      else if (req.url === '/api/runs' && req.method === 'POST' &&
        req.headers['x-emi-token'] === 'test-only-token' &&
        req.headers.origin === `http://${req.headers.host}` &&
        req.headers['content-type'] === 'application/json' &&
        content === '{"workflow":"baseline"}') {
        status = 202;
        value = { id: 'test-run', status: 'running' };
      } else if (req.url === '/api/runs/test-run') value = { id: 'test-run', status: 'completed', artifacts: [] };
      else { status = 403; value = { error: 'Invalid workbench token' }; }
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(value));
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const ownOrigin = `http://127.0.0.1:${server.address().port}`;
    const state = await requestJSON(ownOrigin, '/api/state');
    const run = await requestJSON(ownOrigin, '/api/runs', { workflow: 'baseline' }, state.token);
    assert.equal(run.id, 'test-run');
    const detail = await requestJSON(ownOrigin, `/api/runs/${run.id}`);
    assert.equal(detail.status, 'completed');
    await assert.rejects(requestJSON(ownOrigin, '/api/runs', { workflow: 'baseline' }, 'wrong'), /Invalid workbench token/);
  } finally { await new Promise(resolve => server.close(resolve)); }
});
