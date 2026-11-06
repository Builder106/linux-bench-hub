# Deterministic Hardware Telemetry Technical Specification

## Overview

The Deterministic Hardware Telemetry engine (`lib/linux_bench_hub/hardware_telemetry/` and `bin/lbh-telemetry`) provides low-overhead, high-fidelity monitoring of hardware performance counters, CPU frequency scaling, and thermal throttling events during benchmark execution.

Thermal throttling and dynamic frequency scaling are the primary drivers of non-deterministic performance regression in Linux benchmark pipelines. Unmitigated thermal trips silently distort execution times, inflate benchmark variance (standard deviation), and corrupt cross-distro comparisons. This telemetry subsystem establishes deterministic verification guarantees: if hardware throttling occurs during a benchmark run, the run is flagged as non-deterministic (`deterministic: false`), the throttle duration and event counts are recorded in `telemetry.json`, and regression analyzers are alerted.

## Architecture & Data Flow

The telemetry system utilizes a dual-phase snapshot model augmented by an optional, non-blocking background sampler. Baseline and final snapshots capture exact counter deltas with sub-millisecond precision, while sysfs and procfs readers incur negligible overhead (<0.1% CPU utilization).

```
                     +---------------------------------------+
                     |         Benchmark Dispatcher          |
                     +-------------------+-------------------+
                                         |
                       Collector.start   |   Collector.stop
                                         v
            +---------------------------------------------------------+
            |               HardwareTelemetry::Collector              |
            +----------------------------+----------------------------+
                                         |
                 +-----------------------+-----------------------+
                 |                       |                       |
                 v                       v                       v
         +---------------+       +---------------+       +---------------+
         | ThermalMonitor|       |    Counters   |       |    Sampler    |
         | (Sysfs Zones, |       | (Procfs Stat, |       | (Non-blocking |
         |  Throttling)  |       |  Vmstat, Freq)|       |  Time-Series) |
         +-------+-------+       +-------+-------+       +-------+-------+
                 |                       |                       |
                 +-----------------------+-----------------------+
                                         |
                                         v
                     +---------------------------------------+
                     |       Determinism Verifier &          |
                     |         Report Generator              |
                     +-------------------+-------------------+
                                         |
                                         v
                     +---------------------------------------+
                     |           Output Artifacts            |
                     | - telemetry.json                      |
                     | - manifest.json (hardware_telemetry)  |
                     | - summary.md (telemetry tables)       |
                     +---------------------------------------+
```

## Telemetry Metrics & Data Sources

### 1. Thermal Throttling Registers
- **Interface**: `/sys/devices/system/cpu/cpu*/thermal_throttle/`
- **Counters**:
  - `package_throttle_count`: Increments whenever the CPU package temperature exceeds the throttling threshold. Deduplicated across logical cores on identical physical sockets.
  - `core_throttle_count`: Increments whenever an individual CPU core is throttled. Summed across all cores.
  - `package_throttle_total_time_ms` / `core_throttle_total_time_ms`: Cumulative hardware duration spent under thermal throttling.
- **Delta Calculation**:
  $$\Delta_{\text{pkg}} = \max(0, C_{\text{final}} - C_{\text{initial}})$$
  $$\text{Throttling Detected} \iff \Delta_{\text{pkg}} > 0 \lor \Delta_{\text{core}} > 0$$

### 2. Thermal Zones & Headroom
- **Interface**: `/sys/class/thermal/thermal_zone*/`
- **Readings**:
  - `temp`: Millidegree Celsius reading converted to floating-point Celsius ($T / 1000.0$).
  - `type`: Zone identification string (e.g. `x86_pkg_temp`, `acpitz`, `soc_dts0`).
  - `trip_point_*_temp` & `type`: Critical threshold temperatures ($T_{\text{crit}}$).
- **Thermal Headroom**:
  $$\text{Headroom} = \max(0.0, T_{\text{crit}} - T_{\text{peak}})$$

### 3. Kernel Scheduler & System Counters
- **Interface**: `/proc/stat`
- **Metrics**:
  - `ctxt`: Cumulative context switches. Emits total delta and rate per second ($\Delta_{\text{ctxt}} / \Delta_t$).
  - `processes`: Cumulative fork and process creation operations.
  - CPU utilization ticks: user, nice, system, idle, iowait, irq, softirq, steal. Emits percentage breakdown over the run duration.

### 4. Virtual Memory Counters
- **Interface**: `/proc/vmstat`
- **Metrics**:
  - `pgfault`: Minor page faults. Emits total and per-second fault rates.
  - `pgmajfault`: Major page faults (disk I/O paging events). Emits total and per-second rates.

### 5. CPU Frequency Scaling
- **Interface**: `/sys/devices/system/cpu/cpu*/cpufreq/` (with fallback to `/proc/cpuinfo`)
- **Metrics**: Current operating frequencies across cores in MHz, active governor (`performance`, `powersave`, `schedutil`), and average/min/max frequency range.

## Determinism Verification Rules

A benchmark dispatch is classified as `deterministic: true` if and only if all the following conditions hold:

1. **Zero Thermal Throttling Events**: $\Delta_{\text{package\_throttle}} = 0$ and $\Delta_{\text{core\_throttle}} = 0$.
2. **Frequency Stability Under Load**: Core frequencies do not collapse by $>40\%$ while operating at peak temperatures exceeding $85^\circ\text{C}$.

When a determinism violation occurs:
- The manifest marks `deterministic: false` and `throttling_detected: true`.
- Explanatory notes are recorded in `determinism_notes` (e.g., `"Thermal throttling detected: 14 package events, 8 core events (420ms total)"`).
- The markdown summary highlights the regression warning.

## CLI Tooling

### Standalone Telemetry Tool (`bin/lbh-telemetry`)

```bash
# Instantaneous snapshot of thermal state, frequencies, and counters
bin/lbh-telemetry --check

# JSON output
bin/lbh-telemetry --check --json

# Run a live 5-second sampling monitor
bin/lbh-telemetry --monitor 5 --interval 0.5

# Wrap command execution in telemetry monitoring
bin/lbh-telemetry --exec "sysbench cpu run"

# Simulated mode with synthetic throttling
bin/lbh-telemetry --simulate --simulate-throttle --json
```

### Dispatcher Integration (`bin/lbh-dispatch`)

```bash
# Preflight hardware telemetry diagnostic
bin/lbh-dispatch --telemetry-check

# Standard dispatch with automated hardware telemetry enabled (default)
bin/lbh-dispatch --simulate --output captures/

# Dispatch with simulated throttling to verify non-determinism handling
bin/lbh-dispatch --simulate --simulate-throttle --output captures/
```
