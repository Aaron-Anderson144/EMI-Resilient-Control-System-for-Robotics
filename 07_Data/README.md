# Data Organization

## `raw`

Immutable data obtained from physical measurements or external instruments. Never overwrite or manually edit these files.

## `synthetic`

Data produced by MATLAB, Simulink, Simscape, or circuit simulations.

## `processed`

Cleaned, synchronized, filtered, or derived data produced from raw or synthetic inputs.

Each dataset should be accompanied by metadata containing the test ID, model or hardware configuration, parameter-set ID, sample rate, units, and processing script.

