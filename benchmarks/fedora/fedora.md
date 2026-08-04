# Fedora Benchmark Results

This document provides detailed benchmarking results for Fedora Linux 44, captured monthly by LinuxBenchHub's CI pipeline via Docker using the Phoronix Test Suite.

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

- **OS**: Fedora Linux 44
- **Kernel**: 6.17.0-1018-azure (x86_64)
- **Compiler**: GCC 16.1.1 20260515
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
- **Value (MB/s)**: 24283.9
- **Raw String (MB/s)**: `25595.3:25947.7:24214.2:24458.4:23995.2:21492.5`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 25595.3 |
| 2   | 25947.7 |
| 3   | 24214.2 |
| 4   | 24458.4 |
| 5   | 23995.2 |
| 6   | 21492.5 |

### Summary Statistics

- **Mean Value (MB/s)**: 24283.883
- **Median Value (MB/s)**: 24336.3
- **Standard Deviation (MB/s)**: 1574.711

### Test Identifier: `pts/tinymembench-1.0.2`

#### Title: Tinymembench

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: AMD EPYC 9V74 80-Core
- **Value (MB/s)**: 45480.9
- **Raw String (MB/s)**: `52955.8:53614:45969.6:37502.7:45961.7:36881.8`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 52955.8 |
| 2   | 53614.0 |
| 3   | 45969.6 |
| 4   | 37502.7 |
| 5   | 45961.7 |
| 6   | 36881.8 |

### Summary Statistics

- **Mean Value (MB/s)**: 45480.933
- **Median Value (MB/s)**: 45965.65
- **Standard Deviation (MB/s)**: 7212.318

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
- **Value (Seconds)**: 359.315
- **Raw String (Seconds)**: `359.212:359.117:359.616`

### Detailed Run Values

| Run | Value (Seconds) |
|-----|-------------------|
| 1   | 359.212 |
| 2   | 359.117 |
| 3   | 359.616 |

### Summary Statistics

- **Mean Value (Seconds)**: 359.315
- **Median Value (Seconds)**: 359.212
- **Standard Deviation (Seconds)**: 0.265

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
- **Value (k/s)**: 6987.830
- **Raw String (k/s)**: `6987.635:6986.896:6988.958`

### Detailed Run Values

| Run | Value (k/s) |
|-----|-------------------|
| 1   | 6987.635 |
| 2   | 6986.896 |
| 3   | 6988.958 |

### Summary Statistics

- **Mean Value (k/s)**: 6987.83
- **Median Value (k/s)**: 6987.635
- **Standard Deviation (k/s)**: 1.045

---
