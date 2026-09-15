'use strict';

const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { spawn } = require('node:child_process');

const TITLE = 'EMI Robotics · Signal Lab';
const ACTIVE = new Set(['queued', 'running']);
const PDF_VIEWER = 'chrome-extension://mhjfbmdgcfjbbpaeojofohoefgiehjai/';

function sameOrigin(value, origin) {
  try {
    const candidate = new URL(value);
    return candidate.protocol === 'http:' && candidate.origin === origin &&
      candidate.hostname === '127.0.0.1' && !candidate.username && !candidate.password;
  } catch { return false; }
}

function artifactAllowed(value, origin) {
  if (!sameOrigin(value, origin)) return false;
  try {
    const candidate = new URL(value);
    if (!candidate.pathname.startsWith('/artifacts/') || candidate.search) return false;
    if (/%(?:2f|5c|00)/i.test(candidate.pathname)) return false;
    const decoded = decodeURIComponent(candidate.pathname.slice('/artifacts/'.length));
    return !!decoded && !decoded.includes('\\') && !decoded.includes('\0') &&
      decoded.split('/').every(segment => segment && segment !== '.' && segment !== '..');
  } catch { return false; }
}

function resourceAllowed(value, origin) {
  if (sameOrigin(value, origin)) return true;
  if (value.startsWith('data:') || value === 'about:blank') return true;
  if (value.startsWith(`blob:${origin}/`)) return true;
  // Chromium's packaged PDF viewer is local; its network requests remain filtered.
  return value.startsWith(PDF_VIEWER);
}

function cleanEnvironment(environment) {
  const copy = { ...environment };
  for (const key of Object.keys(copy)) {
    if (/^(PYTHONPATH|PYTHONHOME|ELECTRON_RUN_AS_NODE|NODE_OPTIONS)$/i.test(key)) delete copy[key];
  }
  copy.PYTHONNOUSERSITE = '1';
  copy.PYTHONDONTWRITEBYTECODE = '1';
  return copy;
}

function hasActiveRun(state) {
  return Array.isArray(state?.runs) && state.runs.some(run => ACTIVE.has(run.status));
}

function pathsFor(executable, resources) {
  const distribution = path.dirname(executable);
  return {
    distribution,
    workspace: path.join(distribution, 'workspace'),
    python: path.join(resources, 'python', 'python.exe'),
    server: path.join(distribution, 'workspace', '12_Workbench', 'server.py'),
    local: path.join(distribution, 'local'),
  };
}

function requestJSON(origin, relative, body, token) {
  return new Promise((resolve, reject) => {
    const payload = body === undefined ? null : Buffer.from(JSON.stringify(body));
    const headers = { 'Accept': 'application/json' };
    if (payload) Object.assign(headers, {
      'Content-Type': 'application/json', 'Content-Length': payload.length,
      'X-EMI-Token': token, 'Origin': origin,
    });
    const req = http.request(new URL(relative, origin), {
      method: payload ? 'POST' : 'GET', headers, timeout: 10000,
    }, response => {
      let content = '';
      response.setEncoding('utf8');
      response.on('data', part => {
        content += part;
        if (content.length > 8 * 1024 * 1024) response.destroy(new Error('Local response exceeded its size limit.'));
      });
      response.on('error', reject);
      response.on('end', () => {
        try {
          const value = JSON.parse(content);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw new Error(value.error || `Local service returned ${response.statusCode}.`);
          }
          resolve(value);
        } catch (error) { reject(error); }
      });
    });
    req.on('timeout', () => req.destroy(new Error('The local service did not respond in time.')));
    req.on('error', reject);
    req.end(payload);
  });
}

async function startDesktop() {
  const { app, BrowserWindow, Menu, dialog, session, shell } = require('electron');
  const paths = pathsFor(process.execPath, process.resourcesPath);
  const iconFile = path.join(process.resourcesPath, 'app', 'icon.ico');
  const windowIcon = fs.existsSync(iconFile) ? iconFile : undefined;
  const smoke = process.argv.includes('--smoke-test') || process.argv.includes('--smoke-baseline');
  const smokeBaseline = process.argv.includes('--smoke-baseline');
  const smokePath = path.join(paths.local, smokeBaseline ? 'desktop-baseline-smoke.json' : 'desktop-smoke.json');
  let backend = null;
  let origin = null;
  let mainWindow = null;
  let allowQuit = false;
  let closePending = false;
  let background = false;
  let backgroundPoll = null;
  let stopping = false;
  let fatalShown = false;
  const documentWindows = new Set();

  function log(message) {
    try { fs.appendFileSync(path.join(paths.local, 'desktop.log'), `${new Date().toISOString()} ${message}\n`); }
    catch { /* The startup dialog reports an unwritable portable folder. */ }
  }

  function writeSmoke(value) {
    fs.writeFileSync(smokePath, JSON.stringify({
      timestamp: new Date().toISOString(), title: TITLE,
      executable: process.execPath, resources: process.resourcesPath,
      workspace: paths.workspace, python: paths.python,
      electron: process.versions.electron, node: process.versions.node,
      ...value,
    }, null, 2));
  }

  try {
    fs.mkdirSync(paths.local, { recursive: true });
    fs.accessSync(paths.local, fs.constants.W_OK);
    for (const folder of ['user-data', 'session-data', 'crash-dumps', 'logs', 'temp']) {
      fs.mkdirSync(path.join(paths.local, folder), { recursive: true });
    }
    app.setName(TITLE);
    app.setPath('userData', path.join(paths.local, 'user-data'));
    app.setPath('sessionData', path.join(paths.local, 'session-data'));
    app.setPath('crashDumps', path.join(paths.local, 'crash-dumps'));
    app.setPath('temp', path.join(paths.local, 'temp'));
    app.setAppLogsPath(path.join(paths.local, 'logs'));
    app.commandLine.appendSwitch('disable-background-networking');
    app.commandLine.appendSwitch('disable-component-update');
    app.commandLine.appendSwitch('disable-domain-reliability');
    app.commandLine.appendSwitch('disable-sync');
    app.commandLine.appendSwitch('no-pings');
    app.commandLine.appendSwitch('no-proxy-server');
    app.commandLine.appendSwitch('disable-features', 'MediaRouter,OptimizationHints,AutofillServerCommunication');
  } catch (error) {
    dialog.showErrorBox('Signal Lab could not start',
      `The portable application folder must be writable. Extract the complete package into a local folder you can edit.\n\n${error.message}`);
    app.exit(1);
    return;
  }

  if (!app.requestSingleInstanceLock()) {
    app.quit();
    return;
  }

  function restoreMain() {
    background = false;
    if (backgroundPoll) clearTimeout(backgroundPoll);
    backgroundPoll = null;
    if (mainWindow && !mainWindow.isDestroyed()) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  }

  app.on('second-instance', restoreMain);
  app.on('activate', restoreMain);

  async function stopOwnedBackend() {
    if (!backend || backend.exitCode !== null || backend.signalCode !== null) return;
    stopping = true;
    const child = backend;
    await new Promise(resolve => {
      const timeout = setTimeout(resolve, 4000);
      child.once('exit', () => { clearTimeout(timeout); resolve(); });
      // Stop only the Python child after the API confirms no active experiment.
      // Never terminate a process tree: MATLAB is a separate research process.
      child.kill();
    });
  }

  async function finishAndQuit(code = 0) {
    if (allowQuit) return;
    allowQuit = true;
    if (backgroundPoll) clearTimeout(backgroundPoll);
    await stopOwnedBackend();
    for (const win of documentWindows) if (!win.isDestroyed()) win.destroy();
    if (mainWindow && !mainWindow.isDestroyed()) mainWindow.destroy();
    app.exit(code);
  }

  async function pollBackground() {
    if (!background || allowQuit) return;
    try {
      const state = await requestJSON(origin, '/api/state');
      if (!background || allowQuit) return;
      if (!hasActiveRun(state)) { await finishAndQuit(); return; }
    } catch (error) {
      if (!background || allowQuit) return;
      log(`Background status check: ${error.message}`);
      restoreMain();
      if (mainWindow) await dialog.showMessageBox(mainWindow, {
        type: 'warning', title: 'Experiment status unavailable',
        message: 'Signal Lab could not confirm whether the experiment has finished.',
        detail: 'The window has reopened so you can inspect the saved status. No MATLAB process was stopped.',
      });
      return;
    }
    backgroundPoll = setTimeout(pollBackground, 2500);
  }

  async function requestClose() {
    if (allowQuit || closePending) return;
    closePending = true;
    try {
      if (!origin || !backend || backend.exitCode !== null) { await finishAndQuit(); return; }
      const state = await requestJSON(origin, '/api/state');
      if (!hasActiveRun(state)) { await finishAndQuit(); return; }
      const options = {
        type: 'question', title: 'An experiment is still running',
        message: 'Let the current experiment finish before Signal Lab closes.',
        detail: 'Choose Finish run in background to hide this window. Signal Lab will keep the local service running, save the result, and close when the experiment ends. Open Signal Lab again to restore the window.',
        buttons: ['Keep window open', 'Finish run in background'], defaultId: 0, cancelId: 0,
        noLink: true,
      };
      const choice = mainWindow && !mainWindow.isDestroyed()
        ? await dialog.showMessageBox(mainWindow, options) : await dialog.showMessageBox(options);
      if (choice.response === 1) {
        background = true;
        for (const win of documentWindows) if (!win.isDestroyed()) win.close();
        if (mainWindow) mainWindow.hide();
        backgroundPoll = setTimeout(pollBackground, 1500);
      }
    } catch (error) {
      log(`Close deferred: ${error.message}`);
      restoreMain();
      await dialog.showMessageBox({
        type: 'warning', title: 'Close deferred',
        message: 'The experiment status could not be confirmed.',
        detail: 'Signal Lab will remain open to protect the running experiment. Try closing again after its status updates.\n\n' + error.message,
      });
    } finally { closePending = false; }
  }

  app.on('before-quit', event => {
    if (!allowQuit) { event.preventDefault(); void requestClose(); }
  });
  app.on('window-all-closed', () => {
    if (!allowQuit && !background) void requestClose();
  });

  function assertWorkspace(state) {
    const actual = state?.project?.root;
    if (typeof actual !== 'string' || typeof state.token !== 'string' || state.token.length < 16) {
      throw new Error('The bundled service returned an invalid project identity.');
    }
    const expectedPath = fs.realpathSync(paths.workspace).toLowerCase();
    const actualPath = fs.realpathSync(actual).toLowerCase();
    if (actualPath !== expectedPath) throw new Error('The local service points at a different project folder.');
    if (!Array.isArray(state.workflows) || !Array.isArray(state.runs)) {
      throw new Error('The bundled service returned incomplete workbench state.');
    }
  }

  async function startBackend() {
    for (const file of [paths.python, paths.server, path.join(paths.workspace, '03_MATLAB', 'startup_project.m')]) {
      if (!fs.existsSync(file)) throw new Error(`A bundled application file is missing:\n${file}\n\nExtract the entire package and keep its folders together.`);
    }
    const environment = cleanEnvironment(process.env);
    environment.TEMP = path.join(paths.local, 'temp');
    environment.TMP = environment.TEMP;
    backend = spawn(paths.python, ['-I', '-B', '-u', paths.server, '--port', '0', '--no-browser', '--project-root', paths.workspace], {
      cwd: path.dirname(paths.server), env: environment, windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'], shell: false,
    });
    backend.stderr.on('data', chunk => log(`Service: ${String(chunk).trimEnd()}`));
    return new Promise((resolve, reject) => {
      let buffer = '';
      let settled = false;
      const timeout = setTimeout(() => fail(new Error('The bundled Python service did not start within 30 seconds. See local/desktop.log.')), 30000);
      function fail(error) {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        reject(error);
      }
      backend.once('error', fail);
      backend.stdout.on('data', chunk => {
        const text = String(chunk);
        log(`Service: ${text.trimEnd()}`);
        buffer = (buffer + text).slice(-16384);
        const match = buffer.match(/EMI research workbench: (http:\/\/127\.0\.0\.1:([0-9]+))(?=\s|$)/);
        if (!settled && match && Number(match[2]) > 0 && Number(match[2]) <= 65535) {
          settled = true;
          clearTimeout(timeout);
          resolve(match[1]);
        }
      });
      backend.once('exit', (code, signal) => {
        log(`Local service exited: code=${code}, signal=${signal}`);
        if (!settled) fail(new Error(`The bundled local service stopped during startup (code ${code}). See local/desktop.log.`));
        else if (!stopping && !allowQuit && !fatalShown) {
          fatalShown = true;
          restoreMain();
          dialog.showErrorBox('Local service stopped',
            'Signal Lab’s local service ended unexpectedly. Saved files remain in the workspace. Close and reopen the application to inspect its status. Any active MATLAB process was left running.\n\nSee local/desktop.log for details.');
        }
      });
    });
  }

  const windowPreferences = () => ({
    nodeIntegration: false, contextIsolation: true, sandbox: true,
    webviewTag: false, webSecurity: true, allowRunningInsecureContent: false,
    spellcheck: false, devTools: false, plugins: true,
  });

  function attachWindowBoundary(win, documentWindow = false) {
    win.webContents.on('will-attach-webview', event => event.preventDefault());
    win.webContents.setWindowOpenHandler(({ url }) => {
      if (artifactAllowed(url, origin)) openDocument(url);
      return { action: 'deny' };
    });
    win.webContents.on('will-navigate', (event, legacyURL) => {
      const url = event.url || legacyURL;
      if (documentWindow) {
        if (!artifactAllowed(url, origin)) event.preventDefault();
      } else if (artifactAllowed(url, origin)) {
        event.preventDefault();
        openDocument(url);
      } else if (!sameOrigin(url, origin) || new URL(url).pathname !== '/') event.preventDefault();
    });
    win.webContents.on('will-redirect', (event, legacyURL) => {
      const url = event.url || legacyURL;
      if (!(documentWindow ? artifactAllowed(url, origin) : sameOrigin(url, origin))) event.preventDefault();
    });
    win.webContents.on('will-frame-navigate', event => {
      if (!resourceAllowed(event.url || '', origin)) event.preventDefault();
    });
  }

  function openDocument(url) {
    if (!artifactAllowed(url, origin)) return;
    const win = new BrowserWindow({
      title: 'Research document · Signal Lab', width: 1040, height: 820,
      minWidth: 650, minHeight: 450, backgroundColor: '#d5dadd',
      icon: windowIcon,
      show: false, parent: mainWindow || undefined, webPreferences: windowPreferences(),
    });
    documentWindows.add(win);
    win.setMenu(null);
    attachWindowBoundary(win, true);
    win.once('ready-to-show', () => win.show());
    win.on('closed', () => documentWindows.delete(win));
    win.loadURL(url).catch(error => log(`Document: ${error.message}`));
  }

  async function configureSession() {
    const localSession = session.defaultSession;
    await localSession.setProxy({ mode: 'direct' });
    localSession.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
    localSession.setPermissionCheckHandler(() => false);
    localSession.setDevicePermissionHandler(() => false);
    localSession.webRequest.onBeforeRequest((details, callback) => {
      callback({ cancel: !resourceAllowed(details.url, origin) });
    });
    localSession.on('will-download', (event, item) => {
      if (!artifactAllowed(item.getURL(), origin)) { event.preventDefault(); return; }
      const fileName = path.basename(item.getFilename()).replace(/[<>:"/\\|?*\x00-\x1f]/g, '_');
      item.setSaveDialogOptions({
        title: 'Save research output', defaultPath: path.join(paths.workspace, fileName),
      });
    });
  }

  async function openFolder(folder) {
    const error = await shell.openPath(folder);
    if (error) await dialog.showMessageBox({ type: 'error', message: 'The folder could not be opened.', detail: error });
  }

  function installMenu() {
    Menu.setApplicationMenu(Menu.buildFromTemplate([
      { label: 'File', submenu: [
        { label: 'Open results folder', click: () => void openFolder(path.join(paths.workspace, '12_Workbench', 'runs')) },
        { label: 'Open project folder', click: () => void openFolder(paths.workspace) },
        { type: 'separator' }, { label: 'Quit Signal Lab', accelerator: 'Alt+F4', click: () => void requestClose() },
      ] },
      { label: 'View', submenu: [
        { role: 'reload' }, { type: 'separator' }, { role: 'resetZoom' },
        { role: 'zoomIn' }, { role: 'zoomOut' }, { type: 'separator' }, { role: 'togglefullscreen' },
      ] },
      { label: 'Help', submenu: [{ label: 'About Signal Lab', click: () => void dialog.showMessageBox({
        type: 'info', title: 'About Signal Lab', message: TITLE,
        detail: 'Portable local research workbench\n\nThe desktop interface, Python service, project files, documents, and saved results run from this application folder. No account, Codex, or internet connection is required.\n\nNew simulations and receiver/project tests require a separately installed, licensed MATLAB with the toolboxes required by the selected workflow. MATLAB and its license are not included.\n\nResults: workspace/12_Workbench/runs\nDesktop settings and logs: local',
      }) }] },
    ]));
  }

  async function runSmoke(state) {
    assertWorkspace(state);
    const proof = {
      status: 'passed', origin, backend_pid: backend.pid,
      project_identity_verified: true, bundled_python: fs.realpathSync(paths.python),
      matlab_available: state.runtime.matlab_available,
      workflow_ids: state.workflows.map(item => item.id),
      document_count: state.documents.length,
      ui: 'Not exercised by this command; native window verification is separate.',
    };
    if (hasActiveRun(state)) throw new Error('A workflow is already running; this smoke check will not interrupt it.');
    if (smokeBaseline) {
      const run = await requestJSON(origin, '/api/runs', { workflow: 'baseline' }, state.token);
      proof.baseline_run_id = run.id;
      const deadline = Date.now() + 30 * 60 * 1000;
      let detail;
      do {
        await new Promise(resolve => setTimeout(resolve, 2000));
        detail = await requestJSON(origin, `/api/runs/${encodeURIComponent(run.id)}`);
        if (Date.now() > deadline && ACTIVE.has(detail.status)) {
          throw new Error('Baseline verification exceeded 30 minutes; the research process remains running.');
        }
      } while (ACTIVE.has(detail.status));
      proof.baseline = { status: detail.status, summary: detail.summary, metrics: detail.metrics, artifacts: detail.artifacts };
      if (detail.status !== 'completed') {
        proof.status = 'failed';
        writeSmoke(proof);
        await finishAndQuit(1);
        return;
      }
    }
    writeSmoke(proof);
    log(`Smoke check passed: ${smokePath}`);
    await finishAndQuit();
  }

  try {
    await app.whenReady();
    origin = await startBackend();
    const state = await requestJSON(origin, '/api/state');
    assertWorkspace(state);
    await configureSession();
    if (smoke) { await runSmoke(state); return; }
    installMenu();
    mainWindow = new BrowserWindow({
      title: TITLE, width: 1440, height: 940, minWidth: 900, minHeight: 650,
      icon: windowIcon,
      backgroundColor: '#d5dadd', show: false, webPreferences: windowPreferences(),
    });
    attachWindowBoundary(mainWindow);
    mainWindow.on('page-title-updated', event => { event.preventDefault(); mainWindow.setTitle(TITLE); });
    mainWindow.on('close', event => { if (!allowQuit) { event.preventDefault(); void requestClose(); } });
    mainWindow.once('ready-to-show', () => mainWindow.show());
    await mainWindow.loadURL(origin + '/#overview');
    log(`Desktop ready: ${origin}; project ${paths.workspace}`);
  } catch (error) {
    log(error.stack || error.message);
    if (smoke) writeSmoke({ status: 'failed', error: error.message, origin });
    else dialog.showErrorBox('Signal Lab could not start',
      `${error.message}\n\nKeep the executable, resources, and workspace folders together in a writable local folder. See local/desktop.log for details.`);
    // An uncertain/active research process must retain its service until it ends.
    if (origin && backend && backend.exitCode === null) {
      try {
        const state = await requestJSON(origin, '/api/state');
        if (hasActiveRun(state)) { background = true; backgroundPoll = setTimeout(pollBackground, 2500); return; }
      } catch { backend.unref(); allowQuit = true; app.exit(1); return; }
    }
    await finishAndQuit(1);
  }
}

module.exports = { sameOrigin, artifactAllowed, resourceAllowed, cleanEnvironment, hasActiveRun, pathsFor, requestJSON };
if (process.versions.electron) void startDesktop();
