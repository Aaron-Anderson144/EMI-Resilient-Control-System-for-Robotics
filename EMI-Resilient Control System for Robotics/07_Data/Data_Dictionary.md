# Data Dictionary

| Signal | Symbol | Unit | Description | Initial Source |
|---|---|---|---|---|
| Time | `time_s` | s | Simulation or measurement time | Simulation clock |
| Position reference | `theta_ref_rad` | rad | Commanded shaft position | Test scenario |
| Shaft position | `theta_rad` | rad | Actual or measured shaft position | Plant/encoder |
| Shaft velocity | `omega_rad_s` | rad/s | Actual or estimated shaft speed | Plant/estimator |
| Winding current | `current_A` | A | DC-equivalent or phase-current value | Plant/current sensor |
| Drive command | `voltage_cmd_V` | V | Controller output before or after saturation | Controller |
| Load torque | `load_torque_Nm` | N·m | Mechanical disturbance torque | Test scenario |
| Position error | `position_error_rad` | rad | Reference minus measured position | Analysis |
| Fault active | `fault_active` | Boolean | Whether fault injection is enabled | Fault injector |
| Fault type | `fault_type` | categorical | Identifier for active disturbance | Test configuration |
| Operating mode | `control_mode` | categorical | Normal, suspected, degraded, recovery, or safe stop | Supervisor |
| Residual | `residual` | signal-dependent | Measured minus predicted output | Observer monitor |

## Naming Rules

- Include units in exported column names.
- Use SI units internally unless a documented exception is necessary.
- Preserve raw values and create new fields for derived quantities.
- Record the random seed for every stochastic simulation.

