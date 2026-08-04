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
- **Disk**: 107GB BlockVolume
- **Graphics**: virtio_gpudrmfb
- **Monitor**: QEMU Monitor

### Software

- **OS**: Fedora Linux 44
- **Kernel**: 6.17.0-1011-oracle (aarch64)
- **Compiler**: GCC 16.1.1 20260515
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
- **Value (MB/s)**: 11931.1
- **Raw String (MB/s)**: `11869:11897.8:12026.4`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 11869.0 |
| 2   | 11897.8 |
| 3   | 12026.4 |

### Summary Statistics

- **Mean Value (MB/s)**: 11931.067
- **Median Value (MB/s)**: 11897.8
- **Standard Deviation (MB/s)**: 83.807

### Test Identifier: `pts/tinymembench-1.0.2`

#### Title: Tinymembench

- **App Version**: 2018-05-28
- **Arguments**: ``
- **Description**: Standard Memset
- **Scale**: MB/s
- **Display Format**: BAR_GRAPH

### Data Entries

- **Identifier**: ARMv8 Neoverse-N1
- **Value (MB/s)**: 47576.7
- **Raw String (MB/s)**: `47637.1:47477.2:47615.7`

### Detailed Run Values

| Run | Value (MB/s) |
|-----|-------------------|
| 1   | 47637.1 |
| 2   | 47477.2 |
| 3   | 47615.7 |

### Summary Statistics

- **Mean Value (MB/s)**: 47576.667
- **Median Value (MB/s)**: 47615.7
- **Standard Deviation (MB/s)**: 86.803

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
- **Value (Seconds)**: 201.629
- **Raw String (Seconds)**: `201.827:200.84:202.221`

### Detailed Run Values

| Run | Value (Seconds) |
|-----|-------------------|
| 1   | 201.827 |
| 2   | 200.84 |
| 3   | 202.221 |

### Summary Statistics

- **Mean Value (Seconds)**: 201.629
- **Median Value (Seconds)**: 201.827
- **Standard Deviation (Seconds)**: 0.711

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
- **Value (k/s)**: 4333.746
- **Raw String (k/s)**: `4290.633:4356.678:4353.926`

### Detailed Run Values

| Run | Value (k/s) |
|-----|-------------------|
| 1   | 4290.633 |
| 2   | 4356.678 |
| 3   | 4353.926 |

### Summary Statistics

- **Mean Value (k/s)**: 4333.746
- **Median Value (k/s)**: 4353.926
- **Standard Deviation (k/s)**: 37.362

---
