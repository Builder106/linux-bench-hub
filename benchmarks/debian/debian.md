# Debian Benchmark Results

This document provides detailed benchmarking results for Debian GNU/Linux 13, captured monthly by LinuxBenchHub's CI pipeline via Docker using the Phoronix Test Suite.

## Table of Contents

1. [System Information](#system-information)
2. [Tinymembench Benchmark](#tinymembench-benchmark)
3. [C-Ray Benchmark](#c-ray-benchmark)
4. [Aircrack-ng Benchmark](#aircrack-ng-benchmark)

## System Information

### Hardware

- **Processor**: Intel Xeon Platinum 8370C @ 2.80GHz (2 Cores / 4 Threads)
- **Motherboard**: Microsoft Virtual Machine (Hyper-V UEFI v4.1 BIOS)
- **Memory**: 16GB
- **Disk**: 161GB Virtual Disk
- **Graphics**: hyperv_drmdrmfb

### Software

- **OS**: Debian GNU/Linux 13
- **Kernel**: 6.17.0-1018-azure (x86_64)
- **Compiler**: GCC 14.2.0
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

- **Identifier**: Intel Xeon Platinum 8370C
- **Value (MB/s)**: 15101.0
- **Raw String (MB/s)**: `14421.2:16034.7:16029.8:13573.7:15697:15275.2:15128.9:15343.7:14405.1`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 14421.2 |
| 2   | 16034.7 |
| 3   | 16029.8 |
| 4   | 13573.7 |
| 5   | 15697.0 |
| 6   | 15275.2 |
| 7   | 15128.9 |
| 8   | 15343.7 |
| 9   | 14405.1 |

### Summary Statistics

- **Mean Value (MB/s)**: 15101.033
- **Median Value (MB/s)**: 15275.2
- **Standard Deviation (MB/s)**: 826.042

### Test Identifier: `pts/tinymembench-1.0.2`

#### Title: Tinymembench

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: Intel Xeon Platinum 8370C
- **Value (MB/s)**: 26571.9
- **Raw String (MB/s)**: `26645.1:26681:26694.6:26302.9:26697.8:26421.1:26374:26677.9:26652.8`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 26645.1 |
| 2   | 26681.0 |
| 3   | 26694.6 |
| 4   | 26302.9 |
| 5   | 26697.8 |
| 6   | 26421.1 |
| 7   | 26374.0 |
| 8   | 26677.9 |
| 9   | 26652.8 |

### Summary Statistics

- **Mean Value (MB/s)**: 26571.911
- **Median Value (MB/s)**: 26652.8
- **Standard Deviation (MB/s)**: 158.198

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

- **Identifier**: Intel Xeon Platinum 8370C
- **Value (Seconds)**: 456.055
- **Raw String (Seconds)**: `456.927:455.706:455.532`

### Detailed Run Values

| Run | Value (Seconds) |
|-----|-------------------|
| 1   | 456.927 |
| 2   | 455.706 |
| 3   | 455.532 |

### Summary Statistics

- **Mean Value (Seconds)**: 456.055
- **Median Value (Seconds)**: 455.706
- **Standard Deviation (Seconds)**: 0.76

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

- **Identifier**: Intel Xeon Platinum 8370C
- **Value (k/s)**: 6663.283
- **Raw String (k/s)**: `6669.034:6655.157:6665.657`

### Detailed Run Values

| Run | Value (k/s) |
|-----|-------------------|
| 1   | 6669.034 |
| 2   | 6655.157 |
| 3   | 6665.657 |

### Summary Statistics

- **Mean Value (k/s)**: 6663.283
- **Median Value (k/s)**: 6665.657
- **Standard Deviation (k/s)**: 7.237

---
