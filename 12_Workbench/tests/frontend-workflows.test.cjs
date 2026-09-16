"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

// A small DOM fixture exercises the unchanged application entry point and its
// real fetch/event paths. No browser, network connection or MATLAB run is used.
class Element {
  constructor(tag = "div") {
    this.tagName = tag.toUpperCase(); this.children = []; this.attributes = {};
    this.listeners = {}; this.dataset = {}; this.className = ""; this._text = "";
    this.hidden = false; this.disabled = false; this.scrollTop = 0;
    this.scrollHeight = 0; this.clientHeight = 0;
    this.style = { setProperty() {} };
    this.classList = {
      add: (value) => { this.className += ` ${value}`; },
      toggle: (value, enabled) => {
        const items = this.className.split(/\s+/).filter((item) => item && item !== value);
        if (enabled) items.push(value); this.className = items.join(" ");
      },
    };
  }
  set textContent(value) { this._text = String(value); this.children = []; }
  get textContent() { return this._text + this.children.map((node) => node.textContent).join(""); }
  set value(value) { this._value = String(value); }
  get value() { return this._value ?? (this.tagName === "SELECT" ? this.children[0]?.value : "") ?? ""; }
  get lastElementChild() { return this.children.at(-1); }
  append(...nodes) {
    for (const node of nodes) {
      if (node.tagName === "#FRAGMENT") this.children.push(...node.children);
      else this.children.push(node);
    }
  }
  replaceChildren(...nodes) {
    this.children = []; this._text = "";
    if (this.tagName === "SELECT") this._value = undefined;
    this.append(...nodes);
  }
  setAttribute(key, value) { this.attributes[key] = String(value); }
  getAttribute(key) { return this.attributes[key] ?? this[key] ?? null; }
  addEventListener(type, callback) { (this.listeners[type] ||= []).push(callback); }
  async dispatch(type) { await Promise.all((this.listeners[type] || []).map((fn) => fn({ preventDefault() {} }))); }
  contains(node) { return node === this || this.children.some((child) => child.contains(node)); }
  focus() {}
  matches(selector) {
    const [tag, className] = selector.split(".");
    return (!tag || this.tagName === tag.toUpperCase()) && (!className || this.className.split(/\s+/).includes(className));
  }
  querySelectorAll(selector) {
    return this.children.flatMap((child) => [...(child.matches(selector) ? [child] : []), ...child.querySelectorAll(selector)]);
  }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
}

const workflows = () => [
  { id: "four_way_v2_development", title: "Four-way v2 development", enabled: true, description: "Development." },
  { id: "four_way_v2_evaluation", title: "Four-way v2 evaluation", enabled: false, disabled_reason: "Accepted evidence is missing from this workspace.", description: "Evaluation." },
  { id: "four_way_v2_closure", title: "Source-return comparison", enabled: false, disabled_reason: "Accepted evidence is missing from this workspace.", description: "Return comparison." },
];

async function loadApp(options = {}) {
  const elements = new Map();
  const html = fs.readFileSync(path.join(__dirname, "../web/index.html"), "utf8");
  const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]));
  const document = {
    hidden: false, activeElement: null,
    getElementById(id) {
      if (!ids.has(id)) return null;
      if (!elements.has(id)) elements.set(id, new Element(id === "workflow-select" ? "select" : "div"));
      return elements.get(id);
    },
    createElement: (tag) => new Element(tag),
    createDocumentFragment: () => new Element("#fragment"),
    querySelectorAll: () => [], addEventListener() {},
  };
  document.getElementById("runtime-status").append(new Element("span"));
  const state = {
    workflows: workflows(), runtime: { matlab_available: true }, runs: [], token: "test-token",
    research: { title: "Completed conditional study", detail: "The saved study remains available.", next_step: "Measure receiver behavior." },
    ...options.state,
  };
  if (options.run) state.runs = [options.run];
  const requests = [], timeouts = [];
  const sandbox = {
    document, Node: Element, AbortController, URL, console,
    window: { location: { href: "http://127.0.0.1:8773/", origin: "http://127.0.0.1:8773" }, setTimeout: (_, delay) => { timeouts.push(delay); return timeouts.length; }, clearTimeout() {} },
    fetch: async (url, request) => {
      requests.push({ url, request });
      if (url === "/api/state") return { ok: true, json: async () => state };
      if (url === "/api/runs" && request?.method === "POST" && options.allowLaunch) {
        const run = { id: "new-run", workflow: JSON.parse(request.body).workflow, status: "running", artifacts: [] };
        return { ok: true, json: async () => run };
      }
      const run = state.runs.find((item) => url === `/api/runs/${item.id}`);
      if (run) return { ok: true, json: async () => run };
      throw new Error(`Unexpected request: ${url}`);
    },
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../web/app.js"), "utf8"), sandbox);
  await new Promise(setImmediate);
  return { get: (id) => document.getElementById(id), state, requests, timeouts,
    select: async (id) => { const select = document.getElementById("workflow-select"); select.value = id; await select.dispatch("change"); } };
}

function evaluationRun() {
  const pairs = [], hypotheses = [];
  for (let variant = 1; variant <= 16; variant++) {
    const id = `V${String(variant).padStart(2, "0")}`;
    hypotheses.push({ variant: { id, threshold_id: "nominal", pulseLaw: "transport", latencyRise_s: 25e-9, latencyFall_s: 25e-9 },
      baseline_normalized_mean: .001, combined_normalized_mean: 0, all_execution_clean_guards_pass: true,
      aggregate_gate: true, per_fixture_rmse_gate: true, per_fixture_peak_gate: true, current_gate: true,
      rescued_failures: 0, rescued_failure_gate: false, combined_benefit_demonstrated: false });
    for (let fixture = 1; fixture <= 12; fixture++) for (const Arm of ["BASELINE", "EM_ONLY", "SW_ONLY", "COMBINED"]) {
      pairs.push({ Fixture: `V2EVAL${String(fixture).padStart(2, "0")}`, Variant: id, Arm,
        ReceiverDomainPass: true, ReceiverNumericsPass: true, CleanGuardPass: true, ExecutionGuardPass: true,
        WindowPairedRMSE_deg: Arm === "BASELINE" ? .001 : 0, WindowPairedPeak_deg: .002,
        PeakCurrent_A: .124, EMICountPeak_counts: Arm === "BASELINE" ? 1 : 0, EMICountFinal_counts: 0, TaskSuccess: true });
    }
  }
  return { id: "evaluation", workflow: "four_way_v2_evaluation", title: "Four-way v2 evaluation", status: "completed",
    metrics: { logicalRecords: 1536, pairedResults: 768, passingHypotheses: 0 }, artifacts: [],
    evaluation: { summary: { complete: true, all_execution_clean_guards_pass: true }, pairs, hypotheses } };
}

test("readiness belongs to the selected workflow, not the saved research milestone", async () => {
  const app = await loadApp();
  assert.equal(app.get("run-button").disabled, false);
  await app.select("four_way_v2_evaluation");
  assert.equal(app.get("run-button").disabled, true);
  assert.equal(app.get("workflow-select").disabled, false);
  assert.equal(app.get("workflow-unavailable").textContent, "Accepted evidence is missing from this workspace.");
  assert.equal(app.get("research-title").textContent, "Completed conditional study");
  await app.get("run-form").dispatch("submit");
  assert.equal(app.requests.some((r) => r.request?.method === "POST"), false);
  await app.select("four_way_v2_development");
  assert.equal(app.get("run-button").disabled, false);
  assert.equal(app.get("workflow-unavailable").hidden, true);
});

test("ready evaluation and return workflows remain selectable; an active run blocks concurrent launch", async () => {
  const ready = workflows().map((item) => ({ ...item, enabled: true, disabled_reason: "" }));
  const app = await loadApp({ state: { workflows: ready } });
  for (const id of ["four_way_v2_evaluation", "four_way_v2_closure"]) {
    await app.select(id); assert.equal(app.get("run-button").disabled, false);
  }
  app.state.runs = [{ id: "busy", status: "running" }];
  await app.select("four_way_v2_development");
  assert.equal(app.get("run-button").disabled, true);
  assert.match(app.get("workflow-unavailable").textContent, /already in progress/);
});

test("new launch choices submit their selected identity and allow the full acceptance preflight", async () => {
  for (const workflow of ["four_way_v2_evaluation", "four_way_v2_closure"]) {
    const app = await loadApp({ allowLaunch: true, state: { workflows: workflows().map((item) => ({ ...item, enabled: true })) } });
    await app.select(workflow);
    await app.get("run-form").dispatch("submit");
    const submitted = app.requests.filter((item) => item.request?.method === "POST");
    assert.equal(submitted.length, 1);
    assert.deepEqual(JSON.parse(submitted[0].request.body), { workflow });
    assert.equal(submitted[0].request.headers["X-EMI-Token"], "test-token");
    assert.ok(app.timeouts.includes(240000), "launch must outlast the 180-second acceptance check plus prerequisites");
    assert.ok(app.timeouts.includes(12000), "ordinary refresh keeps its short timeout");
    assert.equal(app.get("run-button").disabled, true);
    assert.match(app.get("launch-message").textContent, /Experiment started/);
  }
});

test("completed negative-benefit evaluation retains all 768 pairs and 16 separate decisions", async () => {
  const app = await loadApp({ run: evaluationRun() });
  const detail = app.get("run-detail"), tables = detail.querySelectorAll("table");
  assert.equal(tables.length, 2);
  assert.equal(tables[0].querySelector("tbody").children.length, 16);
  assert.equal(tables[1].querySelector("tbody").children.length, 768);
  assert.match(detail.textContent, /0 of 16 saved receiver assumptions met/);
  assert.match(detail.textContent, /Completing the workflow does not mean/);
  assert.match(detail.textContent, /Completed/);
  assert.doesNotMatch(detail.textContent, /did not finish successfully/);
  assert.match(tables[0].querySelector("tbody").children[0].lastElementChild.textContent, /^Fail$/);
  assert.match(tables[1].textContent, /V2EVAL12V16Combined/);
  assert.match(detail.textContent, /Logical records/);
  assert.doesNotMatch(detail.textContent, /Development records/);
});

test("incomplete evaluation keeps partial rows and missing decisions explicit", async () => {
  const run = evaluationRun(); run.status = "failed"; run.evaluation.pairs = [run.evaluation.pairs[0]];
  run.evaluation.hypotheses = []; delete run.evaluation.summary.all_execution_clean_guards_pass;
  const app = await loadApp({ run }); const detail = app.get("run-detail");
  assert.match(detail.textContent, /guards: Unrecorded/);
  assert.match(detail.textContent, /Benefit screens were not saved/);
  assert.match(detail.textContent, /1 saved matched evaluation comparisons/);
  assert.match(detail.textContent, /did not finish successfully/);
});

test("source-return view retains all 128 comparisons and distinguishes rejected diagnostics", async () => {
  const comparisons = [];
  for (const cp of [40, 240]) for (let v = 1; v <= 16; v++) for (const Arm of ["BASELINE", "EM_ONLY", "SW_ONLY", "COMBINED"]) {
    comparisons.push({ Fixture: `V2CLOS${cp}`, Variant: `V${String(v).padStart(2, "0")}`, Arm, Ccp_pF: cp,
      ReturnSensitivityRMSE_deg: 0, ReturnSensitivityPeak_deg: 0, ShortReturnPeakCountError: 0,
      LongReturnPeakCountError: 0, ShortReturnFinalCountError: 0, LongReturnFinalCountError: 0,
      ShortReturnDomainNumericsPass: true, LongReturnDomainNumericsPass: true });
  }
  comparisons[0].LongReturnDomainNumericsPass = false;
  const app = await loadApp({ run: { id: "closure", workflow: "four_way_v2_closure", title: "Source-return comparison", status: "completed",
    closure: { summary: { complete: true }, comparisons }, artifacts: [] } });
  const detail = app.get("run-detail"), table = detail.querySelector("table");
  assert.equal(table.querySelector("tbody").children.length, 128);
  assert.equal(table.querySelector("tbody").children[0].lastElementChild.textContent, "Pass / Fail");
  assert.match(detail.textContent, /excluded from the primary benefit screen/);
  assert.match(detail.textContent, /two disturbed full-record trajectories/);
  assert.match(detail.textContent, /Short means 100 ns and long means 45 µs/);
});

test("development results retain conditional scope without obsolete launch prohibition", async () => {
  const app = await loadApp({ run: { id: "development", workflow: "four_way_v2_development", status: "completed",
    development: { summary: { all_execution_clean_guards_pass: true }, pairs: [] }, artifacts: [] } });
  assert.match(app.get("run-detail").textContent, /launch readiness is checked separately/);
  assert.doesNotMatch(app.get("run-detail").textContent, /cannot be launched|cannot launch here/);
});

test("removed imported-evidence section is not recreated by historical API fields", async () => {
  const app = await loadApp({ state: { evidence: [{ id: "old", label: "Historical checkpoint", value: "Imported" }] } });
  const html = fs.readFileSync(path.join(__dirname, "../web/index.html"), "utf8");
  assert.equal(app.get("evidence-grid"), null);
  assert.doesNotMatch(html, /Recorded verification|historical checkpoint|Earlier project evidence|evidence-grid/);
  assert.equal(app.get("run-button").disabled, false);
  assert.equal(app.get("research-title").textContent, "Completed conditional study");
});
