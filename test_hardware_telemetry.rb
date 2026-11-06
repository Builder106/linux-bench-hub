# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "lib/linux_bench_hub/hardware_telemetry"
require_relative "lib/linux_bench_hub/workload_dispatch"

class HardwareTelemetryTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir("lbh_telemetry_test_")
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir) if File.directory?(@tmp_dir)
  end

  # ==========================================
  # Snapshot Tests
  # ==========================================

  def test_snapshot_creation_and_defaults
    snap = LinuxBenchHub::HardwareTelemetry::Snapshot.new
    assert_instance_of Time, snap.timestamp
    assert_operator snap.monotonic_time, :>, 0
    assert_equal({}, snap.cpu_stats)
    assert_equal({}, snap.thermal)
    assert_equal({}, snap.cpu_freq)
  end

  def test_snapshot_serialization_roundtrip
    original = LinuxBenchHub::HardwareTelemetry::Snapshot.new(
      timestamp: Time.utc(2026, 11, 6, 18, 0, 0),
      monotonic_time: 1234.56,
      cpu_stats: { ctxt: 50_000, user: 10_000 },
      vm_stats: { pgfault: 4_000 },
      cpu_freq: { min_mhz: 2400.0, max_mhz: 3200.0, avg_mhz: 2800.0, governor: "performance" },
      thermal: { mean_temp_c: 48.5, package_throttle_count: 2 },
      perf_counters: { cycles: 5_000_000 }
    )

    h = original.to_h
    restored = LinuxBenchHub::HardwareTelemetry::Snapshot.from_h(h)

    assert_equal original.timestamp.iso8601(3), restored.timestamp.iso8601(3)
    assert_in_delta original.monotonic_time, restored.monotonic_time, 0.001
    assert_equal 50_000, restored.cpu_stats[:ctxt]
    assert_equal 4_000, restored.vm_stats[:pgfault]
    assert_equal 2800.0, restored.cpu_freq[:avg_mhz]
    assert_equal 48.5, restored.thermal[:mean_temp_c]
    assert_equal 5_000_000, restored.perf_counters[:cycles]
  end

  # ==========================================
  # ThermalMonitor Tests (Mocked Sysfs)
  # ==========================================

  def test_thermal_monitor_parses_sysfs_zones_and_trips
    sysfs = File.join(@tmp_dir, "sys")
    zone0 = File.join(sysfs, "class/thermal/thermal_zone0")
    FileUtils.mkdir_p(zone0)

    File.write(File.join(zone0, "type"), "x86_pkg_temp\n")
    File.write(File.join(zone0, "temp"), "48500\n")
    File.write(File.join(zone0, "trip_point_0_temp"), "100000\n")
    File.write(File.join(zone0, "trip_point_0_type"), "critical\n")

    monitor = LinuxBenchHub::HardwareTelemetry::ThermalMonitor.new(sysfs_root: sysfs)
    state = monitor.read_state

    assert_equal 1, state[:zones].size
    assert_equal "thermal_zone0", state[:zones].first[:id]
    assert_equal "x86_pkg_temp", state[:zones].first[:type]
    assert_equal 48.5, state[:zones].first[:temp_c]
    assert_equal 48.5, state[:mean_temp_c]
    assert_equal 48.5, state[:max_temp_c]

    trips = state[:zones].first[:trip_points]
    assert_equal 1, trips.size
    assert_equal "critical", trips.first[:type]
    assert_equal 100.0, trips.first[:temp_c]
  end

  def test_thermal_monitor_parses_cpu_throttle_counters
    sysfs = File.join(@tmp_dir, "sys")
    cpu0_throttle = File.join(sysfs, "devices/system/cpu/cpu0/thermal_throttle")
    cpu0_topo = File.join(sysfs, "devices/system/cpu/cpu0/topology")
    cpu1_throttle = File.join(sysfs, "devices/system/cpu/cpu1/thermal_throttle")
    cpu1_topo = File.join(sysfs, "devices/system/cpu/cpu1/topology")
    FileUtils.mkdir_p(cpu0_throttle)
    FileUtils.mkdir_p(cpu0_topo)
    FileUtils.mkdir_p(cpu1_throttle)
    FileUtils.mkdir_p(cpu1_topo)

    File.write(File.join(cpu0_topo, "physical_package_id"), "0\n")
    File.write(File.join(cpu0_throttle, "package_throttle_count"), "5\n")
    File.write(File.join(cpu0_throttle, "core_throttle_count"), "2\n")
    File.write(File.join(cpu0_throttle, "package_throttle_total_time_ms"), "150\n")
    File.write(File.join(cpu0_throttle, "core_throttle_total_time_ms"), "60\n")

    # cpu1 is on the same physical package (0)
    File.write(File.join(cpu1_topo, "physical_package_id"), "0\n")
    File.write(File.join(cpu1_throttle, "package_throttle_count"), "5\n")
    File.write(File.join(cpu1_throttle, "core_throttle_count"), "3\n")
    File.write(File.join(cpu1_throttle, "package_throttle_total_time_ms"), "150\n")
    File.write(File.join(cpu1_throttle, "core_throttle_total_time_ms"), "90\n")

    monitor = LinuxBenchHub::HardwareTelemetry::ThermalMonitor.new(sysfs_root: sysfs)
    throttle = monitor.read_throttle_counters

    # Package throttle should be deduplicated to 5, core throttles summed to 5
    assert_equal 5, throttle[:package_throttle_count]
    assert_equal 5, throttle[:core_throttle_count]
    assert_equal 150, throttle[:package_throttle_time_ms]
    assert_equal 150, throttle[:core_throttle_time_ms]
  end

  def test_thermal_monitor_computes_delta_and_detects_throttling
    monitor = LinuxBenchHub::HardwareTelemetry::ThermalMonitor.new(sysfs_root: @tmp_dir)

    initial = {
      package_throttle_count: 5,
      core_throttle_count: 2,
      package_throttle_time_ms: 100,
      core_throttle_time_ms: 40,
      mean_temp_c: 45.0, max_temp_c: 45.0,
      zones: [ { id: "z0", type: "x86_pkg", temp_c: 45.0, trip_points: [ { type: "critical", temp_c: 100.0 } ] } ]
    }

    final = {
      package_throttle_count: 9, # +4
      core_throttle_count: 5,    # +3
      package_throttle_time_ms: 220, # +120ms
      core_throttle_time_ms: 100,    # +60ms
      mean_temp_c: 98.2, max_temp_c: 98.2,
      zones: [ { id: "z0", type: "x86_pkg", temp_c: 98.2, trip_points: [ { type: "critical", temp_c: 100.0 } ] } ]
    }

    [ initial, final ].each do |state|
      state[:throttle_readings] = LinuxBenchHub::HardwareTelemetry::ThermalMonitor::METRICS.to_h do |key, _|
        [ key, { "cpu0" => { value: state[key], package: "0" } } ]
      end
    end
    delta = monitor.compute_delta(initial, final, [ { thermal_state: { max_temp_c: 85.0 } }, { thermal_state: { max_temp_c: 99.5 } } ])

    assert delta[:throttling_detected]
    assert_equal 4, delta[:package_throttle_delta]
    assert_equal 3, delta[:core_throttle_delta]
    assert_equal 120, delta[:package_throttle_time_ms_delta]
    assert_equal 60, delta[:core_throttle_time_ms_delta]
    assert_equal 45.0, delta[:initial_celsius]
    assert_equal 98.2, delta[:final_celsius]
    assert_equal 99.5, delta[:peak_celsius] # from samples
    assert_in_delta 0.5, delta[:headroom_celsius], 0.01 # 100.0 - 99.5
  end

  # ==========================================
  # Counters Tests (Mocked Procfs & Sysfs)
  # ==========================================

  def test_counters_parses_proc_stat_and_vmstat
    procfs = File.join(@tmp_dir, "proc")
    FileUtils.mkdir_p(procfs)

    stat_content = <<~STAT
      cpu  1000 200 500 8000 100 10 20 50 0 0
      cpu0 500 100 250 4000 50 5 10 25 0 0
      intr 123456
      ctxt 9876543
      processes 45678
      procs_running 5
      procs_blocked 1
    STAT
    File.write(File.join(procfs, "stat"), stat_content)

    vmstat_content = <<~VMSTAT
      nr_free_pages 1234
      pgfault 543210
      pgmajfault 1234
      pgpgin 8888
      pgpgout 9999
    VMSTAT
    File.write(File.join(procfs, "vmstat"), vmstat_content)

    counters = LinuxBenchHub::HardwareTelemetry::Counters.new(procfs_root: procfs, sysfs_root: @tmp_dir)
    cpu_stats = counters.read_cpu_stats
    vm_stats = counters.read_vm_stats

    assert_equal 1000, cpu_stats[:user]
    assert_equal 500, cpu_stats[:system]
    assert_equal 8000, cpu_stats[:idle]
    assert_equal 9876543, cpu_stats[:ctxt]
    assert_equal 45678, cpu_stats[:processes]
    assert_equal 5, cpu_stats[:procs_running]
    assert_equal 1, cpu_stats[:procs_blocked]

    assert_equal 543210, vm_stats[:pgfault]
    assert_equal 1234, vm_stats[:pgmajfault]
  end

  def test_counters_computes_deltas_and_utilization
    counters = LinuxBenchHub::HardwareTelemetry::Counters.new(procfs_root: @tmp_dir, sysfs_root: @tmp_dir)

    snap1 = LinuxBenchHub::HardwareTelemetry::Snapshot.new(
      cpu_stats: { user: 10_000, nice: 0, system: 2_000, idle: 80_000, iowait: 1_000, irq: 0, softirq: 0, steal: 0, ctxt: 1_000_000, processes: 5_000 },
      vm_stats: { pgfault: 100_000, pgmajfault: 500 },
      cpu_freq: { min_mhz: 3000.0, max_mhz: 3200.0, avg_mhz: 3100.0, governor: "performance" }
    )

    snap2 = LinuxBenchHub::HardwareTelemetry::Snapshot.new(
      cpu_stats: { user: 18_000, nice: 0, system: 3_000, idle: 81_000, iowait: 1_000, irq: 0, softirq: 0, steal: 0, ctxt: 1_025_000, processes: 5_050 },
      vm_stats: { pgfault: 105_000, pgmajfault: 510 },
      cpu_freq: { min_mhz: 3200.0, max_mhz: 3200.0, avg_mhz: 3200.0, governor: "performance" },
      perf_counters: { cycles: 2_000_000_000, instructions: 4_000_000_000, cache_misses: 20_000, cache_references: 500_000 }
    )

    delta = counters.compute_delta(snap1, snap2, 10.0)

    assert_equal 25_000, delta[:context_switches_total]
    assert_equal 2500.0, delta[:context_switches_per_sec]

    assert_equal 5_000, delta[:page_faults_total]
    assert_equal 500.0, delta[:page_faults_per_sec]

    assert_equal 10, delta[:maj_page_faults_total]
    assert_equal 1.0, delta[:maj_page_faults_per_sec]

    u = delta[:cpu_utilization]
    # user delta: 8000, system delta: 1000, idle delta: 1000 -> total 10000 ticks
    assert_equal 80.0, u[:user_pct]
    assert_equal 10.0, u[:system_pct]
    assert_equal 10.0, u[:idle_pct]

    perf = delta[:perf_counters]
    assert_equal 2.0, perf[:ipc]
    assert_equal 4.0, perf[:cache_miss_rate_pct]
  end

  # ==========================================
  # Sampler & Background Thread Tests
  # ==========================================

  def test_sampler_background_execution_and_clean_stop
    mock_collector = Class.new do
      attr_reader :call_count
      def initialize
        @call_count = 0
      end
      def capture_sample(index: nil, elapsed: nil)
        @call_count += 1
        { sample_index: index, elapsed_seconds: elapsed, temp_c: 50.0 + index }
      end
    end.new

    sampler = LinuxBenchHub::HardwareTelemetry::Sampler.new(mock_collector, interval: 0.1)
    refute sampler.running?

    sampler.start
    assert sampler.running?
    sleep 0.35

    samples = sampler.stop
    refute sampler.running?
    assert_operator samples.size, :>=, 2
    assert_operator mock_collector.call_count, :>=, 2
    assert_equal 1, samples.first[:sample_index]
  end

  # ==========================================
  # SimulatedProvider Tests
  # ==========================================

  def test_simulated_provider_nominal_report
    provider = LinuxBenchHub::HardwareTelemetry::SimulatedProvider.new(simulate_throttling: false)
    report = provider.generate_report(duration: 5.0, sample_count: 5)

    assert report.deterministic?
    refute report.throttling_detected?
    assert_empty report.determinism_notes
    assert_equal 0, report.thermal[:package_throttle_delta]
    assert_equal 0, report.thermal[:core_throttle_delta]
    assert_equal 42.5, report.thermal[:initial_celsius]
    assert_equal 68.4, report.thermal[:peak_celsius]
    assert_in_delta 31.6, report.thermal[:headroom_celsius], 0.1
    assert_equal 3200.0, report.counters[:frequency_mhz][:avg_mhz]
    assert_equal 5, report.samples.size
    assert_includes report.summary_markdown, "NO THROTTLING OBSERVED"
  end

  def test_simulated_provider_throttled_report
    provider = LinuxBenchHub::HardwareTelemetry::SimulatedProvider.new(simulate_throttling: true)
    report = provider.generate_report(duration: 5.0, sample_count: 5)

    refute report.deterministic?
    assert report.throttling_detected?
    assert_operator report.determinism_notes.size, :>=, 2
    assert_equal 14, report.thermal[:package_throttle_delta]
    assert_equal 8, report.thermal[:core_throttle_delta]
    assert_equal 101.5, report.thermal[:peak_celsius]
    assert_equal 0.0, report.thermal[:headroom_celsius]
    assert_equal 1400.0, report.counters[:frequency_mhz][:min_mhz]
    assert_includes report.summary_markdown, "THROTTLING OBSERVED"
    assert_includes report.summary_markdown, "THROTTLING OBSERVED"
  end

  # ==========================================
  # Collector Lifecycle & Determinism Rules
  # ==========================================

  def test_collector_monitor_block_execution
    res, report = LinuxBenchHub::HardwareTelemetry::Collector.monitor(
      mode: :simulated,
      interval: 0.1
    ) do
      sleep 0.1
      "telemetry-test-result"
    end

    assert_equal "telemetry-test-result", res
    assert_instance_of LinuxBenchHub::HardwareTelemetry::Report, report
    assert report.deterministic?
    assert_operator report.duration_seconds, :>=, 0.05
  end

  # ==========================================
  # Workload Dispatcher & Manifest Integration
  # ==========================================

  def test_dispatcher_records_hardware_telemetry_artifacts
    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.standard(
      output_dir: @tmp_dir,
      telemetry: true,
      telemetry_interval: 0.1
    )
    target = LinuxBenchHub::WorkloadDispatch::SimulatedTarget.new
    dispatcher = LinuxBenchHub::WorkloadDispatch::Dispatcher.new

    result = dispatcher.dispatch(pipeline, target, run_id: "telemetry-dispatch-test")
    assert result.success?
    assert result.deterministic?
    refute result.throttling_detected?

    # Verify telemetry artifact path exists
    assert File.file?(result.telemetry_path)
    assert_equal result.telemetry_path, result.manifest.artifacts[:telemetry_json]

    # Verify JSON content
    telemetry_json = File.read(result.telemetry_path)
    parsed = JSON.parse(telemetry_json, symbolize_names: true)
    assert parsed[:deterministic]
    assert_equal 0, parsed[:thermal][:package_throttle_delta]

    # Verify manifest reflects telemetry
    manifest = result.manifest
    assert manifest.deterministic?
    refute manifest.throttling_detected?
    assert manifest.hardware_telemetry.is_a?(Hash)
    assert_equal 68.4, manifest.hardware_telemetry.dig(:thermal, :peak_celsius)

    # Verify summary markdown renders telemetry
    summary = File.read(result.manifest_path.sub("manifest.json", "summary.md"))
    assert_includes summary, "Deterministic Hardware Telemetry & Thermal Monitoring"
    assert_includes summary, "NO THROTTLING OBSERVED"
    assert_includes summary, "Context Switches"
  end

  def test_dispatcher_catches_simulated_throttling_in_manifest
    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.standard(
      output_dir: @tmp_dir,
      telemetry: true,
      telemetry_interval: 0.1,
      telemetry_options: { simulate_throttling: true }
    )
    target = LinuxBenchHub::WorkloadDispatch::SimulatedTarget.new
    dispatcher = LinuxBenchHub::WorkloadDispatch::Dispatcher.new

    result = dispatcher.dispatch(pipeline, target, run_id: "throttled-dispatch-test")
    assert result.success?
    refute result.deterministic?, "Expected run to be flagged non-deterministic due to throttling"
    assert result.throttling_detected?

    manifest = result.manifest
    refute manifest.deterministic?
    assert manifest.throttling_detected?
    assert_equal 14, manifest.hardware_telemetry.dig(:thermal, :package_throttle_delta)

    # Summary markdown should flag non-determinism
    summary_md = manifest.summary_markdown
    assert_includes summary_md, "THROTTLING OBSERVED"
    assert_includes summary_md, "Thermal throttling detected"
  end

  def test_dispatcher_allows_disabling_telemetry
    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.standard(
      output_dir: @tmp_dir,
      telemetry: false
    )
    target = LinuxBenchHub::WorkloadDispatch::SimulatedTarget.new
    dispatcher = LinuxBenchHub::WorkloadDispatch::Dispatcher.new

    result = dispatcher.dispatch(pipeline, target, run_id: "no-telemetry-dispatch")
    assert result.success?
    assert_nil result.telemetry_path
    assert_nil result.manifest.hardware_telemetry
    refute File.file?(File.join(result.output_dir, "telemetry.json"))
  end

  # ==========================================
  # Standalone CLI Tests
  # ==========================================

  def test_lbh_telemetry_cli_check_and_json
    cli = File.expand_path("bin/lbh-telemetry", __dir__)

    # Default check
    stdout, stderr, status = Open3.capture3(cli, "--check")
    assert status.success?, "CLI check failed: #{stderr}"
    assert_includes stdout, "Hardware Telemetry Snapshot"
    assert_includes stdout, "Kernel Performance Counters"

    # JSON format
    stdout, stderr, status = Open3.capture3(cli, "--check", "--json")
    assert status.success?, "CLI check --json failed: #{stderr}"
    parsed = JSON.parse(stdout, symbolize_names: true)
    assert parsed.key?(:cpu_stats)
    assert parsed.key?(:thermal)
  end

  def test_lbh_telemetry_cli_monitor_and_exec
    cli = File.expand_path("bin/lbh-telemetry", __dir__)
    out_file = File.join(@tmp_dir, "mon_out.json")

    # Monitor simulated
    stdout, stderr, status = Open3.capture3(cli, "--simulate", "--monitor", "0.2", "--interval", "0.1", "--json", "--output", out_file)
    assert status.success?, "CLI monitor failed: #{stderr}"
    assert File.file?(out_file)

    parsed = JSON.parse(File.read(out_file), symbolize_names: true)
    assert parsed[:deterministic]
    assert_equal 68.4, parsed[:thermal][:peak_celsius]

    # Exec wrapper
    stdout, stderr, status = Open3.capture3(cli, "--simulate", "--exec", "echo test-run")
    assert status.success?, "CLI exec failed: #{stderr}"
    assert_includes stdout, "Deterministic: YES"
    assert_includes stdout, "Hardware Telemetry & Thermal Monitoring"
  end

  def test_lbh_dispatch_cli_telemetry_flags
    cli = File.expand_path("bin/lbh-dispatch", __dir__)

    # Telemetry check flag
    stdout, stderr, status = Open3.capture3(cli, "--telemetry-check")
    assert status.success?, "CLI --telemetry-check failed: #{stderr}"
    assert_includes stdout, "LinuxBenchHub Hardware Telemetry Preflight Check"
    assert_includes stdout, "Thermal Monitoring"

    # Simulate with throttle
    stdout, stderr, status = Open3.capture3(cli, "--simulate", "--simulate-throttle", "--output", @tmp_dir)
    assert status.success?, "CLI simulate throttle failed: #{stderr}"
    assert_includes stdout, "THROTTLING OBSERVED"
    assert_includes stdout, "Thermal throttling detected"
  end
end
