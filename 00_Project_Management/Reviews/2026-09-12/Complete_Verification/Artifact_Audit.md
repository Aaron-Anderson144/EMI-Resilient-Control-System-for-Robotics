# Artifact and retained-input audit

Checked 2026-09-13T02:21:35.013307+00:00 against the current local project. All current manifest payloads, declared retained inputs, and frozen-plan files match their recorded hashes. The audit found an outdated publication ZIP, which has been rebuilt and rechecked. The evidence below describes file integrity; it does not add a new control experiment or hardware result.

## Current packages

| Manifest scope | Entries checked | Exact matches | Missing | Mismatched |
|---|---:|---:|---:|---:|
| Publication report directory | 21 | 21 | 0 | 0 |
| Standalone publication directory | 22 | 22 | 0 | 0 |
| September 12 project review | 7 | 7 | 0 | 0 |
| EDMD hybrid package | 56 | 56 | 0 | 0 |

The publication folder contains its outer ZIP in addition to the manifest payload. The ZIP deliberately excludes itself and has been checked separately: **23/23 entries match** the current folder, including the inner checksum manifest. No entries are missing or extra.

The EDMD project folder, standalone output folder, and standalone ZIP each contain **57 files**, including the package manifest. Every relative filename and file hash agrees across all three copies. The three included nominal-project source files also match the corresponding current robotics-project files.

| Current archive | SHA-256 |
|---|---|
| `Publication_Package.zip` | `1429913e0f4f0e350d535ca57d5667ff59f6d2d018d57bf0d1cc159210e40ed0` |
| `EDMD_Hybrid_Estimation.zip` | `96854dc4bafe3e4ca31772593f4a220f103ae74fe31fadee48f09587506a0c87` |

## Retained inputs and frozen source

All **40/40** entries in `Local_Dependencies.json` are present with the declared byte counts and SHA-256 hashes: 34 circuit-runtime files, three experiment-source files, one motion-history input, and two regression inputs. Both retained ngspice executables launch successfully and report ngspice-41. The six files in `Public_Reproduction_Inputs.zip` each match a declared dependency exactly.

All **16/16** frozen-plan entries match. The canonical `04_EMI_Models/Four_Way_EMI_Experiment.md` retains SHA-256 `157daec046c3742b2f78a1071298606789759db04101c0d0a63bc43c3ce5f0be`. Its separate reading copy now links back to that canonical file and explains that the status text describes the plan at the time of freezing. No freeze hash was changed to accept edited inputs.

The numerical checkpoint tag still resolves to `a288d344deddd19b5f2fb5abb2b247a04168c972`. Current HEAD is `6e437538b300084b3c7788043262feccdced5c6f`. Of **378** historical source-manifest entries, all are present, **335** match the recorded publication bytes, and **43** differ. Every difference is a Markdown document. All **333 non-Markdown entries** retain their recorded bytes; the historical numerical source and data have no mismatch in this inventory.

The earlier writing-revision record describes its completed wording pass: **65/72** recorded after-hashes still match. The following **7 later differences** are the subsequent verification edits and freeze restoration. The historical writing record was not rewritten to absorb them.

| Document | Subsequent change |
|---|---|
| `README.md` | Updated the current project overview and verification status. |
| `02_Requirements/Verification_Traceability.md` | Updated the mapping from requirements to current verification evidence. |
| `01_Research/Research_Log.md` | Recorded the current verification work and its limits. |
| `00_Project_Management/Roadmap.md` | Updated the current work sequence and remaining verification work. |
| `11_EDMD_Hybrid_Estimation/docs/PREVIOUS_ASSESSMENT.md` | Clarified that the earlier study and prototype are separate archives. |
| `04_EMI_Models/Four_Way_EMI_Experiment.md` | Restored the exact canonical frozen bytes; the clearer wording is in a separate reading copy. |
| `06_Circuit_Simulations/FOUR_WAY/README.md` | Documented the supplemental V2 CSV coverage auditor and the original auditor's scope. |

Two verification files were added outside the historical checkpoint inventory: `06_Circuit_Simulations/FOUR_WAY/scripts/audit_exported_records_v2.py` and `06_Circuit_Simulations/FOUR_WAY/tests/test_audit_exported_records_v2.py`. They add indexed campaign pair-coverage checks and regression tests. The original numerical auditor remains unchanged. The separate `Four_Way_EMI_Experiment_Readable.md` is also a new document. These additions do not replace frozen source or numerical results; their current hashes are recorded in the structured audit.

`Publication_Status.json` records the September 11 publication. 1/5 of its small published-hash sample still matches the current files; the other entries are later local documentation edits. Its `published: true` and clean-worktree statements are historical facts about that snapshot, not the current edited working tree. The status and historical source manifests were preserved.

## Documents and links

The two report copies match exactly in Markdown, Word, and PDF form. Both current PDFs have **11 pages**. The latest wording is present in Word and PDF, and the current files retain the previously completed visual review of every final page. No rendering was repeated because those documents were not edited during this audit. Authorship metadata retains Aaron Anderson.

The link scan covered **109 Markdown files and 789 inline link occurrences**:

- 532 ordinary local links resolve.
- 46 archived links use absolute drive-letter paths with line references. The files exist locally and all referenced line numbers are in range; their historical semantic context was not reinterpreted.
- 29 archived links use `/C:/...` syntax. Their intended files exist when the legacy leading slash is normalized, but the raw links remain machine-specific and are not portable.
- 182 HTTP links were inventoried. All 129 links to paths in this project's GitHub repository have an existing local counterpart. Remote HTTP availability was not checked for these or the remaining 53 third-party link occurrences.

No ordinary relative target is missing. There are no Markdown fragment targets in this inventory, so no heading-anchor claims are needed. The 75 machine-specific links are confined to four archived audit documents; their exact source lines and targets are retained in `Artifact_Audit.json`. They were left as historical records.

The EDMD previous-assessment document now explicitly says that the earlier study and prototype are separate archives and that their full outputs are not bundled in the hybrid package. Its original saved-evidence paths and numerical claims remain intact.

## Repairs and audit limits

The previous publication ZIP had all 23 expected filenames but ten old payloads: seven Markdown files, the Word document, the PDF, and the inner checksum manifest. It was preserved under `work/project_verification_20260912/before/publication_package_2026-09-11/Publication_Package.zip` before replacement. The rebuilt ZIP has no payload mismatch. The EDMD clarification, refreshed package copies, and reading-copy label were rechecked after editing.

This audit did not run the unopened four-way evaluation or closure stages. MATLAB test execution, toolbox checks, and fresh numerical verification are recorded separately by the project verification run. File hashes establish identity and availability; they do not establish physical model accuracy or hardware performance.

The structured companion `Artifact_Audit.json` contains every checked manifest entry, mismatch classification, link target, runtime version output, current archive hash, and repair record.
