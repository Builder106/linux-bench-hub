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
- **Disk**: 161GB BlockVolume
- **Graphics**: virtio_gpudrmfb
- **Monitor**: QEMU Monitor

### Software

- **OS**: Ubuntu 26.04 LTS
- **Kernel**: 6.17.0-1018-oracle (aarch64)
- **Compiler**: GCC 15.2.0
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
- **Value (MB/s)**: 12752.8
- **Raw String (MB/s)**: `12467.1:12946.7:12844.5`

### Detailed Run Values (test 1)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 12467.1      |
| 2   | 12946.7      |
| 3   | 12844.5      |

### Summary Statistics (test 1)

- **Mean Value (MB/s)**: 12752.767
- **Median Value (MB/s)**: 12844.5
- **Standard Deviation (MB/s)**: 252.617

### Test Identifier: `pts/tinymembench-1.0.2` (test 2)

#### Title: Tinymembench (test 2)

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries (test 2)

- **Identifier**: ARMv8 Neoverse-N1
- **Value (MB/s)**: 47490.1
- **Raw String (MB/s)**: `47491.2:47506.3:47472.9`

### Detailed Run Values (test 2)

| Run | Value (MB/s) |
| --- | ------------ |
| 1   | 47491.2      |
| 2   | 47506.3      |
| 3   | 47472.9      |

### Summary Statistics (test 2)

- **Mean Value (MB/s)**: 47490.133
- **Median Value (MB/s)**: 47491.2
- **Standard Deviation (MB/s)**: 16.726

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
- **Value (Seconds)**: 245.638
- **Raw String (Seconds)**: `244.433:246.879:245.601`

### Detailed Run Values (test 3)

| Run | Value (Seconds) |
| --- | --------------- |
| 1   | 244.433         |
| 2   | 246.879         |
| 3   | 245.601         |

### Summary Statistics (test 3)

- **Mean Value (Seconds)**: 245.638
- **Median Value (Seconds)**: 245.601
- **Standard Deviation (Seconds)**: 1.223

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
- **Value (k/s)**: 3726.172
- **Raw String (k/s)**: `3782.19:3689.443:3706.882`

### Detailed Run Values (test 4)

| Run | Value (k/s) |
| --- | ----------- |
| 1   | 3782.19     |
| 2   | 3689.443    |
| 3   | 3706.882    |

### Summary Statistics (test 4)

- **Mean Value (k/s)**: 3726.172
- **Median Value (k/s)**: 3706.882
- **Standard Deviation (k/s)**: 49.291

---
