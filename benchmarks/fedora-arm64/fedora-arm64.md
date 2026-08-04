# Fedora-arm64 Benchmark Results

This document provides detailed benchmarking results for Fedora Linux 44, captured monthly by LinuxBenchHub's CI pipeline via Docker using the Phoronix Test Suite.

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

- **OS**: Fedora Linux 44
- **Kernel**: 6.17.0-1018-oracle (aarch64)
- **Compiler**: GCC 16.1.1 20260515
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
- **Value (MB/s)**: 12822.2
- **Raw String (MB/s)**: `12915.1:12624.2:12927.4`

### Detailed Run Values (test 1)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 12915.1      |
| 2   | 12624.2      |
| 3   | 12927.4      |

### Summary Statistics (test 1)

- **Mean Value (MB/s)**: 12822.233
- **Median Value (MB/s)**: 12915.1
- **Standard Deviation (MB/s)**: 171.612

### Test Identifier: `pts/tinymembench-1.0.2` (test 2)

#### Title: Tinymembench (test 2)

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries (test 2)

- **Identifier**: ARMv8 Neoverse-N1
- **Value (MB/s)**: 47448.7
- **Raw String (MB/s)**: `47382.1:47551:47413`

### Detailed Run Values (test 2)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 47382.1      |
| 2   | 47551.0      |
| 3   | 47413.0      |

### Summary Statistics (test 2)

- **Mean Value (MB/s)**: 47448.7
- **Median Value (MB/s)**: 47413.0
- **Standard Deviation (MB/s)**: 89.931

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
- **Value (Seconds)**: 240.366
- **Raw String (Seconds)**: `240.699:238.731:241.669`

### Detailed Run Values (test 3)

| Run | Value (Seconds) |
| --- | --------------- |
| 1   | 240.699         |
| 2   | 238.731         |
| 3   | 241.669         |

### Summary Statistics (test 3)

- **Mean Value (Seconds)**: 240.366
- **Median Value (Seconds)**: 240.699
- **Standard Deviation (Seconds)**: 1.497

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
- **Value (k/s)**: 3813.301
- **Raw String (k/s)**: `3716.317:3923.098:3762.538:3851.249`

### Detailed Run Values (test 4)

| Run | Value (k/s) |
| --- | ----------- |
| 1   | 3716.317    |
| 2   | 3923.098    |
| 3   | 3762.538    |
| 4   | 3851.249    |

### Summary Statistics (test 4)

- **Mean Value (k/s)**: 3813.3
- **Median Value (k/s)**: 3806.894
- **Standard Deviation (k/s)**: 92.156

---
