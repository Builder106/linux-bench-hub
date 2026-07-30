<picture>
  <source media="(prefers-color-scheme: dark)"  srcset="assets/banner-dark.svg"  type="image/svg+xml">
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-light.svg" type="image/svg+xml">
  <source media="(prefers-color-scheme: dark)"  srcset="assets/banner-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-light.png">
  <img alt="LinuxBenchHub — compare Linux distros under identical virtual hardware, with a Rails dashboard and live noVNC view." src="assets/banner-dark.svg">
</picture>

[![CI](https://github.com/Builder106/linux-bench-hub/actions/workflows/ci.yml/badge.svg)](https://github.com/Builder106/linux-bench-hub/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/Ruby-3.3.0-CC342D.svg?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.0-D30001.svg?logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](#license)
[![Status](https://img.shields.io/badge/status-in--development-orange.svg)](#project-status)
[![Demo](https://img.shields.io/badge/demo-live-success.svg)](http://161.153.47.170:8080/showcase)

> A benchmarking dataset for Linux distros &mdash; run Phoronix Test Suite across identical hardware on Ubuntu, Fedora, and Debian, captured monthly in CI, with a Rails dashboard and R parsers consuming the same composite XML.

## What this is

LinuxBenchHub has three components:

1. **A benchmark dataset and analysis** under [`benchmarks/`](benchmarks/) &mdash; per-distro Phoronix Test Suite results (CPU, memory, network). Each distro has an R parsing script that extracts summary stats from the raw `pts/composite.xml`. The original bare-metal sample (VMware Fusion Pro on 2&times; i5-7360U) lives at the root of each distro folder; CI-captured runs land in `benchmarks/<distro>/captures/`.
2. **A capture pipeline** under [`.github/workflows/capture-benchmarks.yml`](.github/workflows/capture-benchmarks.yml) &mdash; a monthly GitHub Actions job that runs `pts/c-ray`, `pts/tinymembench`, and `pts/aircrack-ng` inside Ubuntu, Fedora, and Debian containers on the same `ubuntu-latest` runner, then commits the resulting `composite.xml` back to the repo. Free, reproducible, no cloud bill.
3. **A Rails 8 dashboard** under [`website/`](website/) &mdash; a web app that lists stored benchmarks, supports Devise auth, exports CSV/JSON, and renders charts with Chartkick. The dashboard reads the same `composite.xml` files the R scripts parse, so it stays in sync with whatever the CI workflow last captured. It also serves the CI-captured showcase (the per-distro writeups) at `/showcase`.

## Sample results &mdash; Ubuntu 24.04

The dataset has two reference platforms. The x86 sample is the original 2024 bare-metal capture on a 2&times; Intel Core i5-7360U (3 cores), 4 GB RAM, 21 GB disk, in VMware Fusion Pro 13.6.1. The arm64 sample is a 2026 capture on Oracle Cloud's Always-Free Ampere A1 (Neoverse-N1, 4 OCPU, 24 GB), captured natively over SSH by the CI workflow against the host provisioned in [`infra/oci-ampere/`](infra/oci-ampere/).

| Benchmark | Test | Metric | x86 (i5-7360U) | arm64 (Ampere A1) |
| --- | --- | --- | --- | --- |
| **C-Ray** (CPU) | `pts/c-ray-2.0.0`, 1080p @ 16 rpp | Seconds | 1,088.8 | 212.0 |
| **Tinymembench** (memcpy) | `pts/tinymembench-1.0.2` | MB/s | 11,209.5 | 12,155.5 |
| **Tinymembench** (memset) | `pts/tinymembench-1.0.2` | MB/s | 23,480.2 | 47,575.6 |
| **Aircrack-ng** (network) | `pts/aircrack-ng-1.3.0` | k/s | 4,542.6 | 4,154.3 |

Headline gap: Ampere is **~5&times; faster on C-Ray** and **~2&times; faster on memset**, comparable on memcpy and aircrack-ng. (Note: the x86 C-Ray label was previously "ms" in this README; PTS's `<Scale>` is `Seconds` &mdash; this row is now corrected.)

Full per-run data and visualizations:

- [**`benchmarks/ubuntu/ubuntu.md`**](benchmarks/ubuntu/ubuntu.md) &mdash; Ubuntu 24.04 (x86, VMware bare-metal sample)
- [**`benchmarks/ubuntu-arm64/composite-latest.xml`**](benchmarks/ubuntu-arm64/composite-latest.xml) &mdash; Ubuntu 24.04 (arm64, Ampere A1)
- [**`benchmarks/fedora/fedora.md`**](benchmarks/fedora/fedora.md) &mdash; Fedora Linux 41
- [**`benchmarks/debian/debian.md`**](benchmarks/debian/debian.md) &mdash; Debian 12

## How the pieces fit

```mermaid
flowchart LR
  cron[GitHub Actions<br/>monthly cron]
  ubuntu[ubuntu:24.04 container<br/>x86_64]
  fedora[fedora:41 container<br/>x86_64]
  debian[debian:12 container<br/>x86_64]
  ampere[Ampere A1 VM<br/>aarch64 over SSH]
  pts[Phoronix Test Suite<br/>c-ray, tinymembench, aircrack-ng]
  composite[benchmarks/*/composite-latest.xml]
  rparser[benchmarks/*/Parse_composite_*.R<br/>summary stats + plots]
  md[benchmarks/*/*.md<br/>static writeup]

  cron --> ubuntu
  cron --> fedora
  cron --> debian
  cron -.->|SSH| ampere
  ubuntu --> pts
  fedora --> pts
  debian --> pts
  ampere --> pts
  pts --> composite
  composite --> rparser
  rparser --> md

  rails[Rails 8 dashboard<br/>website/]
  charts[Chartkick + Groupdate]

  composite --> rails
  rails --> charts
```

The R parsers and the Rails app are interchangeable consumers of the same `composite.xml` &mdash; run the static analysis with R alone, or boot the dashboard alone, or both. The capture workflow doesn't care which one downstream uses the files.

## Repo layout

```
.
|-- benchmarks/              # captured Phoronix results, per platform
|   |-- ubuntu/              #   ubuntu.md + Parse_composite_Ubuntu.R + composite-latest.xml + captures/
|   |-- ubuntu-arm64/        #   Ampere A1 aarch64 captures (CI-captured over SSH)
|   |-- fedora/
|   `-- debian/
|-- infra/
|   `-- oci-ampere/          # OpenTofu module: Always-Free Ampere A1 host for arm64 captures
|-- .github/
|   |-- workflows/
|   |   |-- capture-benchmarks.yml   # monthly CI capture (containers + Ampere SSH)
|   |   |-- ci.yml                    # Rails test suite gate
|   |   `-- deploy.yml                # Rails app deploy
|   `-- scripts/
|       `-- pts-batch-config.xml      # seeded into PTS before non-interactive runs
|-- website/                 # Rails 8 dashboard (incl. the /showcase writeups)
|   |-- app/                 #   models, controllers, views
|   |-- config/              #   routes, Whenever schedule
|   `-- Dockerfile           #   production image
|-- linux_benchmarking.rb    # standalone CLI script for ad-hoc runs
|-- .lintr                   # R linter config for the Parse_composite_*.R scripts
`-- assets/                  # banner + social card
```

## Setup

### Capturing fresh benchmarks

Captures happen automatically on the 1st of every month via [`.github/workflows/capture-benchmarks.yml`](.github/workflows/capture-benchmarks.yml). To trigger an out-of-band run, push the workflow's "Run workflow" button on the Actions tab &mdash; you can pick a single distro or all three. The job commits `composite-YYYY-MM-DD.xml` (a dated archive) and overwrites `composite-latest.xml` (the stable pointer the dashboard and R scripts read).

To re-derive the summary stats from a fresh `composite.xml` locally:

```bash
# x86 CI capture
Rscript benchmarks/ubuntu/Parse_composite_Ubuntu.R \
  benchmarks/ubuntu/composite-latest.xml benchmarks/ubuntu/plots
# Ampere arm64 capture
Rscript benchmarks/ubuntu/Parse_composite_Ubuntu.R \
  benchmarks/ubuntu-arm64/composite-latest.xml benchmarks/ubuntu-arm64/plots
```

The script accepts `<composite.xml> <output_dir>` since the 2026-05 refactor, so the same parser handles both arches. R deps: `XML`, `dplyr`, `ggplot2`, `tidyr`, `jsonlite`, `rlang`. The `.lintr` at repo root pins the lint rules.

### Capturing arm64 (Ampere)

The arm64 leg runs on a long-lived Always-Free Ampere A1 host, not a container. Provisioning is one `tofu apply` in [`infra/oci-ampere/`](infra/oci-ampere/) &mdash; see that directory's README for the OCI-account prerequisites. Once the host exists and the repo secrets `OCI_AMPERE_HOST` + `OCI_AMPERE_SSH_KEY` (raw PEM &mdash; pipe via `gh secret set OCI_AMPERE_SSH_KEY < ~/.ssh/lbh-ampere`) are set, the monthly cron drives it automatically. Manual dispatches honour the `include_arm64` toggle.

### Running the Rails dashboard

```bash
cd website
bundle install
bin/rails db:prepare
bin/rails server
```

The dashboard reads the same `composite.xml` files the R scripts parse. No external services required &mdash; SQLite is the only datastore.

Deployment is configured for **Kamal** &mdash; see [`website/.kamal/`](website/.kamal/) and [`website/Dockerfile`](website/Dockerfile). The Kamal config is the Rails 8 default scaffold with placeholder values; fill in `image`, `servers`, `proxy.host`, and `registry.username` before `bin/kamal setup`.

## Project status

The architecture pivoted from "on-demand Azure VMs per click" to "monthly CI captures into git." That trade dropped the live-VM demo but bought reproducibility, $0 ongoing cost, and a much smaller security surface (no SSH passwords, no public VNC ports, no cloud cleanup races).

- **Ubuntu 26.04 / Fedora 44 / Debian 13** &mdash; the bare-metal sample sits at the root of each `benchmarks/<distro>/`, captured once on VMware Fusion Pro. CI runs capture fresh containerized numbers monthly into `benchmarks/<distro>/captures/`.
- **Ubuntu / Fedora / Debian arm64 (Ampere A1)** &mdash; captured natively over SSH against an Oracle Cloud Always-Free Ampere VM provisioned via [`infra/oci-ampere/`](infra/oci-ampere/), same three tests and all three distros as the x86 matrix. Gives the dataset an aarch64 column GitHub's x86-only runners can't produce.
- **Cross-distro comparison page** &mdash; the three writeups exist independently; a side-by-side comparison page is not yet written.
- **Rails dashboard** &mdash; live, serving the CI-captured showcase at `/showcase` (per-distro writeups, x86/arm64 switch) alongside its own Devise-authenticated user-submitted benchmark CRUD. Devise auth and Chartkick are wired up; expect rough edges elsewhere.
- **Kamal deploy** &mdash; live on the same Oracle Ampere VM that runs the arm64 capture, reached over plain HTTP at `http://161.153.47.170:8080` for now (no domain yet, so no HTTPS).

## Tech stack

- **Benchmarks**: Phoronix Test Suite, R (`XML`, `dplyr`, `ggplot2`, `tidyr`, `jsonlite`, `rlang`)
- **Capture (x86)**: GitHub Actions (monthly cron, distro containers on `ubuntu-latest`)
- **Capture (arm64)**: Oracle Cloud Ampere A1 (Always-Free, Ubuntu 24.04 aarch64), driven over SSH from the same workflow
- **Infra**: OpenTofu &mdash; see [`infra/oci-ampere/`](infra/oci-ampere/) for the VCN/subnet/security-list/instance module
- **Dashboard**: Rails 8.0, Ruby 3.3, SQLite, Puma, Hotwire (Turbo + Stimulus), Bootstrap, Chartkick + Groupdate
- **Auth**: Devise
- **Deploy**: Docker + Kamal (or any Docker-host PaaS)

## License

Code released under the [MIT License](LICENSE). Third-party components retain their upstream licenses: **Phoronix Test Suite** is GPLv3 (referenced, not bundled); **noVNC**, embedded under [`website/noVNC/`](website/noVNC/), is MPL-2.0; Rails and Ruby are MIT. Captured Phoronix outputs under `benchmarks/*/` are derivative works of the upstream tests.
