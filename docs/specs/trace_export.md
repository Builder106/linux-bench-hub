# Perfetto / FlameGraph integration

## Scope and acceptance

This v1.2 milestone exports existing Linux `perf script` call-stack samples for
external visualization. It adds an offline Ruby library and CLI, with no frontend
implementation. Workload dispatch, telemetry, and cross-kernel comparison are
already available; their PTS XML and counter reports contain no call stacks and
cannot be converted into profiles. A separately recorded, symbolized perf profile
is required. Collection stays opt-in because sampling changes workload overhead.

Acceptance requires valid Perfetto Chrome JSON and FlameGraph folded exports,
preserved process/thread identity and timestamps, root-to-leaf stacks, kernel
mapping annotations, deterministic sample aggregation, explicit event selection,
and failure on malformed or unsupported input. `ruby test_trace_export.rb` covers
these contracts without requiring perf permissions or live hardware.

## Usage

Record on the actual benchmark host, with whatever perf access it already has:

```bash
perf record -F 99 -g -e cycles --output perf.data -- ./workload
perf script -i perf.data --ns -F comm,pid,tid,cpu,time,event,ip,sym,dso > perf.txt

bin/lbh-export-trace perf.txt > samples.json
bin/lbh-export-trace --format folded perf.txt > stacks.collapsed
cat perf.txt | bin/lbh-export-trace --event cycles --format folded - > cycles.collapsed

# With the upstream FlameGraph tools installed separately:
/path/to/FlameGraph/flamegraph.pl --countname samples stacks.collapsed > flamegraph.svg
```

Open `samples.json` in Perfetto for a timeline of thread-scoped instant samples;
select a sample to inspect its CPU, event, original timestamp, addresses, and
root-to-leaf stack arguments. Open `stacks.collapsed` in Perfetto for its native
aggregated flamegraph view, or render it with upstream `flamegraph.pl`.
These exports generate data for external tools, with no bundled viewer or SVG.
See [Perfetto's supported formats](https://perfetto.dev/docs/getting-started/other-formats)
and [FlameGraph's folded stack contract](https://github.com/brendangregg/FlameGraph).
The input fields follow the [upstream perf script interface](https://github.com/torvalds/linux/blob/master/tools/perf/Documentation/perf-script.txt).

The command emits one artifact to stdout and returns 0 on success. Invalid
arguments, unreadable input, malformed records, or an empty selection return 2
with a diagnostic on stderr and no artifact on stdout. Redirection itself can
truncate an existing destination before the CLI runs; use a temporary destination
and rename after success when preserving an existing export matters. Input is
read-only. The tool does not execute commands from traces, fetch symbols, elevate
privileges, or upload profiles.

```ruby
require_relative "lib/linux_bench_hub/trace_export"

profile = File.open("perf.txt", "r:UTF-8") do |input|
  LinuxBenchHub::TraceExport::Profile.new(input, event: "cycles")
end
File.write("samples.json", profile.perfetto)
File.write("stacks.collapsed", profile.folded)
```

## Semantics and limits

- Input must use the explicit fields above: `comm PID/TID [CPU] SECONDS: EVENT:`,
  followed by indented `ADDRESS SYMBOL (DSO)` frames in perf's leaf-first order.
  Timestamps accept one to nine fractional digits and signed-64-bit nonnegative
  nanoseconds. IDs must be nonnegative signed-32-bit integers. Blank lines and
  `#` header comments are accepted; the last sample needs no trailing blank line.
  Single-ID default output, period fields, scheduler payloads, source lines,
  inline-only records, and lost-event records are rejected rather than guessed.
- Only one exact event name is aggregated. Mixed populations require `--event`;
  all records are validated even when filtered out. Event modifiers are part of
  the name. Every sample must contain at least one frame. Limits are 64 MiB of
  input, 100,000 samples before filtering, and 512 frames per sample; split larger
  inputs before export. UTF-8 and printable text with tabs are required.
- Each recorded sample contributes **one** folded count, regardless of perf's
  sampling period. Width means sample population, never measured function time,
  cycle count, off-CPU latency, or proof of kernel causality. JSON instant events
  have no invented durations. Variable sample periods can bias these counts.
- JSON events sort by timestamp, preserving input order for ties. `ts` is in
  microseconds relative to the earliest selected sample; original integer
  nanoseconds and the origin remain in the artifact. Do not merge this relative
  timeline into other captures without aligning their clocks. JSON is Chrome
  trace-event data, not native Perfetto protobuf or CPU profiling tables.
- Folded roots contain command, PID, and TID. Symbols retain DSO identity, strip
  hexadecimal offsets, and reverse into root-to-leaf order. Unknown symbols keep
  their addresses. Known kernel/module mappings have FlameGraph's `_[k]` suffix;
  unknown mappings and vdso are not classified as kernel. This is mapping-based
  evidence and depends on perf's symbolization. `%`, `;`, and `#` in labels are
  escaped as `%25`, `%3B`, and `%23` to preserve folded boundaries and comments.
- Inspect symbol availability, truncated stacks, perf loss diagnostics, sampling
  coverage, and host load before attributing a bottleneck. Missing kernel symbols
  are not resolved by this exporter. Archived benchmark samples and host-wide
  telemetry alone cannot locate a kernel function bottleneck. Do not compare
  absolute counts across captures of different lengths or sampling settings.
