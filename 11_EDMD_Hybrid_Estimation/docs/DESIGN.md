# Hybrid estimation design

This experiment tests whether learning the observer's recent prediction errors can improve its next position forecasts. The physics model still describes the motor. EDMD predicts how the difference between a reading and the observer's prediction will change. Everything runs offline or alongside the controller without affecting it. The multistep forecasts use recorded future applied voltages, which would not automatically be known during live operation. Their accuracy alone does not show that the feedback controller has improved.

The main output is the **expected encoder-position forecast**. It is compared with both the simulated physical position and the received encoder measurements. The observer also maintains an internal state. An accurate encoder forecast does not, on its own, show that this state's velocity and current estimates are accurate or reliable during a fault.

For a received position sample \(y_k\), applied voltage \(u_{k-1}\), and a nominal observer with fixed matrices \(A_p,B_p,C_p\) and correction gain \(L\), the healthy-data preparation is

\[
x_k^- = A_p x_{k-1}^+ + B_p u_{k-1},\qquad
r_k = y_k-C_p x_k^-,\qquad
x_k^+ = x_k^-+Lr_k.
\]

Each run starts from the stated zero estimate. This **ungated** observer accepts every fresh healthy sample and keeps the same matrices and gain throughout. It is not given the actual unknown load torque, test parameters, or true states. The innovation \(r_k\) includes model error, quantization, measurement noise, and the observer's own behavior, so it cannot be treated as a measured physical disturbance.

EDMD uses the causal history

\[
h_k=[r_k,\ldots,r_{k-d},u_{k-1},\ldots,u_{k-d}]^\top,
\quad z_k=\psi(h_k),
\quad z_{k+1}\approx Kz_k+G\widetilde u_k.
\]

Normalization is fitted on the training runs and kept unchanged for validation, testing, and forecasts. The dictionary contains a constant and normalized history coordinates. The quadratic version adds their degree-two products. Comparing it with the matched linear dictionary shows whether those extra nonlinear features help. Both are finite approximations to the dynamics. The method follows the general lifting approach in [Williams, Kevrekidis and Rowley](https://arxiv.org/abs/1408.4408) and the input-aware predictor in [Korda and Mezić](https://arxiv.org/abs/1611.03537); it does not give an exact finite Koopman representation.

At a forecast origin, the model initializes once from innovations and applied inputs available through that origin. For each future step it predicts \(\widehat r_{k+1}\), then applies

\[
\widehat x_{k+1}^- = A_p\widehat x_k^+ + B_pu_k,\qquad
\widehat y_{k+1}=C_p\widehat x_{k+1}^-+\widehat r_{k+1},\qquad
\widehat x_{k+1}^+=\widehat x_{k+1}^-+L\widehat r_{k+1}.
\]

The forecast uses no future measured position. Its state update is consistent with the innovation it predicts. The internal posterior position is \(C_p\widehat x_{k+1}^+=C_p\widehat x_{k+1}^-+(C_pL)\widehat r_{k+1}\), which generally differs from \(\widehat y_{k+1}\). The results therefore report these two quantities separately.

The comparison uses common forecast origins after a 200 ms warmup. All methods start from the same nominal observer posterior and receive identical future applied voltages:

- **Nominal physics:** propagate with no future innovation correction.
- **Persistent innovation:** hold the mean of the last 20 available innovations throughout the forecast, using the same hybrid recursion.
- **Learned linear innovation:** forecast innovations with the linear dictionary.
- **Quadratic EDMD innovation:** forecast innovations with the quadratic dictionary.

Whole trajectories are separated into training, validation, and test sets. Validation selects among 18 delay/degree/ridge configurations; the selected models are frozen before testing. The primary outcome is per-trajectory continuous-position endpoint RMSE at 50 ms. A regime passes the declared screening criterion only with at least 10% lower mean error than all three comparison methods, paired wins on at least 7 of 10 test trajectories against each, and no nonfinite forecasts. Numerical failures remain counted. Other horizons are secondary outcomes, not grounds for test-driven retuning.

A useful result here would show better predictions under the tested simulation conditions and inputs. EMI immunity, calibrated disturbance estimates, closed-loop stability, hardware accuracy, and operation with missing or corrupted measurements need separate tests. Training on healthy innovations has not established reliability during those faults. The error and input histories may also miss relevant state information, and quadratic features with affine inputs do not guarantee that the lifted dynamics close. Any short-horizon gain must be considered alongside growing long-horizon errors and performance with different controllers.

