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
- **Disk**: 161GB BlockVolume
- **Graphics**: virtio_gpudrmfb
- **Monitor**: QEMU Monitor

### Software

- **OS**: Debian GNU/Linux 13
- **Kernel**: 6.17.0-1018-oracle (aarch64)
- **Compiler**: GCC 14.2.0
- **File-System**: overlayfs
- **Screen Resolution**: 1280x800
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

- **Identifier**: ARMv8 Neoverse-N1
- **Value (MB/s)**: 11919.6
- **Raw String (MB/s)**: `12081.7:11633.9:12043.1`

### Detailed Run Values (test 1)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 12081.7      |
| 2   | 11633.9      |
| 3   | 12043.1      |

### Summary Statistics (test 1)

- **Mean Value (MB/s)**: 11919.567
- **Median Value (MB/s)**: 12043.1
- **Standard Deviation (MB/s)**: 248.146

### Test Identifier: `pts/tinymembench-1.0.2` (test 2)

#### Title: Tinymembench (test 2)

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries (test 2)

- **Identifier**: ARMv8 Neoverse-N1
- **Value (MB/s)**: 47470.9
- **Raw String (MB/s)**: `47519.7:47423.3:47469.6`

### Detailed Run Values (test 2)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 47519.7      |
| 2   | 47423.3      |
| 3   | 47469.6      |

### Summary Statistics (test 2)

- **Mean Value (MB/s)**: 47470.867
- **Median Value (MB/s)**: 47469.6
- **Standard Deviation (MB/s)**: 48.212

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

- **Identifier**: ARMv8 Neoverse-N1
- **Value (Seconds)**: 237.698
- **Raw String (Seconds)**: `237.107:238.025:237.961`

### Detailed Run Values (test 3)

| Run | Value (Seconds) |
| --- | --------------- |
| 1   | 237.107         |
| 2   | 238.025         |
| 3   | 237.961         |

### Summary Statistics (test 3)

- **Mean Value (Seconds)**: 237.698
- **Median Value (Seconds)**: 237.961
- **Standard Deviation (Seconds)**: 0.513

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

- **Identifier**: ARMv8 Neoverse-N1
- **Value (k/s)**: 3699.635
- **Raw String (k/s)**: `3287.725:3652.637:3723.387:3642.309:3345.511:4097.679:3697.419:3838.126:3638.606:4071.467:3598.347:3374.275:3671.583:3754.223:4101.228`

### Detailed Run Values (test 4)

| Run | Value (k/s) |
| --- | ----------- |
| 1   | 3287.725    |
| 2   | 3652.637    |
| 3   | 3723.387    |
| 4   | 3642.309    |
| 5   | 3345.511    |
| 6   | 4097.679    |
| 7   | 3697.419    |
| 8   | 3838.126    |
| 9   | 3638.606    |
| 10  | 4071.467    |
| 11  | 3598.347    |
| 12  | 3374.275    |
| 13  | 3671.583    |
| 14  | 3754.223    |
| 15  | 4101.228    |

### Summary Statistics (test 4)

- **Mean Value (k/s)**: 3699.635
- **Median Value (k/s)**: 3671.583
- **Standard Deviation (k/s)**: 253.814

---
