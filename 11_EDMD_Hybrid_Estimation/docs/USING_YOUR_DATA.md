# Using your data

Use `replay_controller` to try the trained models on the robotics project's controller CSV files. It predicts the next reading from earlier measurements and the voltage already applied during the previous sample. This one-step replay does not need future voltage commands.

## Required recording

Start with a healthy run from known zero position, velocity and current. Record at a uniform 1 ms interval with timestamps starting at zero, position in radians and voltage in volts. Save the **actual applied voltage**, with row k's command acting from time k to time k+1. If saturation or a supply fault changes the voltage reaching the motor, the requested command alone is not enough.

| CSV field | Meaning |
|---|---|
| `time_s` | Consecutive source timestamps, starting at zero |
| `receivedMeasurement_rad` | Received encoder position |
| `command_V` | Actual applied voltage for the following interval |
| `sampleReceived` | Must be 1 for every row |
| `sourceIndex` | Must match the current row index, starting at 1 |
| `receiverDomainFailed` | Must be present and zero throughout the run |

The importer ignores hidden truth columns such as `position_rad`; replay does not need them. The domain-failure flag must be zero throughout an already eligible record. That flag alone does not prove hardware EMI immunity.

Replay rejects missing, stale, delayed, nonfinite or irregularly timed data. Recovery after a gap has not been validated in this prototype. Keep the original rows and flags when a record fails these checks. Removing them to get a pass would hide the fault or change the timing.

## Replay

With this package as MATLAB's current folder:

```matlab
log = replay_controller("C:\path\to\controller.csv");
```

The default loads the saved models named by `results/latest_run.json`. To use an explicitly selected model file and output location:

```matlab
log = replay_controller("C:\path\to\controller.csv", ...
    "C:\path\to\selected_models.mat", "C:\path\to\replay_results");
```

An explicit model file must contain exactly four entries, with the unweighted linear and quadratic learned models at positions three and four, as in the original benchmark bundle. A correction-study bundle or a learned model carrying a correction policy is rejected. Evaluate optional weighted models through the correction-study/scoring entry points; this replay adapter does not select or apply those policies.

Each run creates a folder with `replay.csv` and metadata. Warmup rows keep the original measurements but have no eligible learned forecast. Every learned history starts after the 100 discarded observer samples; the default 200 ms time warmup may extend this further. Later rows compare the nominal prior position, linear-hybrid prediction and EDMD prediction with the received reading. The prediction errors help diagnose behavior. They are not calibrated EMI alarms or measurements of true hardware error.

The supplied models were trained on simulated data. A recording lets you check how they transfer to another run, but does not establish that they are suitable for the hardware. A model can agree more closely with an encoder without being closer to the robot's actual position. An independent position reference is needed to check that.

## Training another experiment

`hybrid_prepare_records` converts clean records into innovation records; `edmd_fit` trains the linear or quadratic model. Every record needs `y`, `u`, `t`, `valid`, `sampleTime`, and `domainValid`. The current state-initialization and healthy-data assumptions still apply. Different initialization, sensors or sampling require an explicit design change and verification.

Use whole independent runs for training, validation and testing. Choose normalization, dictionaries and regularization using training/validation data. Freeze those choices before inspecting the final test set. Include matching-model conditions so a learned correction's nominal degradation remains visible.

Before connecting a correction to the running controller, test when to trust it, how to handle faults and uncertainty, how to bound its behavior, and how to recover the state. The current replay tool only writes diagnostics.
