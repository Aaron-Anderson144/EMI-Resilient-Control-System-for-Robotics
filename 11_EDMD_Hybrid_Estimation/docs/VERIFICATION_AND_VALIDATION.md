# EDMD verification and validation review

13 September 2026 — version 0.2.1

The implementation and its saved numerical evidence have been verified for the documented offline forecast workflow. Validation remains limited to hypothetical healthy actuator simulations. The evidence does not establish an advantage for quadratic EDMD over the simpler linear hybrid, nor suitability for robot deployment.

## Verdict by claim

| Claim | Finding | Evidence |
|---|---|---|
| Code implements the documented observation, history and applied-input timing | Verified within the tested contract | Causal observer/forecast tests, delayed-history boundaries, input-effect oracle and future-data isolation. |
| Ridge regression and delay bookkeeping are numerically correct | Verified within the tested cases | Independent positive-ridge normal-equation oracle, duplicated-data normalization check, known dynamics and exact bookkeeping tests. |
| Simulated plant integration is numerically converged | Supported for the representative tested trajectories | Nominal exact zero-order-hold comparison; nonlinear/stress integration at 4, 8 and 16 substeps, including full three-second reversal/load-step cases. |
| Published fits, selection decisions and forecasts are reproducible | Verified | Complete repeated original experiment, correction study and diagnostics compared with the frozen artifacts. |
| Stored forecast, event and paired metrics are calculated consistently | Independently verified | Separate Python/NumPy recomputation of all 302,080 endpoints and derived tables. |
| Quadratic EDMD passes the original incremental-benefit screen | **Failed in all four regimes** | The screen requires improvement against physics, persistence and linear correction; the linear comparison prevents a pass. |
| The optional weighting rule generally improves the learned predictor | **Not supported** | Nominal error improves, but mismatch and changed-controller accuracy deteriorate substantially. |
| Hardware, receiver faults, EMI resilience or improved closed-loop control | **Not validated** | This package contains healthy-data conditional forecast experiments, without those experiments. |

Passing software checks is separate from meeting a model-performance objective. A reproducible negative result remains a negative result.

## Defects corrected

**Warmup history boundary.** Preparation discards observer samples 1–100. With a reduced time warmup or sufficiently long delay, the old scoring, diagnostics and replay origin formula could include sample 100 in a learned history. A persistent correction could also reach into discarded history. Learned histories now begin at sample 101 or later; the 20-sample persistent baseline begins no earlier than origin 120. For example, delay two with zero time warmup now begins at origin 103. Default 200 ms study origins remain at sample 201, so the saved experiment results are unchanged.

**Ambiguous model-file replay.** The replay adapter previously accepted a six-model correction-study bundle and silently selected its original unweighted models. It also ignored an attached correction policy. It now rejects unsupported extra models and policies explicitly. The documented original four-entry model bundle still replays normally; weighted models remain available through correction-study scoring.

Historical verification wording and saved-path documentation were also corrected. Original contributor attribution is retained: **Larry Anderson — Research collaborator and technical adviser**.

## Automated checks

All **74 tests passed**, eight more than version 0.2. New coverage includes:

- Positive-ridge regression against an independent algebraic solution and invariance to duplicating entire training trajectories.
- Warmup boundaries for zero, short and long delays, the persistent baseline, model diagnostics and replay.
- The exact sample first affected by an applied command, checked with an independent observer-input calculation.
- Duplicate, reversed, offset and gapped timestamps and malformed eligibility flags.
- Rejection of ambiguous replay bundles and ignored correction policies.
- Full three-second nonlinear/stress integration convergence with reversals, both load steps and changed controller gains.

For the two added transient convergence cases, the maximum position difference between four- and eight-substep integration was below **2.8 × 10^-10 radians**. This verifies numerical integration under the simulated equations; it does not validate those equations or parameters against hardware.

## Reproduction and independent evidence audit

The MATLAB verification runner repeats all 18 original fits and validation scores, reconstructs both selected models, regenerates the original 76 records, reproduces the 20 correction-policy candidate scores and selected rules, regenerates the additional 52 records, and compares the stored forecast and diagnostic tables. Reproduction uses the same seeds. These repeats are not additional unseen validation data.

The four groups contain **128 distinct planned seeds**: 24 training, 12 development validation, 40 original evaluation and 52 later evaluation records. Actual measurement/input arrays are also checked for duplicates across groups. Original and regenerated measurement, input, time, truth, seed, sample-time, regime and load arrays are compared.

Numeric reproduction uses absolute tolerance 10^-12 plus relative tolerance 10^-10. Nonfinite values match only with the same infinity sign or paired NaNs; failures remain represented. Timing measurements such as fit duration are excluded from numeric reproduction. Source hashes identify the MATLAB code read at the start; the final review separately checks those hashes against the completed source files.

The independent Python audit recomputed:

| Evidence | Rows checked |
|---|---:|
| Forecast endpoints | 302,080 |
| Per-trajectory forecast rows | 2,360 |
| Overall forecast summaries | 260 |
| Per-trajectory event rows | 7,080 |
| Event summaries | 780 |
| Paired comparisons | 21,000 |

It verifies target/time/error identities, common origins, event partitions, fixed correction decisions across horizons, failure counts, RMSE, bias, spread, nearest-rank P95, maxima, equal-trajectory aggregation and paired differences. It also checks selection eligibility, original benefit calculations, singular-value/ridge arithmetic and lifted-diagnostic aggregation.

The maximum forecast/event arithmetic difference was **9.77 × 10^-15** in the saved numerical units. A larger **3.49 × 10^-10** difference occurs only when recomputing a condition number of approximately 103,210 from rounded CSV singular values. Those quantities have different scales and units and should not be combined into an error-in-radians claim.

Twenty original experiment/reference/pointer artifacts match their preserved version 0.1 hashes. The package manifest identifies the final edited source and reports separately from the original frozen model choices.

## Interpretation of validation

The original quadratic EDMD model failed the specified incremental-benefit screen in nominal, varied, nonlinear and stress conditions. This is consistent with the simpler learned linear model's similar or slightly lower errors.

In the later 52-trajectory study, weighting reduced nominal 50 ms EDMD RMSE from **0.184216° to 0.007741°**, compared with physics at **0.006093°**. But stress error increased from **2.432376° to 5.009684°**; in the combined stress/changed-controller scenario it increased from **1.506884° to 8.156767°**. The weighting rule therefore remains experimental, with a documented nominal-versus-mismatch tradeoff.

All methods receive recorded future voltages during multi-step evaluation. Records are synchronous, uniformly sampled at 1 ms and fully eligible. Initial state is assumed known; default origins exclude startup before 200 ms. Reversal labels use simulation truth offline. Mechanical load transitions are represented, but separate load-event summaries are not implemented. The changed-controller arm also changes regime and seeds, so it does not isolate controller gain alone.

These conditions define the evidence boundary. Operational acceptance would require application-specific error limits and independent recordings, followed by receiver-fault and closed-loop evaluation. Existing results should not be reused as untouched evaluation after further model tuning.

## Repeat the verification

In MATLAB, from this project folder:

```matlab
run_checks          % Unit and numerical checks
run_verification    % Full tests, refits, data and result reproduction
```

`run_verification` creates a separate folder under `results/verifications/`, including its plan, source hashes, test results, audit stages, complete reproduction artifacts and `execution.json`. It updates only `results/verifications/latest_verification.json` after success. The original model/replay pointer is preserved. A plan or partial directory alone is not a completed verification.

This review completed run `results/verifications/tp55928c7e_de86_468d_876a_52017f370741`: **74 tests and 13 audit stages passed**. Its `final_integrity.json` records the additional end-of-run source and original-artifact hash checks. The active `results/test_results.csv` and `results/verification_summary.json` identify this review; earlier verification records are preserved in `provenance/`.

For the independent audit, use Python with the NumPy dependency listed in `verification/requirements.txt`:

```text
python verification/verify_evidence.py --output results/independent_evidence_audit.json
```

The Python audit deliberately targets the currently documented study protocol; see [its instructions](../verification/README.md). MATLAB R2026a with Control System Toolbox and Python 3.12.10 with NumPy 2.5.0 were used for this review.
