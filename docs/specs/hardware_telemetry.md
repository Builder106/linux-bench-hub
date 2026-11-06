# Deterministic Hardware Telemetry

The Ruby dispatcher and `bin/lbh-telemetry` collect host-wide observations around a workload. They read counters without changing governors, kernel settings, sensor configuration, or privileges. No frontend changes are involved.

## Scope and acceptance

The v1.1 workload dispatcher is the prerequisite. This milestone adds baseline/final kernel counter deltas, bounded periodic thermal observations, optional native PMU counts, structured artifacts, and tests for throttling, unavailable sensors, and collector cleanup. It preserves benchmark exit status and the existing `composite.xml` contract.

A telemetry report is evidence about its collection host and interval. It does not guarantee repeatable timings, identical hardware, absence of power limits, or workload-exclusive measurements. Background activity contributes to host-wide counters. Polling can miss temperature excursions between samples; supported lifetime throttle counters preserve event evidence between reads.

## Sources and overhead

- `/proc/stat`: CPU tick deltas, context switches, and process creation.
- `/proc/vmstat`: total page faults and major page faults.
- Sysfs cpufreq, with `/proc/cpuinfo` fallback: observed frequency endpoints and governor. Frequency differences across cores are not proof of thermal throttling.
- Sysfs thermal zones: millidegree temperatures and exposed critical trips. Peaks use the hottest zone, including intermediate observations. Headroom is unavailable when no critical trip is exposed.
- Sysfs CPU thermal throttle counters: count and duration deltas. Package deltas are deduplicated using physical package IDs. Core counts are summed per logical CPU. Missing, malformed, reset, or disappearing counters are not treated as measured zeroes.
- Optional `perf stat -a`: cycles, instructions, cache references, and cache misses. One process counts events for the session without recording stacks or traces. Missing perf, denied access, and unsupported events appear as unavailable; no permissions are elevated. Set `perf: false` in collector options to disable it.

The default poll period is one second; periods below 0.1 seconds and non-finite values are rejected. Zero disables periodic polling while retaining endpoint observations and PMU counting. Storage retains at most 3,600 recent samples; aggregate peak temperature and observed throttling persist for the whole session. Elapsed time uses a monotonic clock. Stop wakes the sampler immediately, reaps perf, and runs even if the workload raises. Overhead depends on CPU/sensor count and host load; there is no fixed percentage guarantee.

Linux documents the broadcast package counters and cumulative throttle durations in its [thermal throttle interface](https://kernel.googlesource.com/pub/scm/linux/kernel/git/jirislaby/linux/+/refs/heads/devel/Documentation/admin-guide/thermal/intel_thermal_throttle.rst). PMU counting follows the [perf stat interface](https://www.man7.org/linux/man-pages/man1/perf-stat.1.html).

## Reports and integration

`telemetry.json`, the manifest's `hardware_telemetry`, and `summary.md` record:

- `source`: `native`, `simulated`, or `unavailable`; `scope`: `host`.
- `deterministic`: `false` when throttle counts or throttle duration increase; `true` when supported counters remain stable and kernel counters are readable; `null` when evidence is insufficient. The field assesses observed thermal stability only.
- `throttling_detected`, explanatory notes, thermal deltas, kernel counters, PMU availability and values, and bounded samples.

Telemetry is enabled by default in `bin/lbh-dispatch`. A simulated target always uses explicitly labeled synthetic readings. Docker and SSH dispatch return unavailable telemetry rather than attaching the orchestrator's hardware to another target. For those runs, execute `lbh-telemetry` on the benchmark host or inside its container; visibility still depends on that environment. The shared monthly shell capture runner invokes the standalone telemetry tool inside each distro container around the timed PTS workload. Ruby is installed in all six matrix entries. Both matrices archive dated telemetry JSON and `telemetry-latest.json` alongside their XML, without changing the XML schema or git publication rules. Failed or invalid captures preserve both previous output files. Each file is replaced atomically; the pair is not a filesystem transaction.

A throttled benchmark retains its execution success/failure status and measured XML; its manifest flags the thermal evidence separately. Consumers must inspect `deterministic` and `source` before comparing results. With telemetry disabled, no telemetry artifact is generated and the manifest's verdict is unknown.

## Usage

```bash
# Snapshot (does not start perf)
bin/lbh-telemetry --check --json

# Sample locally and save a report
bin/lbh-telemetry --monitor 5 --interval 1 --json --output /tmp/telemetry.json

# Preserve the wrapped command's exit status
bin/lbh-telemetry --exec 'sysbench cpu run' --output /tmp/telemetry.json

# Exercise dispatch artifacts without accessing real hardware
bin/lbh-dispatch --simulate --output /tmp/lbh-captures
bin/lbh-dispatch --simulate --simulate-throttle --output /tmp/lbh-captures

# Disable collection, or choose endpoint-only collection
bin/lbh-dispatch --no-telemetry
bin/lbh-dispatch --telemetry-interval 0
```

Run `ruby test_hardware_telemetry.rb` and `ruby test_hardware_telemetry_regression.rb` for fixture-based reader, lifecycle, PMU, CLI, and manifest checks without privileged hardware access.
