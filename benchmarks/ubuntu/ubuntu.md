# Ubuntu Benchmark Results

This document provides detailed benchmarking results for Ubuntu 26.04 LTS, captured monthly by LinuxBenchHub's CI pipeline via Docker using the Phoronix Test Suite.

## Table of Contents

1. [System Information](#system-information)
2. [Tinymembench Benchmark](#tinymembench-benchmark)
3. [C-Ray Benchmark](#c-ray-benchmark)
4. [Aircrack-ng Benchmark](#aircrack-ng-benchmark)

## System Information

### Hardware

- **Processor**: AMD EPYC 9V74 80-Core (2 Cores / 4 Threads)
- **Motherboard**: Microsoft Virtual Machine (Hyper-V UEFI v4.1 BIOS)
- **Memory**: 16GB
- **Disk**: 2 x 81GB Virtual Disk
- **Graphics**: hyperv_drmdrmfb

### Software

- **OS**: Ubuntu 26.04 LTS
- **Kernel**: 6.17.0-1018-azure (x86_64)
- **Compiler**: GCC 15.2.0
- **File-System**: overlayfs
- **Screen Resolution**: 1024x768
- **System Layer**: Docker

---

## Tinymembench Benchmark

### Test Identifier: `pts/tinymembench-1.0.2`

#### Title: Tinymembench

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memcpy
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: AMD EPYC 9V74 80-Core
- **Value (MB/s)**: 23210.7
- **Raw String (MB/s)**: `20870:22694.8:22420.7:22338.3:22664.7:23032.7:24692.3:26972.2`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 20870.0 |
| 2   | 22694.8 |
| 3   | 22420.7 |
| 4   | 22338.3 |
| 5   | 22664.7 |
| 6   | 23032.7 |
| 7   | 24692.3 |
| 8   | 26972.2 |

### Summary Statistics

- **Mean Value (MB/s)**: 23210.712
- **Median Value (MB/s)**: 22679.75
- **Standard Deviation (MB/s)**: 1844.065

### Test Identifier: `pts/tinymembench-1.0.2`

#### Title: Tinymembench

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: AMD EPYC 9V74 80-Core
- **Value (MB/s)**: 43653.0
- **Raw String (MB/s)**: `38480.5:39845.2:39794.4:39357.1:39979:41231.4:52780:57756.8`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 38480.5 |
| 2   | 39845.2 |
| 3   | 39794.4 |
| 4   | 39357.1 |
| 5   | 39979.0 |
| 6   | 41231.4 |
| 7   | 52780.0 |
| 8   | 57756.8 |

### Summary Statistics

- **Mean Value (MB/s)**: 43653.05
- **Median Value (MB/s)**: 39912.1
- **Standard Deviation (MB/s)**: 7330.751

---

## C-Ray Benchmark

### Test Identifier: `pts/c-ray-2.0.0`

#### Title: C-Ray

- **App Version**: 2.0
- **Arguments**: `-s 1920x1080 -r 16`
- **Description**: Resolution: 1080p - Rays Per Pixel: 16
- **Scale**: Seconds
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: AMD EPYC 9V74 80-Core
- **Value (Seconds)**: 366.009
- **Raw String (Seconds)**: `366.359:365.858:365.811`

### Detailed Run Values

| Run | Value (Seconds) |
|-----|-------------------|
| 1   | 366.359 |
| 2   | 365.858 |
| 3   | 365.811 |

### Summary Statistics

- **Mean Value (Seconds)**: 366.009
- **Median Value (Seconds)**: 365.858
- **Standard Deviation (Seconds)**: 0.304

---

## Aircrack-ng Benchmark

### Test Identifier: `pts/aircrack-ng-1.3.0`

#### Title: Aircrack-ng

- **App Version**: 1.7
- **Arguments**: ``
- **Description**:
- **Scale**: k/s
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: AMD EPYC 9V74 80-Core
- **Value (k/s)**: 6978.865
- **Raw String (k/s)**: `7003.043:6952.318:6981.234`

### Detailed Run Values

| Run | Value (k/s) |
|-----|-------------------|
| 1   | 7003.043 |
| 2   | 6952.318 |
| 3   | 6981.234 |

### Summary Statistics

- **Mean Value (k/s)**: 6978.865
- **Median Value (k/s)**: 6981.234
- **Standard Deviation (k/s)**: 25.445

---
