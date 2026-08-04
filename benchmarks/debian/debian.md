# Debian Benchmark Results

This document provides detailed benchmarking results for Debian GNU/Linux 13, captured monthly by LinuxBenchHub's CI pipeline via Docker using the Phoronix Test Suite.

## Table of Contents

1. [System Information](#system-information)
2. [Tinymembench Benchmark](#tinymembench-benchmark)
3. [C-Ray Benchmark](#c-ray-benchmark)
4. [Aircrack-ng Benchmark](#aircrack-ng-benchmark)

## System Information

### Hardware

- **Processor**: AMD EPYC 7763 64-Core (2 Cores / 4 Threads)
- **Motherboard**: Microsoft Virtual Machine (Hyper-V UEFI v4.1 BIOS)
- **Memory**: 16GB
- **Disk**: 161GB Virtual Disk
- **Graphics**: hyperv_drmdrmfb

### Software

- **OS**: Debian GNU/Linux 13
- **Kernel**: 6.17.0-1020-azure (x86_64)
- **Compiler**: GCC 14.2.0
- **File-System**: overlayfs
- **Screen Resolution**: 1024x768
- **System Layer**: Docker

---

## Tinymembench Benchmark

### Test Identifier: `pts/tinymembench-1.0.2` (test 1)

#### Title: Tinymembench (test 1)

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memcpy
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries (test 1)

- **Identifier**: AMD EPYC 7763 64-Core
- **Value (MB/s)**: 23844.2
- **Raw String (MB/s)**: `24694.1:23708.6:22939.9:23391.7:24694.5:23583.6:23841.5:23662.4:24081.9`

### Detailed Run Values (test 1)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 24694.1      |
| 2   | 23708.6      |
| 3   | 22939.9      |
| 4   | 23391.7      |
| 5   | 24694.5      |
| 6   | 23583.6      |
| 7   | 23841.5      |
| 8   | 23662.4      |
| 9   | 24081.9      |

### Summary Statistics (test 1)

- **Mean Value (MB/s)**: 23844.244
- **Median Value (MB/s)**: 23708.6
- **Standard Deviation (MB/s)**: 574.86

### Test Identifier: `pts/tinymembench-1.0.2` (test 2)

#### Title: Tinymembench (test 2)

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries (test 2)

- **Identifier**: AMD EPYC 7763 64-Core
- **Value (MB/s)**: 36824.1
- **Raw String (MB/s)**: `42335.6:35100.1:30418.2:32068.2:45341.6:33589.1:45399.9:34020.3:33144.1`

### Detailed Run Values (test 2)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 42335.6      |
| 2   | 35100.1      |
| 3   | 30418.2      |
| 4   | 32068.2      |
| 5   | 45341.6      |
| 6   | 33589.1      |
| 7   | 45399.9      |
| 8   | 34020.3      |
| 9   | 33144.1      |

### Summary Statistics (test 2)

- **Mean Value (MB/s)**: 36824.122
- **Median Value (MB/s)**: 34020.3
- **Standard Deviation (MB/s)**: 5862.636

---

## C-Ray Benchmark

### Test Identifier: `pts/c-ray-2.0.0` (test 3)

#### Title: C-Ray (test 3)

- **App Version**: 2.0
- **Arguments**: `-s 1920x1080 -r 16`
- **Description**: Resolution: 1080p - Rays Per Pixel: 16
- **Scale**: Seconds
- **Display Format**: BAR_GRAPH

### Data Entries (test 3)

- **Identifier**: AMD EPYC 7763 64-Core
- **Value (Seconds)**: 367.031
- **Raw String (Seconds)**: `367.204:367.253:366.635`

### Detailed Run Values (test 3)

| Run | Value (Seconds) |
| --- | --------------- |
| 1   | 367.204         |
| 2   | 367.253         |
| 3   | 366.635         |

### Summary Statistics (test 3)

- **Mean Value (Seconds)**: 367.031
- **Median Value (Seconds)**: 367.204
- **Standard Deviation (Seconds)**: 0.344

---

## Aircrack-ng Benchmark

### Test Identifier: `pts/aircrack-ng-1.3.0` (test 4)

#### Title: Aircrack-ng (test 4)

- **App Version**: 1.7
- **Arguments**: ``
- **Description**:
- **Scale**: k/s
- **Display Format**: BAR_GRAPH

### Data Entries (test 4)

- **Identifier**: AMD EPYC 7763 64-Core
- **Value (k/s)**: 7500.407
- **Raw String (k/s)**: `7500.5:7499.298:7501.422`

### Detailed Run Values (test 4)

| Run | Value (k/s) |
| --- | ----------- |
| 1   | 7500.5      |
| 2   | 7499.298    |
| 3   | 7501.422    |

### Summary Statistics (test 4)

- **Mean Value (k/s)**: 7500.407
- **Median Value (k/s)**: 7500.5
- **Standard Deviation (k/s)**: 1.065

---
