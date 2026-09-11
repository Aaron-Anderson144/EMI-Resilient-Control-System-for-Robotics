# Publication figure captions

## Figure 1 Causal architecture

The implemented feedback loop connects the currently held controller voltage to the continuous motor trajectory, every intended quantization crossing, the loaded encoder A circuit, Schmitt events and a persistent quadrature count. The controller receives exactly measurement_rad, sourceIndex and sampleReceived. B is ideal. The saved SC01B_R2 waveform is an independent one-way capacitive aggressor with a declared synthetic return and burst construction; it is not the actuator winding's own driven switching source. An offline no-aggressor shadow uses each exposed run's own intended A/B trajectory and never feeds control. The illustration describes a simulation architecture, not a validated hardware system.

Source: 04_EMI_Models/Four_Way_Causal_Implementation.md and frozen 04_EMI_Models/Four_Way_EMI_Experiment.md.

## Figure 2 Four arm design

The frozen four-arm design crosses differential capacitance with the existing software protection choice. BASELINE and SW_ONLY use 100 pF; EM_ONLY and COMBINED use 1,000 pF, an added 900 pF across the receiver pair. The historical protected policy is used unchanged. A common motion governor, task, source, coupling and reset definition apply to all arms, and each arm is paired with its own clean actuator run. This design supports attribution within the declared simulation; the diagram does not imply demonstrated improvement or synergy.

Source: 04_EMI_Models/Four_Way_EMI_Experiment.md, section Victim and electrical intervention.

## Figure 3 Development receiver domain

DEV01 (Ccp/Ccn = 10/9 pF) reaches peak absolute common-mode voltages of 3.34750050200855 V at 100 pF and 3.34750776203227 V at 1,000 pF. Both round to 3.348 V as plotted. All four arms remain within the assumed receiver domain and show no persistent EMI count error or paired actuator disturbance. DEV02 (200/5 pF) reaches 7.5574846311737 V at 100 pF and 8.03757142585377 V at 1,000 pF. All four exposed arms therefore exceed the assumed |common mode| <= 7 V domain and are rejected for physical receiver or comparative control-effect interpretation. Software counterparts have the same peaks. The limit is a behavioral model assumption, not a measured component rating or damage threshold. Values are displayed to three decimals; the source records retain full precision.

Source: 00_Project_Management/Verification/Causal_Receiver_2026-09-11/domain_and_clean_decoder_summary.csv and 00_Project_Management/Causal_Receiver_Checkpoint.md.

## Files and rendering

Each named asset is supplied as editable, accessible SVG and a 2x PNG with identical content. White backgrounds, black titles and high-contrast navy, teal and amber are consistent across figures. Captions should carry the final report figure numbers.
