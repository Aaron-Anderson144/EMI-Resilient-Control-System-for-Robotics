# Additional local verification records

The standard final campaign comprises 67 automated tests and 51 native simulations. All accepted simulations recorded zero warnings and reached their requested stop time. The final campaign log and result CSVs are the acceptance record.

`standalone_verify.log` records opening/running the saved model without base-workspace setup and checking overridden model-workspace parameters against the independent reference.

`diagnostics_gate_verify.log` records a nominal accepted run and a deliberately injected warning that was correctly rejected with `SC01A:SimulationWarning`. `diagnostic_gate_probe_evidence.mat` retains that intentional diagnostic. Its original temporary path in the log was relocated here. This expected rejection-path probe is separate from the 51 accepted campaign runs; it is not an unresolved circuit warning. Pilot and supplementary development runs are not included in the standard campaign count.