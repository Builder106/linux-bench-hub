# Automated Workload Dispatch Technical Specification

## Overview

The Automated Workload Dispatch engine (`lib/linux_bench_hub/workload_dispatch/` and `bin/lbh-dispatch`) provides deterministic, reproducible benchmark execution pipelines across three core subsystem tiers:

1. **CPU**: Computational and raytracing stress tests (`pts/c-ray-2.0.0`).
2. **Memory Bandwidth**: Sub-cache read and write memory throughput (`pts/tinymembench-1.0.2`).
3. **Disk I/O**: Synchronous and asynchronous block storage throughput and latency (`pts/fio-2.1.0`).

## Pipeline Architecture

The dispatch architecture separates workload specifications, pipeline configuration, target execution backends, and result manifest generation.

```
                    +-----------------------+
                    |    Workload Catalog   |
                    | (CPU, Memory, Disk IO)|
                    +-----------+-----------+
                                |
                                v
                    +-----------------------+
                    |   Pipeline Planner    |
                    |   (Batch Answers,     |
                    |    Deterministic Seed)|
                    +-----------+-----------+
                                |
        +-----------------------+-----------------------+
        |                       |                       |
        v                       v                       v
+---------------+       +---------------+       +---------------+
|  LocalTarget  |       |  DockerTarget |       |   SshTarget   |
| (Native Host) |       | (Distro Ctr)  |       | (Remote Host) |
+-------+-------+       +-------+-------+       +-------+-------+
        |                       |                       |
        +-----------------------+-----------------------+
                                |
                                v
                    +-----------------------+
                    |      Dispatcher       |
                    | - Preflight Checks    |
                    | - XML Result Parser   |
                    | - Error Trap Handler  |
                    | - Manifest & Telemetry|
                    +-----------+-----------+
                                |
                    +-----------+-----------+
                    |   Output Artifacts    |
                    | - composite.xml       |
                    | - manifest.json       |
                    | - summary.md          |
                    +-----------------------+
```

## Workload Specifications

### 1. CPU Raytracing (`pts/c-ray-2.0.0`)
- **Category**: `:cpu`
- **Identifier**: `pts/c-ray-2.0.0`
- **Arguments**: `-s 1920x1080 -r 16` (1080p resolution, 16 rays per pixel)
- **Interactive Answers**: `1\n16\n`
- **Output Scale**: `Seconds` (Lower Is Better)
- **Dependencies**: `build-essential`

### 2. Sub-Cache Memory Bandwidth (`pts/tinymembench-1.0.2`)
- **Category**: `:memory`
- **Identifier**: `pts/tinymembench-1.0.2`
- **Arguments**: Default sub-cache memcpy and memset loops
- **Interactive Answers**: None required (batch automated)
- **Output Scale**: `MB/s` (Higher Is Better)
- **Dependencies**: `build-essential`

### 3. Flexible I/O Storage (`pts/fio-2.1.0`)
- **Category**: `:disk_io`
- **Identifier**: `pts/fio-2.1.0`
- **Arguments**: `4KB Random Read - Linux AIO - Yes - 1`
- **Interactive Answers**: `1\n1\n1\n1\n` (Type: Random Read, Engine: Linux AIO, Direct: Yes, Block: 4KB)
- **Output Scale**: `MB/s` / `IOPS` (Higher Is Better)
- **Dependencies**: `build-essential`, `libaio-dev`

## Execution Targets

- **`LocalTarget`**: Native runner execution. Validates `phoronix-test-suite` on `$PATH`, seeds non-interactive configuration, executes workloads, and monitors `/var/lib/phoronix-test-suite` for artifacts and `install-failed.log`.
- **`DockerTarget`**: Containerized runner executing across distribution images:
  - Ubuntu: `ubuntu:26.04`
  - Fedora: `fedora:44`
  - Debian: `debian:13`
- **`SshTarget`**: Remote orchestration driving dedicated cloud hardware (e.g. Oracle Cloud Ampere A1 VM) over SSH.
- **`SimulatedTarget`**: High-fidelity deterministic simulation producing schema-compliant `composite.xml` and manifest outputs for automated testing, CI pipelines, and dry-run validation.

## Reproducibility Guarantees

1. **Zero Prompt Drift**: All interactive prompts across PTS setup and individual test options are pre-seeded and piped non-interactively via deterministic response streams.
2. **Artifact Verification**: Verifies `composite.xml` presence, validates XML structure, and traps partial installation failures (`install-failed.log`).
3. **Execution Manifest**: Emits `manifest.json` containing kernel version, architecture, duration, workload statuses, and per-metric mean and standard deviation.

## CLI Usage

```bash
# List registered workloads across all three tiers
bin/lbh-dispatch --list

# Preflight check against current host
bin/lbh-dispatch --check

# Dry-run validation of the three-tier pipeline
bin/lbh-dispatch --simulate --output captures/

# Native execution of CPU and Memory tiers
bin/lbh-dispatch --workloads cpu,memory --target local

# Container execution for Fedora 44
bin/lbh-dispatch --target docker --distro fedora --output captures/
```
