# Cross-Kernel Comparison Engine

## Scope and acceptance

The v1.2 engine automatically diffs recorded PTS benchmark sample traces between
two kernel versions. It consumes the existing single-system `composite.xml`
contract produced by workload dispatch and monthly captures. No new capture
schema, privileged kernel switching, frontend, or visualization is required.
Perfetto and FlameGraph exports remain a separate milestone.

Acceptance requires direction-aware regression detection, configurable tolerance,
stable metric matching, explicit added/removed metrics, compatibility checks,
machine-readable evidence, and nonzero automation exit codes for regressions or
incomplete comparisons. `ruby test_kernel_comparison.rb` exercises these behaviors
with synthetic traces and an archived PTS capture, without running benchmarks.
CI runs this suite alongside dispatch and telemetry tests.

## CLI and library

```bash
bin/lbh-compare-kernels --threshold 5 baseline/composite.xml candidate/composite.xml > diff.json
```

The CLI writes one JSON report to stdout, preserving both input files. Invalid
input writes an explanation to stderr and emits no JSON. Shell redirection can
save a report even when the comparison returns a regression status.

| Exit | Report status | Meaning |
| --- | --- | --- |
| 0 | `passed` | All metrics matched; none exceeded the regression tolerance |
| 1 | `regression` | At least one matched metric regressed beyond tolerance |
| 2 | `partial` | At least one metric was added or removed, including no overlap |
| 2 | `incompatible` | Recorded environments differ, or kernel versions are identical |
| 2 | No report | Invalid arguments, unreadable files, or malformed captures |

Partial reports retain regression verdicts for matched metrics; their summary
must still be inspected. Incompatible reports suppress all performance deltas
and label overlapping metrics `incomparable`.

```ruby
require_relative "lib/linux_bench_hub/kernel_comparison"

comparison = LinuxBenchHub::KernelComparison
baseline = comparison::Capture.load("baseline/composite.xml")
candidate = comparison::Capture.load("candidate/composite.xml")
report = comparison::Engine.new(threshold_percent: 5).compare(baseline, candidate)
```

The library returns a Ruby hash with schema version 1. It contains both captures'
paths and metadata, incompatibility reasons, warnings, status counts, and a sorted
metric list. Each matched metric retains both original sample arrays, sample
counts, arithmetic means, absolute delta, percentage change, and regression
percentage. Output contains no generated timestamp and is deterministic for the
same inputs, paths, and threshold.

## Matching and regression policy

A metric's identity is its exact versioned profile identifier, application
version, arguments, description, unit, and `LIB`/`HIB` proportion. Memcpy and
memset, disk operations, and different profile versions never collapse into one
average. Identity changes appear as removed and added metrics. XML order does
not affect matching or report order.

Means are calculated from finite, positive `RawString` samples rather than the
rounded aggregate `Value`. Missing samples, ambiguous duplicate metrics, multiple
systems or entries, mismatched entry/system identifiers, missing identity fields,
unknown proportions, DTDs, and entity declarations are rejected. Sample counts
may differ; these are independent traces, with no sample-by-sample pairing.

`change_percent = 100 * (candidate_mean - baseline_mean) / baseline_mean`.
For lower-is-better metrics, regression percentage equals percentage change; for
higher-is-better metrics, its sign is reversed. A value strictly greater than the
tolerance is a regression; strictly below its negative is an improvement; all
other changes are unchanged. The default tolerance is 5%; it must be finite and
nonnegative. Classification uses unrounded values. Unrepresentable percentages
are errors rather than non-finite JSON values.

This threshold is a comparison policy, not a statistical significance test.
Inspect raw samples and repeat controlled captures before attributing a slowdown.

## Environment guardrails and limitations

Captures must record processor, memory, OS, compiler, a kernel with architecture,
and PTS client version. Both architectures, all recorded hardware fields, all
non-kernel software fields (including storage filesystem and container layer when
present), and PTS versions must match. Metadata field order is ignored. Kernels
must differ; the first argument explicitly selects the baseline, without guessing
which version is newer. Full system JSON is retained and differences produce a
warning because it can include kernel settings, microcode, and security details.

Matching recorded hardware does not prove the same physical host, storage, load,
or thermal state. GitHub runners with the same advertised CPU can still differ.
The engine always reports this limitation. Review the corresponding
[`telemetry.json`](hardware_telemetry.md) source and thermal evidence, plus run
manifests, before attribution. This engine does not infer thermal stability from
missing telemetry, establish kernel causality, compare PMU counter rates, or read
stack/event tracing formats. Simulated captures are test evidence only. Containers
share their host kernel: changing a distro container alone is not a kernel test.
