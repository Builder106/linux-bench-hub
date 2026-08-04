# Fedora Benchmark Results

This document provides detailed benchmarking results for Fedora Linux 44, captured monthly by LinuxBenchHub's CI pipeline via Docker using the Phoronix Test Suite.

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

- **OS**: Fedora Linux 44
- **Kernel**: 6.17.0-1020-azure (x86_64)
- **Compiler**: GCC 16.1.1 20260515
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
- **Value (MB/s)**: 22071.4
- **Raw String (MB/s)**: `21476.6:22295.4:22442.1`

### Detailed Run Values (test 1)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 21476.6      |
| 2   | 22295.4      |
| 3   | 22442.1      |

### Summary Statistics (test 1)

- **Mean Value (MB/s)**: 22071.367
- **Median Value (MB/s)**: 22295.4
- **Standard Deviation (MB/s)**: 520.28

### Test Identifier: `pts/tinymembench-1.0.2` (test 2)

#### Title: Tinymembench (test 2)

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries (test 2)

- **Identifier**: AMD EPYC 7763 64-Core
- **Value (MB/s)**: 36227.9
- **Raw String (MB/s)**: `35632.5:36634:36417.1`

### Detailed Run Values (test 2)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 35632.5      |
| 2   | 36634.0      |
| 3   | 36417.1      |

### Summary Statistics (test 2)

- **Mean Value (MB/s)**: 36227.867
- **Median Value (MB/s)**: 36417.1
- **Standard Deviation (MB/s)**: 526.885

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
- **Value (Seconds)**: 352.315
- **Raw String (Seconds)**: `352.229:352.719:351.997`

### Detailed Run Values (test 3)

| Run | Value (Seconds) |
| --- | --------------- |
| 1   | 352.229         |
| 2   | 352.719         |
| 3   | 351.997         |

### Summary Statistics (test 3)

- **Mean Value (Seconds)**: 352.315
- **Median Value (Seconds)**: 352.229
- **Standard Deviation (Seconds)**: 0.369

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
- **Value (k/s)**: 7583.768
- **Raw String (k/s)**: `7591.058:7567.514:7592.732`

### Detailed Run Values (test 4)

| Run | Value (k/s) |
| --- | ----------- |
| 1   | 7591.058    |
| 2   | 7567.514    |
| 3   | 7592.732    |

### Summary Statistics (test 4)

- **Mean Value (k/s)**: 7583.768
- **Median Value (k/s)**: 7591.058
- **Standard Deviation (k/s)**: 14.101

---
