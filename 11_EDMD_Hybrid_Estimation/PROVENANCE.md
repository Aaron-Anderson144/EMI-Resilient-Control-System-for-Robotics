# Provenance and reproducibility

This folder holds the hybrid-estimation work for the EMI-Resilient Control System for Robotics project. Larry Anderson is credited as **Research collaborator and technical adviser** in [CONTRIBUTIONS.md](CONTRIBUTIONS.md).

## Included reference material

- `reference_project/03_MATLAB/parameters/actuator_parameters.m` and the two functions in `reference_project/03_MATLAB/functions/` are unchanged copies from the user's robotics project. Its repository HEAD at collection was `6e437538b300084b3c7788043262feccdced5c6f`. The project had pre-existing uncommitted changes; HEAD alone does not identify every working-tree file. Delivered hashes identify the actual included copies.
- `code/edmd_*.m` originates in the preceding EDMD prototype. `study_generate_records.m` and its generator tests originate in the preceding robot study. The generator test now locates the bundled parameters rather than an external project path.
- `docs/EDMD_Primer_PMU.docx` is the source primer from `C:\Users\adand\OneDrive\Documents\EDMD_Primer_PMU.docx`, included for reference.
- `docs/PREVIOUS_ASSESSMENT.md` records the earlier direct-prediction study. Its run identifiers and external links belong to that study. Use the current hybrid results to judge this implementation.
- The EDMD and input-aware methods build on the primary research linked in [DESIGN.md](docs/DESIGN.md). This package tests a custom hybrid implementation; it does not reproduce the numerical experiments in those papers.

## Run record

The included hybrid study is `tp76c650cf_8abb_4d22_8d57_24d2dc9d3462`. It uses fresh seed ranges that are separate from the earlier study. The plan was written before data generation, and the selected models were saved before test generation. These records show the order of execution. The protocol was not independently registered.

The original study uses paths relative to the package root for bundled references. Later diagnostic, correction and verification execution records also retain absolute source/output paths to identify the local runs; those recorded locations may need resolving again if the package is moved.

`source_snapshot_initial.json` records the code captured during the initial execution, before model selection. It is not an advance registration. Later reporting fixes kept failed bars visible, handled unavailable bootstrap intervals, and applied the EDMD nonfinite screen per regime as the plan described. A harmless duplicate figure-close warning was also removed. These fixes left the trained models, predictions and numerical conclusions unchanged. The controller replay adapter and its tests were added after the study.

`package_manifest.json` lists the delivered file hashes, excluding its own. It identifies the current package separately from the frozen training and test choices. Rerunning the experiment keeps earlier result folders, but does not automatically freeze a new manifest for every later edit.

## Scope of this release

Version 0.2.1 adds the completed verification/validation review and a reproducible `run_verification.m` entry point. It corrects nondefault warmup-history boundaries in scoring, diagnostics and replay, and rejects unsupported weighted replay bundles. All 74 tests and 13 MATLAB audit stages passed. The independent Python audit recomputed all 302,080 saved forecast endpoints and their derived tables. The complete verification is `results/verifications/tp55928c7e_de86_468d_876a_52017f370741`; source hashes captured at its start were checked again at completion. Version 0.2 manifests, verification summary and test records are preserved in `provenance/`. The [verification and validation report](docs/VERIFICATION_AND_VALIDATION.md) separates passing software/reproduction checks from the failed incremental EDMD benefit screen and unestablished operational validation.

Version 0.2, dated 13 September 2026, adds forecast/event diagnostics, spectrum and recursive-feature diagnostics, optional causal correction weighting, and explicit transient generator options. Its 66 automated checks and both experiment runners completed in MATLAB R2026a. The original trained models, original experiment directory, reference files and `results/latest_run.json` are unchanged. The original version 0.1 manifest and verification summary are preserved in `provenance/`.

The diagnostic run is `results/diagnostics/tpcca256fb_a82d_4e50_bb0a_9c7b23c3c087`; the correction run is `results/correction_studies/tpcf97f728_83e8_4922_a0cb_3b68a6b9c318`. Selection used original development validation, then generated 52 separately seeded evaluation trajectories. Reporting fixes repeated the same selected policies and seeds, with byte-identical candidate, prediction and paired-comparison CSVs. They did not create additional independent test evidence. Superseded diagnostic and incomplete development exports were moved to task scratch storage; completed runs are retained in this package. See [update results](docs/RESULTS_20260913.md) for actual benefits and tradeoffs and [implementation details](docs/IMPLEMENTATION_20260913.md) for lecture links and information boundaries.

The folder includes the reference MATLAB sources, learned models and simulated data needed to run the experiment. Use MATLAB R2026a and Control System Toolbox. The original robotics project does not need to be present.

The hybrid experiment did not open the original project's evaluation or closure data. Its implementation added `11_EDMD_Hybrid_Estimation` and preserved the existing project files. This remains offline work without a controller connection or hardware run. GitHub publication preserves the code, simulated evidence and negative findings; it does not change their validation status. Git history identifies the published revision.
