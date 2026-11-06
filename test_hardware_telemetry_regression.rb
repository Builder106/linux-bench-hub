# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "timeout"
require "rbconfig"
require_relative "lib/linux_bench_hub/workload_dispatch"

class HardwareTelemetryRegressionTest < Minitest::Test
  HT = LinuxBenchHub::HardwareTelemetry
  WD = LinuxBenchHub::WorkloadDispatch

  def setup
    @root = Dir.mktmpdir("lbh-telemetry-regression")
    @proc = File.join(@root, "proc")
    @sys = File.join(@root, "sys")
    write("proc/stat", "cpu 100 0 20 500 0 0 0 0 0 0\nctxt 1000\nprocesses 50\n")
    write("proc/vmstat", "pgfault 100\npgmajfault 2\n")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write(path, content)
    target = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, content)
    target
  end

  def cpu(cpu: 0, package: 0, count: 0, time: 0)
    base = "sys/devices/system/cpu/cpu#{cpu}"
    write("#{base}/topology/physical_package_id", package.to_s)
    write("#{base}/thermal_throttle/package_throttle_count", count.to_s)
    write("#{base}/thermal_throttle/package_throttle_total_time_ms", time.to_s)
    write("#{base}/thermal_throttle/core_throttle_count", "0")
  end

  def collector(**options)
    HT::Collector.new(procfs_root: @proc, sysfs_root: @sys, perf: false, interval: 0, **options)
  end

  def test_missing_native_sensors_and_files_never_generate_simulation
    c = collector(procfs_root: File.join(@root, "absent"))
    c.start
    report = c.stop
    assert_equal "native", report.source
    assert_nil report.deterministic?
    assert_nil report.thermal[:package_throttle_delta]
    assert_empty report.counters
    assert_includes report.summary_markdown, "UNVERIFIED"
    assert_same report, c.stop
  end

  def test_native_deltas_and_throttle_time_without_new_event
    cpu(count: 5, time: 100)
    c = collector.start
    cpu(count: 5, time: 200)
    write("proc/stat", "cpu 180 0 30 510 0 0 0 0 0 0\nctxt 1100\nprocesses 52\n")
    report = c.stop
    assert_equal 0, report.thermal[:package_throttle_delta]
    assert_equal 100, report.thermal[:package_throttle_time_ms_delta]
    assert report.throttling_detected?
    refute report.deterministic?
    assert_equal 100, report.counters[:context_switches_total]
    assert_equal 80.0, report.counters.dig(:cpu_utilization, :user_pct)
  end

  def test_zero_events_with_readable_sensors
    cpu
    c = collector.start
    report = c.stop
    assert report.deterministic?
    refute report.throttling_detected?
    assert_equal 0, report.sample_count
  end

  def test_reset_or_hotplug_does_not_fabricate_throttle_events
    cpu(count: 100)
    c = collector.start
    cpu(count: 1)
    cpu(cpu: 1, package: 1, count: 1000)
    report = c.stop
    refute report.throttling_detected?
    assert_nil report.deterministic?
  end

  def test_package_counts_and_times_are_deduplicated_independently
    cpu(cpu: 0, count: 5, time: 100)
    cpu(cpu: 1, count: 5, time: 130)
    monitor = HT::ThermalMonitor.new(sysfs_root: @sys)
    initial = monitor.read_state
    cpu(cpu: 0, count: 6, time: 150)
    cpu(cpu: 1, count: 6, time: 180)
    final = monitor.read_state
    assert_equal 130, initial[:package_throttle_time_ms]
    delta = monitor.compute_delta(initial, final)
    assert_equal 1, delta[:package_throttle_delta]
    assert_equal 50, delta[:package_throttle_time_ms_delta]
  end

  def test_hottest_zone_and_intermediate_spike_are_retained
    cpu
    write("sys/class/thermal/thermal_zone0/temp", "40000")
    write("sys/class/thermal/thermal_zone1/temp", "90000")
    c = collector.start
    write("sys/class/thermal/thermal_zone1/temp", "105000")
    c.capture_sample(index: 1, elapsed: 1)
    write("sys/class/thermal/thermal_zone1/temp", "50000")
    report = c.stop
    assert_equal 105.0, report.thermal[:peak_celsius]
    assert_nil report.thermal[:headroom_celsius] # no critical trip was exposed
  end

  def test_invalid_sensor_values_are_unavailable
    write("sys/class/thermal/thermal_zone0/temp", "broken")
    write("sys/devices/system/cpu/cpu0/thermal_throttle/core_throttle_count", "broken")
    state = HT::ThermalMonitor.new(sysfs_root: @sys).read_state
    assert_nil state[:max_temp_c]
    assert_nil state[:core_throttle_count]
  end

  def test_sampler_bounds_memory_and_stops_promptly
    source = Object.new
    def source.capture_sample(index:, elapsed:)
      { sample_index: index, elapsed_seconds: elapsed }
    end
    sampler = HT::Sampler.new(source, interval: 60, max_samples: 2)
    5.times { |i| sampler.add_sample(sample_index: i) }
    assert_equal [3, 4], sampler.samples.map { |s| s[:sample_index] }
    sampler.start
    Timeout.timeout(1) { sampler.stop }
    refute sampler.running?
  end

  def test_exception_stops_monitor_sampler
    active = nil
    assert_raises(RuntimeError) do
      HT.monitor(procfs_root: @proc, sysfs_root: @sys, perf: false, interval: 60) do |c|
        active = c
        raise "benchmark failed"
      end
    end
    refute active.sampler.running?
    assert_instance_of HT::Report, active.stop
  end

  def test_dispatch_exception_stops_collector
    active = collector(interval: 60)
    target = Class.new(WD::SimulatedTarget) do
      def execute(*)
        raise "benchmark failed"
      end
    end.new
    HT::Collector.stub(:new, active) do
      assert_raises(RuntimeError) do
        WD::Dispatcher.new.dispatch(WD::Pipeline.standard(output_dir: @root), target)
      end
    end
    refute active.sampler.running?
  end

  def test_remote_targets_are_not_measured_on_the_dispatch_host
    [:ssh, :docker].each do |type|
      target = WD::SimulatedTarget.new
      target.define_singleton_method(:target_type) { type }
      result = WD::Dispatcher.new.dispatch(WD::Pipeline.standard(output_dir: @root), target, run_id: type.to_s)
      assert result.success?
      assert_equal "unavailable", result.telemetry_report.source
      assert_nil result.deterministic?
      assert_empty result.telemetry_report.counters
    end
  end

  def test_invalid_polling_intervals_fail_before_execution
    [-1, 0.01, Float::INFINITY, Float::NAN, "invalid"].each do |value|
      assert_raises(ArgumentError) { collector(interval: value) }
      assert_raises(ArgumentError) { WD::Pipeline.standard(telemetry_interval: value) }
    end
  end

  def test_report_survives_plain_json_hash_roundtrip
    original = HT::SimulatedProvider.new.generate_report
    restored = HT::Report.from_h(JSON.parse(original.to_json))
    assert_equal original.summary_markdown, restored.summary_markdown
  end

  def test_perf_parser_rejects_unavailable_events_and_preserves_large_integer_counts
    values = HT::PerfCounters.parse("123456789012345678;;cycles;100;100\n<not supported>;;instructions;0;0\n200;;cache-misses;100;100\n")
    assert_equal 123456789012345678, values[:cycles]
    assert_equal 200, values[:cache_misses]
    refute values.key?(:instructions)
  end

  def test_missing_perf_is_explicit
    result = HT::PerfCounters.new(executable: File.join(@root, "missing-perf")).start.stop
    refute result[:available]
    assert_empty result[:values]
    assert_equal HT::PerfCounters::EVENTS, result[:unavailable_events]
  end

  def test_perf_process_is_stopped_and_reaped
    # A fake perf isolates process lifecycle and CSV parsing from host privileges.
    perf = write("perf", <<~RUBY)
      #!#{RbConfig.ruby}
      trap("INT") { STDERR.puts "100;;cycles;100;100"; exit 0 }
      File.write(#{File.join(@root, "ready").inspect}, Process.pid.to_s)
      sleep
    RUBY
    FileUtils.chmod(0o755, perf)
    counter = HT::PerfCounters.new(executable: perf).start
    begin
      Timeout.timeout(3) { sleep 0.01 until File.exist?(File.join(@root, "ready")) }
      pid = File.read(File.join(@root, "ready")).to_i
      result = counter.stop
      assert result[:available]
      assert_equal 100, result[:values][:cycles]
      assert_raises(Errno::ECHILD) { Process.waitpid(pid, Process::WNOHANG) }
    ensure
      counter.stop
    end
  end
end
