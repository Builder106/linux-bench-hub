# Contributing

LinuxBenchHub is a personal project mid-build. The Ubuntu writeup and R parsers work; the Rails dashboard and the Fedora/Debian writeups are in progress. Bug fixes and reproducibility improvements are welcome; large features are best opened as issues first so we agree on direction before code review.

## Development setup

### Static benchmarks (R)

```bash

# R deps (one-time)

Rscript -e 'install.packages(c("xml2", "dplyr", "ggplot2", "tidyr"))'

# Re-parse an existing composite into summary stats + plots

Rscript benchmarks/ubuntu/Parse_composite_Ubuntu.R path/to/composite.xml
```

Lint rules for the R scripts are pinned in `.lintr`at repo root; run via`lintr::lint_dir(".")` if you have lintr installed.

## Rails dashboard

```bash
cd website

# Ruby version is pinned in website/.ruby-version (3.3.0)

# Use rbenv, asdf, or your Ruby version manager of choice

bundle install

# Database, asset prep

bin/rails db:prepare

# Dev server

bin/rails server
```

The dashboard reads `benchmarks/<distro>/composite-latest.xml` directly &mdash; no VMware, no Azure, no live VM spawning. To pick up fresh captures locally, either wait for the monthly CI run to push them or trigger the [`capture-benchmarks.yml`](.github/workflows/capture-benchmarks.yml) workflow manually and pull.

## Lint

The Rails app uses the omakase Ruby style (`website/.rubocop.yml`):

```bash
cd website && bundle exec rubocop --parallel
```

## Project-specific guardrails

- **Identical hardware per capture batch is load-bearing.** The original sample ran on a specific VMware Fusion profile (2&times; i5-7360U, 4 GB RAM); the CI captures run on whatever GitHub assigns to `ubuntu-latest`. Don't mix runs from different hardware profiles in the same `composite-latest.xml` &mdash; that breaks the comparison the whole project is built around.
- **`composite.xml` is the contract between the R parser and the Rails ingester.** Both sides read the same XML; don't split them onto separate schemas. If you change the parser, change the ingester in the same PR.
- **The `.kamal/` config is not currently pointing at a live host.** Don't add a "deploy to prod" CI step without first confirming the deploy target exists.
- **`.github/workflows/capture-benchmarks.yml`writes back to`main`.** Any breaking change to the workflow's git operations (pull/rebase/push) can corrupt history on the default branch. Test such changes on a feature branch with `workflow_dispatch` first.
- **Don't commit raw test runs that don't have a writeup.** The CI workflow handles its own archival under `benchmarks/<distro>/captures/`; manual additions should track to the `<distro>.md` markdown writeup.
- **Devise migrations and seeds are not in a known-stable state.** Treat the database as scratch in development &mdash; don't write production data assumptions into seeds yet.

## Commit conventions

The existing log uses short imperative subjects. Examples:

```text
Add Rails UJS support, update performance benchmarks controller for destroy action, and adjust JavaScript imports
Add rdoc for documentation, implement background job for benchmark execution, and enhance GUI with VM connection details
Trying to fix this
```

(The last one is honest about debugging state; that's fine when nothing in production depends on the message.) Match the imperative style. No AI co-author trailer.

## PR process

1. Open an issue first for anything that touches more than one of: benchmarks, R parsers, Rails dashboard. Easier to align on scope before code review.
2. Run the relevant lint and tests locally before opening the PR:

- Static benchmarks: `Rscript -e 'lintr::lint_dir(".")'`
- Rails: `cd website && bundle exec rubocop --parallel && bin/rails test`

1. CI (Ruby + R syntax) must be green.
2. Squash-merge into `main`.

## Scope

**In scope:**

- Finishing the Fedora 41 and Debian 12 writeups (`benchmarks/fedora/fedora.md`, `benchmarks/debian/debian.md`) from the captured raw data.
- Wiring the Rails dashboard to read `benchmarks/<distro>/composite-latest.xml` on boot.
- Adding new Phoronix tests to the capture workflow (apply to all three distros in the same PR to keep the comparison fair).
- Improving the R parser output (better plots, additional summary stats).
- Documentation and README clarifications.

**Out of scope:**

- Switching benchmarking tools (e.g. UnixBench, Geekbench) &mdash; the cross-distro comparison is anchored to Phoronix Test Suite.
- Re-introducing the on-demand VM model (`BenchmarkService`, live noVNC viewer). That was retired for a reason: hardcoded SSH passwords, public VNC ports, and unbounded cloud spend.
- Adding distros without a corresponding capture workflow matrix entry and at least one initial run committed.
- Bundling Phoronix Test Suite source into this repo &mdash; it's pulled fresh in the workflow.

If you're unsure, open an issue and ask.
