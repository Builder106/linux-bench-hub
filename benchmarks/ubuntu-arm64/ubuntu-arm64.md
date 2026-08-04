# Ubuntu-arm64 Benchmark Results

This document provides detailed benchmarking results for Ubuntu 26.04 LTS, captured monthly by LinuxBenchHub's CI pipeline via Docker using the Phoronix Test Suite.

## Table of Contents

1. [System Information](#system-information)
2. [Tinymembench Benchmark](#tinymembench-benchmark)
3. [C-Ray Benchmark](#c-ray-benchmark)
4. [Aircrack-ng Benchmark](#aircrack-ng-benchmark)

## System Information

### Hardware

- **Processor**: ARMv8 Neoverse-N1 (4 Cores)
- **Motherboard**: QEMU KVM Virtual Machine (1.6.6 BIOS)
- **Memory**: 24GB
- **Disk**: 107GB BlockVolume
- **Graphics**: virtio_gpudrmfb
- **Monitor**: QEMU Monitor

### Software

- **OS**: Ubuntu 26.04 LTS
- **Kernel**: 6.17.0-1011-oracle (aarch64)
- **Compiler**: GCC 15.2.0
- **File-System**: overlayfs
- **Screen Resolution**: 1280x800
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

- **Identifier**: ARMv8 Neoverse-N1
- **Value (MB/s)**: 11776.2
- **Raw String (MB/s)**: `11825.2:11715.7:11787.6`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 11825.2 |
| 2   | 11715.7 |
| 3   | 11787.6 |

### Summary Statistics

- **Mean Value (MB/s)**: 11776.167
- **Median Value (MB/s)**: 11787.6
- **Standard Deviation (MB/s)**: 55.638

### Test Identifier: `pts/tinymembench-1.0.2`

#### Title: Tinymembench

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: ARMv8 Neoverse-N1
- **Value (MB/s)**: 47240.3
- **Raw String (MB/s)**: `47251.3:47195.7:47274`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 47251.3 |
| 2   | 47195.7 |
| 3   | 47274.0 |

### Summary Statistics

- **Mean Value (MB/s)**: 47240.333
- **Median Value (MB/s)**: 47251.3
- **Standard Deviation (MB/s)**: 40.286

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

- **Identifier**: ARMv8 Neoverse-N1
- **Value (Seconds)**: 205.504
- **Raw String (Seconds)**: `206.237:205.473:204.801`

### Detailed Run Values

| Run | Value (Seconds) |
|-----|-------------------|
| 1   | 206.237 |
| 2   | 205.473 |
| 3   | 204.801 |

### Summary Statistics

- **Mean Value (Seconds)**: 205.504
- **Median Value (Seconds)**: 205.473
- **Standard Deviation (Seconds)**: 0.718

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

- **Identifier**: ARMv8 Neoverse-N1
- **Value (k/s)**: 4274.258
- **Raw String (k/s)**: `4348.223:4342.495:3994.261:4349.705:4344.805:4347.136:4348.365:3985.502:3989.579:4347.669:4349.865:4345.14:4331.438:4344.339:4345.341`

### Detailed Run Values

| Run | Value (k/s) |
| ----- | ------------------- |
| 1 | 4348.223 |
| 2 | 4342.495 |
| 3 | 3994.261 |
| 4 | 4349.705 |
| 5 | 4344.805 |
| 6 | 4347.136 |
| 7 | 4348.365 |
| 8 | 3985.502 |
| 9 | 3989.579 |
| 10 | 4347.669 |
| 11 | 4349.865 |
| 12 | 4345.14 |
| 13 | 4331.438 |
| 14 | 4344.339 |
| 15 | 4345.341 |

### Summary Statistics

- **Mean Value (k/s)**: 4274.258
- **Median Value (k/s)**: 4345.14
- **Standard Deviation (k/s)**: 147.305

---
