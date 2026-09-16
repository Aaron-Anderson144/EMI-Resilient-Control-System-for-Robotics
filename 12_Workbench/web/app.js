"use strict";

(() => {
  const $ = (id) => document.getElementById(id);
  const el = (tag, className, content) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (content !== undefined && content !== null) node.textContent = String(content);
    return node;
  };
  const activeStatuses = new Set(["queued", "running"]);
  const knownStatuses = new Set(["queued", "running", "completed", "failed", "interrupted"]);
  const detailCache = new Map();
  const detailRequests = new Map();
  let state = null;
  let selectedId = null;
  let submitting = false;
  let refreshing = false;
  let connected = false;
  let pollTimer = null;
  let detailSignature = "";
  let historySignature = "";
  let workflowSignature = "";
  let documentSignature = "";
  let comparisonSignature = "";
  let comparisonRequest = 0;

  function safeUrl(value) {
    if (typeof value !== "string" || !value.trim()) return null;
    try {
      const url = new URL(String(value), window.location.href);
      if (url.origin === window.location.origin && ["http:", "https:"].includes(url.protocol)) return url.href;
    } catch (_) { /* Invalid links are omitted. */ }
    return null;
  }

  function fileLink(title, value, className) {
    const url = safeUrl(value);
    if (!url) return el("span", className, title);
    const anchor = el("a", className, title);
    anchor.href = url;
    anchor.target = "_blank";
    anchor.rel = "noopener";
    return anchor;
  }

  function timeLabel(value, compact = false) {
    if (!value) return "Time not recorded";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "Time not recorded";
    return date.toLocaleString(undefined, compact ? { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" } : { month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit", second: "2-digit" });
  }

  function badge(status) {
    const value = String(status || "unknown");
    return el("span", `run-status ${knownStatuses.has(value) ? value : "unknown"}`, value.charAt(0).toUpperCase() + value.slice(1));
  }

  async function api(path, options = {}, timeoutMs = 12000) {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(path, { ...options, signal: controller.signal, cache: "no-store" });
      let payload;
      try { payload = await response.json(); } catch (_) { throw new Error("The workspace returned an unreadable response."); }
      if (!response.ok) throw new Error(payload.error || `The request could not be completed (${response.status}).`);
      return payload;
    } catch (error) {
      if (error.name === "AbortError") throw new Error("The workspace took too long to respond. Refresh to check whether the run started before trying again.");
      if (error instanceof TypeError) throw new Error("Unable to reach the local workspace. Check that the workbench is still open, then try again.");
      throw error;
    } finally { window.clearTimeout(timeout); }
  }

  function setConnectionError(message) {
    connected = false;
    $("connection-error").hidden = false;
    $("connection-error-text").textContent = message;
    $("runtime-status").className = "runtime-pill unavailable";
    $("runtime-status").lastElementChild.textContent = "Workspace disconnected";
    $("last-updated").textContent = "Connection interrupted · showing last received data";
    updateLauncher();
  }

  function renderRuntime(runtime) {
    const available = !!runtime?.matlab_available;
    $("runtime-status").className = `runtime-pill ${available ? "available" : "unavailable"}`;
    $("runtime-status").lastElementChild.textContent = available ? "MATLAB available" : "MATLAB unavailable";
  }

  function renderDocuments(items) {
    const signature = JSON.stringify(items);
    if (signature === documentSignature) return;
    documentSignature = signature;
    const cards = items.map((item) => {
      const card = fileLink("", item.url, "document-card");
      const icon = el("span", "document-icon", "▧");
      icon.setAttribute("aria-hidden", "true");
      const text = el("div");
      text.append(el("h3", "", item.title || "Research document"), el("p", "", item.description || "Open the project document."));
      const arrow = el("span", "document-arrow", "↗");
      arrow.setAttribute("aria-hidden", "true");
      card.append(icon, text, arrow);
      return card;
    });
    $("document-grid").replaceChildren(...(cards.length ? cards : [el("p", "empty-inline", "No research documents were supplied by this workspace.")]));
  }

  function renderWorkflows(workflows) {
    const signature = JSON.stringify(workflows);
    if (signature !== workflowSignature) {
      workflowSignature = signature;
      const previous = $("workflow-select").value;
      const options = workflows.map((workflow) => {
        const option = el("option", "", workflow.title);
        option.value = workflow.id;
        return option;
      });
      $("workflow-select").replaceChildren(...options);
      if (workflows.some((item) => item.id === previous)) $("workflow-select").value = previous;
    }
    updateLauncher();
  }

  function updateLauncher() {
    const workflow = state?.workflows?.find((item) => item.id === $("workflow-select").value);
    const activeRun = state?.runs?.find((run) => activeStatuses.has(run.status));
    const allowed = connected && !submitting && workflow?.enabled === true && !activeRun;
    $("workflow-select").disabled = submitting || !state?.workflows?.length;
    $("run-button").disabled = !allowed;
    $("run-button-label").textContent = submitting ? "Starting experiment…" : activeRun ? "Experiment in progress" : "Run experiment";
    $("run-form").setAttribute("aria-busy", String(submitting));
    $("workflow-description").textContent = workflow?.description || "No workflows are available in this workspace.";
    let reason = "";
    if (!connected && state) reason = "Reconnect to the workspace before starting an experiment.";
    else if (activeRun) reason = "An experiment is already in progress. Its results will update automatically below.";
    else if (workflow && workflow.enabled !== true) reason = workflow.disabled_reason || workflow.reason || "This workflow is currently unavailable.";
    $("workflow-unavailable").hidden = !reason;
    $("workflow-unavailable").textContent = reason;
  }

  function renderActivity(runs) {
    if (!runs.length) return;
    const run = runs.find((item) => activeStatuses.has(item.status)) || runs[0];
    const content = el("div");
    const heading = el("div", "activity-head");
    heading.append(el("span", "eyebrow", activeStatuses.has(run.status) ? "IN PROGRESS" : "LATEST RUN"), badge(run.status));
    content.append(heading, el("h3", "", run.title || run.workflow || "Experiment"));
    if (activeStatuses.has(run.status)) {
      const progress = el("div", "activity-progress");
      progress.setAttribute("aria-hidden", "true");
      progress.append(el("span"));
      content.append(progress);
    }
    content.append(el("p", "", run.summary || (activeStatuses.has(run.status) ? "The experiment is running. Logs and saved results will appear as they become available." : "Select this run to inspect its saved outputs and execution log.")), el("div", "activity-time", timeLabel(run.started_at, true)));
    $("activity-content").replaceChildren(content);
  }

  function renderHistory(runs) {
    $("run-count").textContent = String(runs.length);
    const signature = JSON.stringify([selectedId, runs.map((run) => [run.id, run.title, run.status, run.started_at])]);
    if (signature === historySignature) return;
    historySignature = signature;
    if (!runs.length) return;
    const focusedId = document.activeElement?.dataset?.runId;
    const scroll = $("run-history").scrollTop;
    const items = runs.map((run) => {
      const button = el("button", `history-item${run.id === selectedId ? " selected" : ""}`);
      button.type = "button";
      button.dataset.runId = run.id;
      button.setAttribute("aria-pressed", String(run.id === selectedId));
      button.append(el("span", "history-title", run.title || run.workflow || "Experiment"));
      const bottom = el("span", "history-item-bottom");
      bottom.append(el("span", "history-time", timeLabel(run.started_at, true)), badge(run.status));
      button.append(bottom);
      button.addEventListener("click", () => selectRun(run.id));
      return button;
    });
    $("run-history").classList.add("run-history-overflow");
    $("run-history").replaceChildren(...items);
    $("run-history").scrollTop = scroll;
    if (focusedId) items.find((item) => item.dataset.runId === focusedId)?.focus({ preventScroll: true });
  }

  const metricLabels = {
    logicalrecords: "Logical records", pairedresults: "Matched comparisons", comparisonpairs: "Return comparisons", receiverhypotheses: "Receiver assumptions", failedrecords: "Failed records", failedpairs: "Failed comparisons", developmentguardspass: "Development execution guards", evaluationguardspass: "Evaluation execution guards", passinghypotheses: "Assumptions meeting benefit screen", allhypothesesbenefitpass: "All assumptions meet benefit screen", closuredomainnumericspass: "Return comparison validity guards",
    totalcases: "Characterization cases", validcases: "Within domain and converged", invalidcases: "Outside model domain", unresolvedcases: "Unresolved cases", cleanerrorcases: "Clean cases with errors", exposederrorcases: "Disturbed cases with count error", pulselawdependentcases: "Pulse-model dependent cases",
    parametersetid: "Parameter set", stable: "Linear model stable", maximumpolemagnitude: "Largest pole magnitude", trackingrmse_rad: "Tracking RMSE", finalerror_rad: "Final position error", peakvoltagecommand_v: "Peak voltage command", settlingtime_s: "Settling time", linearcommandexceedsnominalvoltage: "Command exceeds nominal voltage", tests: "Total tests", elapsedseconds: "Elapsed time",
    rmse: "Tracking RMSE", tracking_rmse: "Tracking RMSE", tracking_rmse_rad: "Tracking RMSE", position_rmse_rad: "Position RMSE", peak_error_rad: "Peak position error", peak_current_a: "Peak current", max_current_a: "Peak current", settling_time_s: "Settling time", overshoot_percent: "Overshoot", duration_s: "Recorded duration", sample_count: "Recorded samples", passed: "Passed", failed: "Failed", incomplete: "Incomplete", total: "Total checks", tests_passed: "Tests passed", tests_failed: "Tests failed", tests_incomplete: "Tests incomplete", tests_total: "Total tests", steady_state_error: "Steady-state error", peak_voltage_v: "Peak voltage", rise_time_s: "Rise time", percent_overshoot: "Overshoot"
  };

  function metricRows(metrics, prefix = "", depth = 0) {
    if (!metrics || typeof metrics !== "object" || Array.isArray(metrics)) return [];
    return Object.entries(metrics).flatMap(([key, raw]) => {
      const id = prefix ? `${prefix}.${key}` : key;
      if (raw === null || raw === undefined) return [];
      if (raw && typeof raw === "object" && !Array.isArray(raw) && !("value" in raw)) return depth < 2 ? metricRows(raw, id, depth + 1) : [];
      const value = raw && typeof raw === "object" ? raw.value : raw;
      if (!["number", "string", "boolean"].includes(typeof value)) return [];
      const inferredUnit = /_rad$/.test(key) ? "rad" : /_s$/.test(key) || key === "elapsedSeconds" ? "s" : /_a$/i.test(key) ? "A" : /_v$/i.test(key) ? "V" : /percent/.test(key) ? "%" : "";
      const label = raw?.label || metricLabels[key.toLowerCase()] || key.replace(/_/g, " ").replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, (letter) => letter.toUpperCase());
      return [{ id, label, value, unit: raw?.unit || inferredUnit }];
    });
  }

  function formatValue(value) {
    if (typeof value === "boolean") return value ? "Yes" : "No";
    if (typeof value !== "number") return String(value);
    if (!Number.isFinite(value)) return "Not available";
    if (value !== 0 && (Math.abs(value) < .0001 || Math.abs(value) >= 10000000)) return value.toExponential(3);
    return value.toLocaleString(undefined, { maximumSignificantDigits: 6 });
  }

  async function getDetail(id, force = false) {
    if (!force && detailCache.has(id) && !activeStatuses.has(detailCache.get(id).status)) return detailCache.get(id);
    if (detailRequests.has(id)) return detailRequests.get(id);
    const request = api(`/api/runs/${encodeURIComponent(id)}`).then((run) => { detailCache.set(id, run); return run; }).finally(() => detailRequests.delete(id));
    detailRequests.set(id, request);
    return request;
  }

  function renderCharacterization(study) {
    if (!study || typeof study !== "object" || !study.studyId) return null;
    const section = el("section", "characterization-findings");
    const asArray = (value) => value === undefined || value === null ? [] : Array.isArray(value) ? value : [value];
    section.append(el("span", "eyebrow", "RECEIVER V2 / CONDITIONAL SIMULATION"), el("h4", "", "Characterization findings"));
    section.append(el("p", "characterization-scope", study.scope || "The receiver behavior is a declared simulation assumption; measured characterization is still required."));
    const findings = asArray(study.findings).filter((item) => typeof item === "string");
    if (findings.length) {
      const list = el("ul", "finding-list");
      findings.forEach((finding) => list.append(el("li", "", finding)));
      section.append(list);
    }
    const decision = study.suitableForFourWay === true ? "The clean-case numerical prerequisite passed in simulation." : "The clean-case numerical prerequisite was not established by this run.";
    section.append(el("p", "characterization-gate", `${decision} Every disturbed control case still needs its own domain and behavior checks. The control comparison remains gated; completion of this sweep does not establish physical validity or mitigation benefit.`));
    const limitations = asArray(study.limitations).filter((item) => typeof item === "string");
    if (limitations.length) {
      section.append(el("h5", "", "Interpretation limits"));
      const list = el("ul", "finding-list limits-list");
      limitations.forEach((limitation) => list.append(el("li", "", limitation)));
      section.append(list);
    }
    const cases = asArray(study.cases).filter((item) => item && typeof item === "object");
    if (cases.length) {
      const wrapper = el("div", "characterization-table");
      wrapper.tabIndex = 0;
      wrapper.setAttribute("role", "region");
      wrapper.setAttribute("aria-label", "Scrollable receiver characterization cases");
      const table = el("table");
      table.append(el("caption", "", "Matched clean and disturbed cases. Domain status refers to the declared model limits."));
      const head = el("thead");
      const heading = el("tr");
      for (const label of ["Case / fixture", "Cdiff / Ccp (pF)", "Input", "Pulse / threshold / delay", "Domain / numerics", "Final count error", "Extra / missed edges"]) {
        const cell = el("th", "", label);
        cell.scope = "col";
        heading.append(cell);
      }
      head.append(heading);
      const body = el("tbody");
      for (const item of cases) {
        const row = el("tr");
        const identity = el("td", "case-identity", item.caseId || "Unrecorded");
        identity.append(el("small", "", item.fixtureId || ""));
        const polarity = item.polarity === 1 ? "positive" : item.polarity === -1 ? "negative" : item.polarity;
        const input = item.exposed === true ? `Disturbed${polarity ? ` · ${polarity}` : ""}` : item.exposed === false ? "Clean" : "Unrecorded";
        const capacitors = `${formatValue(item.capacitance_pF ?? "—")} / ${formatValue(item.couplingP_pF ?? "—")}`;
        const delay = typeof item.latency_ns === "number" ? `${formatValue(item.latency_ns)} ns` : "";
        const convergence = item.numericalConverged === true ? "converged" : item.numericalConverged === false ? "unresolved" : "not recorded";
        const values = [capacitors, input, [item.pulseLaw, item.thresholdVariant, delay].filter(Boolean).join(" / "), `${item.domainStatus || "not recorded"} / ${convergence}`, item.finalCountError];
        row.append(identity);
        values.forEach((value) => row.append(el("td", "", value === undefined || value === null ? "Unrecorded" : formatValue(value))));
        row.append(el("td", "", `${formatValue(item.extraEdges ?? "—")} / ${formatValue(item.missedEdges ?? "—")}`));
        body.append(row);
      }
      table.append(head, body);
      wrapper.append(table);
      section.append(wrapper, el("p", "characterization-footnote", "Cdiff is the differential filter capacitor; Ccp is the disturbance coupling to the positive input. Open cases.csv below for voltage extrema, first violation time, time outside the model domain, and numerical convergence. Per-case outputs retain event timing."));
    }
    return section;
  }

  const resultArray = (value) => (Array.isArray(value) ? value : value ? [value] : []).filter((item) => item && typeof item === "object");
  const resultFlag = (value) => value === true || value === 1 ? "Pass" : value === false || value === 0 ? "Fail" : "Unrecorded";
  const resultNumber = (value) => value === null || value === undefined ? "—" : formatValue(value);
  const armLabel = (arm) => ({ BASELINE: "Baseline", EM_ONLY: "Circuit only", SW_ONLY: "Software only", COMBINED: "Combined" })[arm] || arm || "Unrecorded";

  function resultIdentity(primary, secondary) {
    const cell = el("td", "case-identity", primary || "Unrecorded");
    if (secondary) cell.append(el("small", "", secondary));
    return cell;
  }

  function resultTable(label, caption, headings, rows) {
    const wrapper = el("div", "characterization-table");
    wrapper.tabIndex = 0;
    wrapper.setAttribute("role", "region");
    wrapper.setAttribute("aria-label", label);
    const table = el("table"), head = el("thead"), heading = el("tr"), body = el("tbody");
    table.append(el("caption", "", caption));
    headings.forEach((label) => { const cell = el("th", "", label); cell.scope = "col"; heading.append(cell); });
    head.append(heading);
    rows.forEach((cells) => {
      const row = el("tr");
      cells.forEach((cell) => row.append(cell instanceof Node ? cell : el("td", "", cell)));
      body.append(row);
    });
    table.append(head, body); wrapper.append(table);
    return wrapper;
  }

  function renderPairedResults(pairs, partition) {
    const items = resultArray(pairs);
    if (!items.length) return el("p", "empty-inline", "No matched comparisons were saved in this result.");
    return resultTable(`Scrollable ${partition} results by receiver assumption`,
      `${items.length} saved matched ${partition} comparisons. Receiver assumptions remain separate; no pooled benefit is calculated.`,
      ["Fixture / assumption", "Control arm", "Domain / numerics", "Clean / execution guards", "Paired RMSE / peak (°)", "Peak current (A)", "EMI count peak / final", "Task success"],
      items.map((item) => [resultIdentity(item.Fixture, item.Variant), armLabel(item.Arm),
        `${resultFlag(item.ReceiverDomainPass)} / ${resultFlag(item.ReceiverNumericsPass)}`,
        `${resultFlag(item.CleanGuardPass)} / ${resultFlag(item.ExecutionGuardPass)}`,
        `${resultNumber(item.WindowPairedRMSE_deg)} / ${resultNumber(item.WindowPairedPeak_deg)}`,
        resultNumber(item.PeakCurrent_A), `${resultNumber(item.EMICountPeak_counts)} / ${resultNumber(item.EMICountFinal_counts)}`, resultFlag(item.TaskSuccess)]));
  }

  function renderDevelopment(study) {
    if (!study?.summary) return null;
    const section = el("section", "characterization-findings");
    section.append(el("span", "eyebrow", "FOUR-WAY V2 / DEVELOPMENT"), el("h4", "", "Results by receiver assumption"));
    section.append(el("p", "characterization-scope", "These two development fixtures compare the baseline, circuit mitigation, software mitigation, and combined arms. Each disturbed record is paired with its clean companion under the same receiver assumption."));
    section.append(el("p", "characterization-gate", `Development execution and clean-case guards: ${resultFlag(study.summary.all_execution_clean_guards_pass)}. This is conditional simulation evidence; it does not establish measured receiver validity or a mitigation benefit. Evaluation launch readiness is checked separately for the selected workflow.`));
    section.append(renderPairedResults(study.pairs, "development"));
    section.append(el("p", "characterization-footnote", "Open metrics.csv for all motion, control, count, recovery, and guard measures; record_index.csv retains every execution, including failures. Saved record files contain causal packet, event, and motor traces."));
    return section;
  }

  function renderEvaluation(study) {
    if (!study?.summary) return null;
    const section = el("section", "characterization-findings");
    section.append(el("span", "eyebrow", "FOUR-WAY V2 / EVALUATION"), el("h4", "", "Evaluation by receiver assumption"));
    section.append(el("p", "characterization-scope", "The twelve evaluation fixtures retain all 16 receiver assumptions and four control arms. Disturbed runs are compared with their own clean companions. These are conditional simulation results; physical receiver behavior remains unmeasured."));
    section.append(el("p", "characterization-gate", `Evaluation execution and clean-case guards: ${resultFlag(study.summary.all_execution_clean_guards_pass)}. Completing the workflow does not mean that the combined treatment met the benefit screen.`));
    const hypotheses = resultArray(study.hypotheses ?? study.summary.assessment?.hypotheses);
    section.append(el("h5", "", "Combined-benefit screens"));
    if (hypotheses.length) {
      const passing = hypotheses.filter((item) => item.combined_benefit_demonstrated === true || item.combined_benefit_demonstrated === 1).length;
      section.append(el("p", "", `${passing} of ${hypotheses.length} saved receiver assumptions met the combined-benefit screen. This count is not a probability of real-world success.`));
      section.append(resultTable("Scrollable benefit screens by receiver assumption", "Each receiver assumption keeps its own benefit decision and guard results.",
        ["Assumption / behavior", "Normalized RMSE: baseline / combined", "Execution guards", "Aggregate", "RMSE / peak / current", "Rescued tasks / rescue gate", "Combined benefit"],
        hypotheses.map((item) => {
          const variant = item.variant || {};
          const delay = typeof variant.latencyRise_s === "number" && typeof variant.latencyFall_s === "number" ? `${resultNumber(variant.latencyRise_s * 1e9)}/${resultNumber(variant.latencyFall_s * 1e9)} ns` : "";
          const behavior = [variant.threshold_id, variant.pulseLaw, delay].filter(Boolean).join(" · ");
          return [resultIdentity(variant.id, behavior), `${resultNumber(item.baseline_normalized_mean)} / ${resultNumber(item.combined_normalized_mean)}`,
            resultFlag(item.all_execution_clean_guards_pass), resultFlag(item.aggregate_gate),
            `${resultFlag(item.per_fixture_rmse_gate)} / ${resultFlag(item.per_fixture_peak_gate)} / ${resultFlag(item.current_gate)}`,
            `${resultNumber(item.rescued_failures)} / ${resultFlag(item.rescued_failure_gate)}`, resultFlag(item.combined_benefit_demonstrated)];
        })));
    } else section.append(el("p", "empty-inline", "Benefit screens were not saved in this result."));
    section.append(el("p", "characterization-footnote", "A benefit requires the aggregate improvement and every per-fixture guard, plus at least one failed baseline task rescued by the combined treatment. When both paired errors are zero, the aggregate inequality alone does not show a reduction. Equality with circuit-only results does not establish an added software contribution."));
    section.append(el("h5", "", "Matched evaluation comparisons"), renderPairedResults(study.pairs, "evaluation"));
    section.append(el("p", "characterization-footnote", "The complete evaluation contains 768 matched comparisons and 1,536 logical records. Paired position measures subtract the matching arm's clean trajectory; count errors use its no-aggressor receiver shadow. Current is the absolute motor-current peak. Open metrics.csv and record_index.csv below for all saved measures and record identities."));
    return section;
  }

  function renderClosure(study) {
    if (!study?.summary) return null;
    const section = el("section", "characterization-findings");
    section.append(el("span", "eyebrow", "FOUR-WAY V2 / SOURCE RETURN"), el("h4", "", "Source-return comparison"));
    section.append(el("p", "characterization-scope", "These separate diagnostics compare a 100 ns source return with a 45 µs return at 40 and 240 pF disturbance coupling, with positive task sign and zero phase. All 16 receiver assumptions and four arms remain separate."));
    section.append(el("p", "characterization-gate", "This comparison is excluded from the primary benefit screen. Its position differences compare two disturbed full-record trajectories, not a disturbed trajectory against a clean companion. Physical receiver behavior remains unmeasured."));
    const comparisons = resultArray(study.comparisons);
    if (comparisons.length) {
      section.append(resultTable("Scrollable source-return comparisons", `${comparisons.length} saved return comparisons. The complete diagnostic contains 128 comparisons and 256 logical records.`,
        ["Fixture / assumption", "Control arm / coupling", "Return difference RMSE / peak (°)", "Peak count: short / long", "Final count: short / long", "Domain + numerics: short / long"],
        comparisons.map((item) => [resultIdentity(item.Fixture, item.Variant), `${armLabel(item.Arm)} / ${resultNumber(item.Ccp_pF)} pF`,
          `${resultNumber(item.ReturnSensitivityRMSE_deg)} / ${resultNumber(item.ReturnSensitivityPeak_deg)}`,
          `${resultNumber(item.ShortReturnPeakCountError)} / ${resultNumber(item.LongReturnPeakCountError)}`,
          `${resultNumber(item.ShortReturnFinalCountError)} / ${resultNumber(item.LongReturnFinalCountError)}`,
          `${resultFlag(item.ShortReturnDomainNumericsPass)} / ${resultFlag(item.LongReturnDomainNumericsPass)}`])));
    } else section.append(el("p", "empty-inline", "No source-return comparisons were saved in this result."));
    section.append(el("p", "characterization-footnote", "Short means 100 ns and long means 45 µs. A failed domain or numerical guard limits that row to diagnostics. Open closure_comparisons.csv and record_index.csv below for the saved comparisons and every execution."));
    return section;
  }

  function renderDetail(run) {
    if (run.id !== selectedId) return;
    const signature = JSON.stringify(run);
    if (signature === detailSignature) return;
    detailSignature = signature;
    const wasLogOpen = $("run-detail").querySelector("details.run-log")?.open || false;
    const focusedElement = $("run-detail").contains(document.activeElement) ? document.activeElement : null;
    const focusedTag = focusedElement?.tagName;
    const focusedHref = focusedElement?.getAttribute("href");
    const previousLog = $("run-detail").querySelector("pre");
    const scrollPosition = previousLog?.scrollTop || 0;
    const followingLog = previousLog ? previousLog.scrollTop + previousLog.clientHeight >= previousLog.scrollHeight - 15 : false;
    const fragment = document.createDocumentFragment();
    const header = el("div", "detail-header");
    const title = el("div");
    title.append(el("h3", "", run.title || run.workflow || "Experiment"), el("div", "detail-time", `Started ${timeLabel(run.started_at)}`));
    if (run.finished_at) title.append(el("div", "detail-time", `Finished ${timeLabel(run.finished_at)}`));
    header.append(title, badge(run.status));
    fragment.append(header, el("p", "detail-summary", run.summary || (activeStatuses.has(run.status) ? "This experiment is in progress. Results update automatically." : "This run has no recorded summary.")));
    const metrics = metricRows(run.metrics);
    if (metrics.length) {
      const grid = el("div", "metric-grid");
      for (const metric of metrics) {
        const card = el("div", "metric");
        const formatted = formatValue(metric.value);
        const value = el("strong", `metric-value${formatted.length > 16 ? " long-value" : ""}`, formatted);
        if (typeof metric.value === "number" && Number.isFinite(metric.value)) {
          value.classList.add("number-readout");
          value.style.setProperty("--number-width", String(Math.max(1, formatted.length * .55)));
          value.style.setProperty("--unit-space", `${metric.unit ? metric.unit.length * 7 + 5 : 0}px`);
          value.replaceChildren(el("span", "measurement-number", formatted));
        }
        if (metric.unit) value.append(el("small", "", metric.unit));
        card.append(el("span", "metric-label", metric.label), value);
        grid.append(card);
      }
      fragment.append(grid);
    }
    if (run.workflow === "receiver_characterization") {
      const characterization = renderCharacterization(run.characterization);
      if (characterization) fragment.append(characterization);
    }
    if (run.workflow === "four_way_v2_development") {
      const development = renderDevelopment(run.development);
      if (development) fragment.append(development);
    }
    if (run.workflow === "four_way_v2_evaluation") {
      const evaluation = renderEvaluation(run.evaluation);
      if (evaluation) fragment.append(evaluation);
    }
    if (run.workflow === "four_way_v2_closure") {
      const closure = renderClosure(run.closure);
      if (closure) fragment.append(closure);
    }
    if (["failed", "interrupted"].includes(run.status)) fragment.append(el("p", "detail-notice", "This run did not finish successfully. Inspect the execution log before using any partial outputs."));
    const artifacts = Array.isArray(run.artifacts) ? run.artifacts : [];
    fragment.append(el("h4", "artifact-heading", "Saved outputs"));
    if (artifacts.length) {
      const links = el("div", "artifact-list");
      const fourWay = ["four_way_v2_development", "four_way_v2_evaluation", "four_way_v2_closure"].includes(run.workflow);
      const caseArtifacts = run.workflow === "receiver_characterization" ? artifacts.filter((artifact) => /\/details\//.test(artifact.name || "")) : fourWay ? artifacts.filter((artifact) => new RegExp(`/${run.workflow}/[^/]+/`).test(artifact.name || "")) : [];
      for (const artifact of artifacts.filter((item) => !caseArtifacts.includes(item))) links.append(fileLink(`${artifact.name} ↗`, artifact.url, "artifact-link"));
      fragment.append(links);
      if (caseArtifacts.length) {
        const details = el("details", "case-artifacts");
        const caseLinks = el("div", "artifact-list");
        caseArtifacts.forEach((artifact) => caseLinks.append(fileLink(`${artifact.name} ↗`, artifact.url, "artifact-link")));
        details.append(el("summary", "", `Per-case traces and event timing (${caseArtifacts.length} files)`), caseLinks);
        fragment.append(details);
      }
      const plot = artifacts.find((artifact) => /\.png$/i.test(artifact.name || "") && safeUrl(artifact.url));
      if (plot) {
        const anchor = fileLink("", plot.url, "artifact-image-link");
        const image = el("img", "artifact-image");
        image.src = safeUrl(plot.url);
        image.alt = `Saved result plot: ${plot.name}`;
        image.loading = "lazy";
        image.addEventListener("error", () => { anchor.replaceChildren(el("span", "empty-inline", "Plot preview could not load. Open the saved output above.")); });
        anchor.append(image);
        fragment.append(anchor);
      }
    } else fragment.append(el("p", "no-artifacts", activeStatuses.has(run.status) ? "Outputs will appear as they are saved." : "No output files were recorded for this run."));
    const log = el("details", "run-log");
    log.setAttribute("aria-live", "off");
    log.open = wasLogOpen;
    const logContent = el("pre", "", run.log || "No log output has been recorded yet.");
    logContent.setAttribute("tabindex", "0");
    logContent.setAttribute("aria-label", "Execution log");
    log.append(el("summary", "", "Execution log"), logContent);
    fragment.append(log);
    $("run-detail").replaceChildren(fragment);
    logContent.scrollTop = followingLog ? logContent.scrollHeight : scrollPosition;
    if (focusedTag === "SUMMARY") log.querySelector("summary").focus({ preventScroll: true });
    else if (focusedTag === "PRE") logContent.focus({ preventScroll: true });
    else if (focusedHref) Array.from($("run-detail").querySelectorAll("a")).find((anchor) => anchor.getAttribute("href") === focusedHref)?.focus({ preventScroll: true });
  }

  async function selectRun(id) {
    if (selectedId === id && detailCache.has(id)) return;
    selectedId = id;
    detailSignature = "";
    renderHistory(state?.runs || []);
    $("run-detail").replaceChildren(el("div", "detail-loading", "Loading saved result…"));
    try { renderDetail(await getDetail(id)); }
    catch (error) { if (selectedId === id) $("run-detail").replaceChildren(el("p", "detail-error", error.message)); }
  }

  function renderComparisonOptions(runs) {
    const completed = runs.filter((run) => run.status === "completed");
    const counts = new Map();
    completed.forEach((run) => counts.set(run.workflow, (counts.get(run.workflow) || 0) + 1));
    const eligible = completed.filter((run) => counts.get(run.workflow) >= 2);
    $("comparison-panel").hidden = eligible.length < 2;
    if (eligible.length < 2) return;
    const signature = JSON.stringify(eligible.map((run) => [run.id, run.workflow, run.title, run.started_at]));
    if (signature === comparisonSignature) return;
    comparisonSignature = signature;
    const firstValue = $("compare-first").value;
    $("compare-first").replaceChildren(...eligible.map(comparisonOption));
    if (eligible.some((run) => run.id === firstValue)) $("compare-first").value = firstValue;
    updateSecondComparison();
  }

  function comparisonOption(run) {
    const option = el("option", "", `${run.title || run.workflow} · ${timeLabel(run.started_at)} · ${String(run.id).slice(-6)}`);
    option.value = run.id;
    return option;
  }

  function updateSecondComparison() {
    const first = state.runs.find((run) => run.id === $("compare-first").value);
    const previous = $("compare-second").value;
    const candidates = state.runs.filter((run) => run.status === "completed" && run.workflow === first?.workflow && run.id !== first?.id);
    $("compare-second").replaceChildren(...candidates.map(comparisonOption));
    if (candidates.some((run) => run.id === previous)) $("compare-second").value = previous;
    void renderComparison();
  }

  async function renderComparison() {
    const request = ++comparisonRequest;
    const firstId = $("compare-first").value;
    const secondId = $("compare-second").value;
    if (!firstId || !secondId) return;
    $("comparison-content").replaceChildren(el("p", "empty-inline", "Reading saved metrics…"));
    try {
      const [first, second] = await Promise.all([getDetail(firstId), getDetail(secondId)]);
      if (request !== comparisonRequest) return;
      const firstMetrics = metricRows(first.metrics);
      const secondMetrics = metricRows(second.metrics);
      const keys = new Set([...firstMetrics, ...secondMetrics].map((item) => item.id));
      if (!keys.size) {
        $("comparison-content").replaceChildren(el("p", "empty-inline", "These runs have no saved summary metrics. Select a run above to compare its output files and execution log."));
        return;
      }
      const table = el("table");
      const caption = el("caption", "", "Saved metrics for the selected first and second runs");
      const head = el("thead");
      const headRow = el("tr");
      for (const label of ["Metric", "First run", "Second run"]) {
        const cell = el("th", "", label);
        cell.scope = "col";
        headRow.append(cell);
      }
      head.append(headRow);
      const body = el("tbody");
      for (const key of keys) {
        const a = firstMetrics.find((metric) => metric.id === key);
        const b = secondMetrics.find((metric) => metric.id === key);
        const row = el("tr");
        row.append(el("td", "", (a || b).label));
        for (const metric of [a, b]) row.append(el("td", "", metric ? `${formatValue(metric.value)}${metric.unit ? ` ${metric.unit}` : ""}` : "Not recorded"));
        body.append(row);
      }
      table.append(caption, head, body);
      $("comparison-content").replaceChildren(table);
    } catch (error) {
      if (request === comparisonRequest) $("comparison-content").replaceChildren(el("p", "detail-error", error.message));
    }
  }

  async function refresh() {
    if (refreshing) return;
    refreshing = true;
    $("refresh-results").disabled = true;
    try {
      const nextState = await api("/api/state");
      if (!nextState || !Array.isArray(nextState.workflows) || !Array.isArray(nextState.runs)) throw new Error("The workspace did not supply a valid project state.");
      state = nextState;
      connected = true;
      $("connection-error").hidden = true;
      renderRuntime(state.runtime);
      $("research-title").textContent = state.research?.title || "Research status not recorded";
      $("research-detail").textContent = state.research?.detail || "Review the project documents for current research context.";
      $("research-next").textContent = state.research?.next_step || "Review the current project plan.";
      renderDocuments(state.documents || []);
      renderWorkflows(state.workflows);
      renderActivity(state.runs);
      if (!selectedId && state.runs.length) selectedId = state.runs[0].id;
      renderHistory(state.runs);
      renderComparisonOptions(state.runs);
      $("last-updated").textContent = `Last checked ${new Date().toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })}`;
      if (selectedId) {
        try { renderDetail(await getDetail(selectedId, true)); }
        catch (error) { $("run-detail").replaceChildren(el("p", "detail-error", `Could not refresh this result. ${error.message}`)); detailSignature = ""; }
      }
    } catch (error) { setConnectionError(error.message); }
    finally { refreshing = false; $("refresh-results").disabled = false; }
  }

  async function launch(event) {
    event.preventDefault();
    if (submitting || $("run-button").disabled) return;
    const workflow = $("workflow-select").value;
    submitting = true;
    $("launch-message").className = "launch-message";
    $("launch-message").textContent = "Starting your experiment…";
    updateLauncher();
    try {
      // Gated workflows verify local evidence before returning a run identity.
      // Allow that bounded preflight to finish; routine polling stays responsive.
      const run = await api("/api/runs", { method: "POST", headers: { "Content-Type": "application/json", "X-EMI-Token": state.token }, body: JSON.stringify({ workflow }) }, 240000);
      if (!run.id) throw new Error("The workspace did not return a run identifier. Refresh before starting another run.");
      selectedId = run.id;
      detailSignature = "";
      state.runs = [run, ...state.runs.filter((item) => item.id !== run.id)];
      renderHistory(state.runs);
      renderActivity(state.runs);
      $("launch-message").textContent = "Experiment started. Results will update automatically below.";
      await refresh();
    } catch (error) {
      $("launch-message").className = "launch-message is-error";
      $("launch-message").textContent = error.message;
      await refresh();
    } finally { submitting = false; updateLauncher(); }
  }

  function schedulePoll() {
    if (pollTimer) window.clearTimeout(pollTimer);
    if (!document.hidden) pollTimer = window.setTimeout(async () => { await refresh(); schedulePoll(); }, 3000);
  }

  $("run-form").addEventListener("submit", launch);
  $("workflow-select").addEventListener("change", () => { $("launch-message").textContent = ""; updateLauncher(); });
  $("refresh-results").addEventListener("click", () => void refresh());
  $("retry-connection").addEventListener("click", () => void refresh());
  $("compare-first").addEventListener("change", updateSecondComparison);
  $("compare-second").addEventListener("change", () => void renderComparison());
  document.addEventListener("visibilitychange", () => { if (!document.hidden) void refresh(); schedulePoll(); });
  document.querySelectorAll(".nav-link").forEach((link) => link.addEventListener("click", () => {
    document.querySelectorAll(".nav-link").forEach((item) => item.classList.toggle("active", item === link));
  }));
  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver((entries) => {
      const visible = entries.filter((entry) => entry.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
      if (visible.length) document.querySelectorAll(".nav-link").forEach((link) => link.classList.toggle("active", link.hash === `#${visible[0].target.id}`));
    }, { rootMargin: "-5% 0px -60% 0px", threshold: 0 });
    document.querySelectorAll(".section").forEach((section) => observer.observe(section));
  }
  void refresh().finally(schedulePoll);
})();
