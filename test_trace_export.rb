# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "lib/linux_bench_hub/trace_export"

class TraceExportTest < Minitest::Test
  Profile = LinuxBenchHub::TraceExport::Profile
  CLI = File.expand_path("bin/lbh-export-trace", __dir__)

  def sample(comm: "fio worker", pid: 42, tid: 43, time: "123.000001000", event: "cycles:k", symbol: "io_schedule+0x12", dso: "[kernel.kallsyms]")
    <<~TRACE
      #{comm} #{pid}/#{tid} [003] #{time}: #{event}:
              ffffffff81234567 #{symbol} (#{dso})
              0000000000400123 submit_io+0x2 (/usr/bin/fio)

    TRACE
  end

  def profile(text = sample, **options)
    Profile.new(StringIO.new(text), **options)
  end

  def test_folded_counts_root_to_leaf_and_kernel_annotation
    text = sample + sample(symbol: "io_schedule+0x99")
    assert_equal "fio worker-42/43;submit_io (/usr/bin/fio);io_schedule ([kernel.kallsyms])_[k] 2\n", profile(text).folded
  end

  def test_threads_processes_and_dsos_do_not_merge
    text = sample + sample(tid: 44) + sample(pid: 99) + sample(dso: "/usr/lib/libio.so")
    lines = profile(text).folded.lines
    assert_equal 4, lines.size
    assert lines.all? { |line| line.end_with?(" 1\n") }
    assert_equal lines.sort, lines
  end

  def test_perfetto_has_sorted_instants_relative_microseconds_and_original_stacks
    text = sample(time: "123.002001123", tid: 44) + sample
    report = JSON.parse(profile(text).perfetto)
    assert_equal 123_000_001_000, report.fetch("metadata").fetch("timestamp_origin_ns")
    assert_equal 2, report.fetch("metadata").fetch("sample_count")
    names, events = report.fetch("traceEvents").partition { |e| e["ph"] == "M" }
    assert_equal [ 43, 44 ], names.map { |e| e["tid"] }
    assert_equal [ 0, 2000.123 ], events.map { |e| e["ts"] }
    assert_equal [ 43, 44 ], events.map { |e| e["tid"] }
    events.each do |event|
      assert_equal "i", event.fetch("ph")
      assert_equal "t", event.fetch("s")
      refute event.key?("dur")
      assert_equal 42, event.fetch("pid")
      args = event.fetch("args")
      assert_equal 3, args.fetch("cpu")
      assert_equal "cycles:k", args.fetch("event")
      assert_equal [ "submit_io", "io_schedule" ], args.fetch("stack").map { |f| f["symbol"] }
      assert_equal "ffffffff81234567", args.fetch("stack").last.fetch("address")
    end
  end

  def test_equal_timestamps_and_repeated_exports_are_deterministic
    trace = profile(sample + sample(symbol: "other"))
    assert_equal trace.perfetto, trace.perfetto
    assert_equal trace.folded, trace.folded
    events = JSON.parse(trace.perfetto)["traceEvents"].select { |e| e["ph"] == "i" }
    assert_match(/io_schedule/, events.first["name"])
    assert_match(/other/, events.last["name"])
  end

  def test_thread_renames_keep_one_initial_name_and_per_sample_commands
    report = JSON.parse(profile(sample + sample(comm: "new name", time: "124.0")).perfetto)
    names, events = report["traceEvents"].partition { |event| event["ph"] == "M" }
    assert_equal 1, names.size
    assert_equal "fio worker", names.first["args"]["name"]
    assert_equal [ "fio worker", "new name" ], events.map { |event| event["args"]["comm"] }
  end

  def test_event_selection_does_not_mix_populations
    text = sample + sample(event: "instructions") + sample
    assert_match(/Multiple events/, assert_raises(ArgumentError) { profile(text) }.message)
    assert profile(text, event: "cycles:k").folded.end_with?(" 2\n")
    assert profile(text, event: "instructions").folded.end_with?(" 1\n")
    assert_raises(ArgumentError) { profile(text, event: "cycles") }
  end

  def test_escaping_preserves_frame_boundaries_without_collisions
    trace = profile(sample(comm: "#name;1%", symbol: "method;foo") + sample(symbol: "method%3Bfoo"))
    assert_includes trace.folded, "%23name%3B1%25-42/43;"
    assert_includes trace.folded, "method%3Bfoo"
    assert_includes trace.folded, "method%253Bfoo"
    args = JSON.parse(trace.perfetto)["traceEvents"].find { |e| e["ph"] == "i" }["args"]
    assert_equal "method;foo", args["stack"].last["symbol"]
  end

  def test_unknown_symbols_keep_addresses_and_user_mappings_are_not_kernel
    folded = profile(sample(symbol: "[unknown]", dso: "[unknown]")).folded
    assert_includes folded, "[unknown]@ffffffff81234567 ([unknown])"
    refute_includes folded, "_[k]"
    refute_includes profile(sample(dso: "[vdso]")).folded, "_[k]"
    assert_includes profile(sample(dso: "[ext4]")).folded, "_[k]"
    assert_includes profile(sample(dso: "/boot/vmlinux")).folded, "_[k]"
  end

  def test_comments_blank_lines_final_sample_without_newline_and_idle_thread
    text = "# perf header\n\n" + sample(pid: 0, tid: 0, time: "0.1").rstrip
    assert_includes profile(text).folded, "fio worker-0/0;"
    assert_equal 100_000_000, JSON.parse(profile(text).perfetto)["metadata"]["timestamp_origin_ns"]
  end

  def test_invalid_traces_fail_closed
    [ "", "# only a header\n", "<xml/>", "lost events\n", "  1234 orphan (lib)\n",
      sample.lines.first, sample.sub("42/43", "43"), sample.sub("cycles:k:", "9 cycles:k:"),
      sample.sub("123.000001000", "NaN"), sample.sub("123.000001000", "123.1234567890"),
      sample.sub("123.000001000", "9223372037.0"), sample + "unrecognized record\n",
      sample(pid: 2**31), sample(tid: 2**31), sample.sub("[003]", "[2147483648]"),
      sample.sub("io_schedule", "io\rschedule"),
      sample.sub("io_schedule", "io\u0000schedule"), sample.sub("io_schedule", "\xFF".b).force_encoding("UTF-8")
    ].each do |text|
      assert_raises(ArgumentError, text.inspect) { profile(text) }
    end
  end

  def test_resource_limits
    with_limit(:MAX_BYTES, sample.bytesize) { assert profile.folded.end_with?(" 1\n") }
    with_limit(:MAX_DEPTH, 2) { assert profile.folded.end_with?(" 1\n") }
    with_limit(:MAX_SAMPLES, 1) { assert profile.folded.end_with?(" 1\n") }
    with_limit(:MAX_BYTES, 10) { assert_raises(ArgumentError) { profile } }
    with_limit(:MAX_DEPTH, 1) { assert_raises(ArgumentError) { profile } }
    with_limit(:MAX_SAMPLES, 1) { assert_raises(ArgumentError) { profile(sample + sample) } }
  end

  def test_cli_formats_stdin_files_and_failures
    out, err, status = Open3.capture3(RbConfig.ruby, CLI, "-", stdin_data: sample)
    assert status.success?, err
    assert_empty err
    assert_equal 1, JSON.parse(out)["metadata"]["sample_count"]
    out, err, status = Open3.capture3(RbConfig.ruby, CLI, "--event", "instructions", "--format", "folded", "-", stdin_data: sample + sample(event: "instructions"))
    assert status.success?, err
    assert_equal profile.folded, out
    Dir.mktmpdir("lbh-trace") do |dir|
      path = File.join(dir, "perf.txt")
      File.write(path, sample)
      out, err, status = Open3.capture3(RbConfig.ruby, CLI, "--format", "folded", path)
      assert status.success?, err
      assert_equal profile.folded, out
      assert_equal sample, File.read(path)
    end
    [ [], [ "--format", "svg", "-" ], [ "missing.perf" ], [ "-", "extra" ], [ "--event", "absent", "-" ] ].each do |args|
      out, err, status = Open3.capture3(RbConfig.ruby, CLI, *args, stdin_data: sample)
      assert_equal 2, status.exitstatus
      assert_empty out
      assert_match(/Trace export failed/, err)
    end
    out, err, status = Open3.capture3(RbConfig.ruby, CLI, "-", stdin_data: "invalid\n")
    assert_equal 2, status.exitstatus
    assert_empty out
    assert_match(/line 1/, err)
    out, err, status = Open3.capture3(RbConfig.ruby, CLI, "--help")
    assert status.success?
    assert_empty err
    assert_match(/Usage:/, out)
  end

  def with_limit(name, value)
    namespace = LinuxBenchHub::TraceExport
    original = namespace.const_get(name)
    namespace.send(:remove_const, name)
    namespace.const_set(name, value)
    yield
  ensure
    namespace.send(:remove_const, name)
    namespace.const_set(name, original)
  end
end
