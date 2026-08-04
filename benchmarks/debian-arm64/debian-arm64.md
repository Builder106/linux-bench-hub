# Debian-arm64 Benchmark Results

This document provides detailed benchmarking results for Debian GNU/Linux 13, captured monthly by LinuxBenchHub's CI pipeline via Docker using the Phoronix Test Suite.

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

- **OS**: Debian GNU/Linux 13
- **Kernel**: 6.17.0-1011-oracle (aarch64)
- **Compiler**: GCC 14.2.0
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
- **Value (MB/s)**: 11667.0
- **Raw String (MB/s)**: `11693:11696.4:11611.6`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 11693.0 |
| 2   | 11696.4 |
| 3   | 11611.6 |

### Summary Statistics

- **Mean Value (MB/s)**: 11667.0
- **Median Value (MB/s)**: 11693.0
- **Standard Deviation (MB/s)**: 48.008

### Test Identifier: `pts/tinymembench-1.0.2`

#### Title: Tinymembench

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: ARMv8 Neoverse-N1
- **Value (MB/s)**: 47525.3
- **Raw String (MB/s)**: `47527.1:47488.1:47560.6`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 47527.1 |
| 2   | 47488.1 |
| 3   | 47560.6 |

### Summary Statistics

- **Mean Value (MB/s)**: 47525.267
- **Median Value (MB/s)**: 47527.1
- **Standard Deviation (MB/s)**: 36.285

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
- **Value (Seconds)**: 199.848
- **Raw String (Seconds)**: `199.791:199.892:199.861`

### Detailed Run Values

| Run | Value (Seconds) |
|-----|-------------------|
| 1   | 199.791 |
| 2   | 199.892 |
| 3   | 199.861 |

### Summary Statistics

- **Mean Value (Seconds)**: 199.848
- **Median Value (Seconds)**: 199.861
- **Standard Deviation (Seconds)**: 0.052

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
- **Value (k/s)**: 4271.842
- **Raw String (k/s)**: `4273.283:4270.992:4271.252`

### Detailed Run Values

| Run | Value (k/s) |
|-----|-------------------|
| 1   | 4273.283 |
| 2   | 4270.992 |
| 3   | 4271.252 |

### Summary Statistics

- **Mean Value (k/s)**: 4271.842
- **Median Value (k/s)**: 4271.252
- **Standard Deviation (k/s)**: 1.254

---
