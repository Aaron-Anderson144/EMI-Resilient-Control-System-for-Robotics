# FOUR-WAY-EMI-PLAN-V1 circuit and receiver implementation

These new helpers implement the frozen experiment without editing SC01A,
SC01B_R2, the replay, or the historical controllers. They provide a conditional
numerical model; numerical agreement does not qualify physical hardware.

Add `03_MATLAB/functions` to the MATLAB path. Initialize with
`s=fourway_receiver_init(Ccp_pF,Ccn_pF,Cdiff_pF,phase_s,exposed,closure_s)`;
the default closure is 100 ns. Advance with
`[s,packet]=fourway_receiver_advance(s,tEnd,[time_s,A,B])`, supplying only
causal intended transitions within the current interval. `packet` contains
persistent decoded count, count radians, independently accumulated intended
count, receiver-domain status, terminal circuit state, and intended A/B.
Controller code must use only the decoded measurement and receipt metadata.

The compiled engine diagonalizes the unchanged SC01A network, retaining all
three modes (including complex-conjugate modes in zero-coupling fixtures).
Each original source PWL interval and driver ramp uses the exact affine
matrix solution. Analytic interval enclosures bound exponentials and cosine
phase ranges; they certify absent threshold roots or monotonicity before
root bisection. Unresolved grazing rejects the run. Endpoint-only glitch
detection and fixed pulse rejection are not used. Source, closure, pulse,
burst, ramp, and packet boundaries carry the previous continuous state.

The source is read from its original CSV only after its frozen SHA-256 is
verified. All 40,001 original timestamps/voltages remain unchanged. The 100
ns return adds a final PWL interval followed by DC hold; the alternative
45 us return occupies the rest of the 50 us period. Each exposed record has
200 complete periods, in the two frozen 100-period bursts. Actual nonzero
source-derivative times are retained per pulse in `s.source`.

`r=fourway_receiver_export(s)` retains complete threshold/domain events,
decoder transitions, intended transitions, source/ramp boundary states, and
packet circuit states. Column names and boundary-kind mappings are included.
The immutable original source is represented by its verified identity rather
than copied millions of times. `fourway_receiver_reconstruct(r,queryTimes)`
recreates exact receiver states at arbitrary requested times using the same
engine hash. `fourway_exact(config,state,stop,transitions,queryTimes)` is the
direct native-comparison API, with fifth output `[time_s,vp,vn,ir]`.

Receiver A events and ideal B events within 1 ps are decoded jointly. Invalid
two-bit changes hold count and update the preceding observed state. Events
at a packet timestamp are processed before that packet. A later call that
reveals a new event within 1 ps of an event already sampled raises
`FOURWAY:CrossPacketJointAmbiguity`: merging it would require future input or
retrospective repair. Such alignment is rejected, not silently accepted as
an equivalent integer count. Exact threshold duplicates across packet
boundaries are suppressed by persistent event history.

Once common mode exceeds +/-7 V, circuit and event recording continues but
receiver A is held and the run is rejected for interpretation. An offline
shadow initializes an otherwise identical unexposed receiver and replays the
exposed record's saved intended trajectory; it never feeds the controller.

Run `runtests('06_Circuit_Simulations/FOUR_WAY/tests/TestFourwayReceiver.m')`
for source/closure, independent branch KCL and return law, augmented-matrix
exponential, both motion directions, zero coupling, reversal, continuous
boundaries, cancelling/persistent glitches, joint illegal changes, coincident
sampling, cross-packet ambiguity, shadow, and domain-failure tests. Native
Simscape acceptance is a separate 8-fixture x 3-refinement campaign. The
compiler emits source-hash-named binaries under `work/`; this permits parallel
MATLAB acceptance runs without overwriting a loaded or historical model.
