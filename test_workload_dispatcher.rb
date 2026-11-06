# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "lib/linux_bench_hub/workload_dispatch"
require_relative "linux_benchmarking"

class WorkloadDispatcherTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir("lbh_test_")
    LinuxBenchHub::WorkloadDispatch::Workload.reset_registry!
  end

  def teardown
    LinuxBenchHub::WorkloadDispatch::Workload.reset_registry!
    FileUtils.remove_entry(@tmp_dir) if File.directory?(@tmp_dir)
  end

  # ==========================================
  # Workload Tests
  # ==========================================

  def test_standard_workloads_registered
    workloads = LinuxBenchHub::WorkloadDispatch::Workload.all
    assert_operator workloads.size, :>=, 3

    categories = workloads.map(&:category)
    assert_includes categories, :cpu
    assert_includes categories, :memory
    assert_includes categories, :disk_io
  end

  def test_cpu_workload_specification
    cpu = LinuxBenchHub::WorkloadDispatch::Workload::CPU
    assert_equal "cpu-c-ray", cpu.id
    assert_equal :cpu, cpu.category
    assert_equal "pts/c-ray-2.0.0", cpu.test_identifier
    assert cpu.lower_is_better?
    assert_equal "Seconds", cpu.unit
    assert_equal ["1", "16"], cpu.interactive_answers
  end

  def test_memory_workload_specification
    mem = LinuxBenchHub::WorkloadDispatch::Workload::MEMORY
    assert_equal "memory-tinymembench", mem.id
    assert_equal :memory, mem.category
    assert_equal "pts/tinymembench-1.0.2", mem.test_identifier
    refute mem.lower_is_better?
    assert_equal "MB/s", mem.unit
  end

  def test_disk_io_workload_specification
    disk = LinuxBenchHub::WorkloadDispatch::Workload::DISK_IO
    assert_equal "disk-fio", disk.id
    assert_equal :disk_io, disk.category
    assert_equal "pts/fio-2.1.0", disk.test_identifier
    refute disk.lower_is_better?
    assert_equal "MB/s", disk.unit
    assert_equal ["1", "1", "1", "1"], disk.interactive_answers
  end

  def test_workload_lookup_and_registration
    assert_equal LinuxBenchHub::WorkloadDispatch::Workload::CPU,
                 LinuxBenchHub::WorkloadDispatch::Workload.find("cpu")
    assert_equal LinuxBenchHub::WorkloadDispatch::Workload::MEMORY,
                 LinuxBenchHub::WorkloadDispatch::Workload.find(:memory)
    assert_equal LinuxBenchHub::WorkloadDispatch::Workload::DISK_IO,
                 LinuxBenchHub::WorkloadDispatch::Workload.find("pts/fio-2.1.0")

    custom = LinuxBenchHub::WorkloadDispatch::Workload.new(
      id: "custom-cpu",
      name: "Custom CPU",
      category: :cpu,
      test_identifier: "pts/custom-cpu",
      description: "Custom compute test",
      unit: "Seconds",
      lower_is_better: true
    )
    LinuxBenchHub::WorkloadDispatch::Workload.register(custom)
    assert_equal custom, LinuxBenchHub::WorkloadDispatch::Workload.find("custom-cpu")
  end

  def test_workload_invalid_category_raises
    assert_raises(ArgumentError) do
      LinuxBenchHub::WorkloadDispatch::Workload.new(
        id: "invalid-workload",
        name: "Invalid",
        category: :unsupported,
        test_identifier: "pts/invalid",
        description: "Invalid",
        unit: "Score"
      )
    end
  end

  # ==========================================
  # Pipeline Tests
  # ==========================================

  def test_standard_pipeline_creation
    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.standard(output_dir: @tmp_dir)
    assert pipeline.covers_three_tiers?
    assert_equal %i[cpu memory disk_io], pipeline.categories
    assert_equal ["pts/c-ray-2.0.0", "pts/tinymembench-1.0.2", "pts/fio-2.1.0"], pipeline.pts_arguments
    assert_includes pipeline.batch_input_string, "1\n16\n"
  end

  def test_pipeline_validation
    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.new(workloads: [LinuxBenchHub::WorkloadDispatch::Workload::CPU])
    assert pipeline.validate!
    refute pipeline.covers_three_tiers?

    empty_pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.new(workloads: [])
    assert_raises(ArgumentError) { empty_pipeline.validate! }
  end

  # ==========================================
  # Target Tests
  # ==========================================

  def test_docker_target_configuration
    ubuntu_target = LinuxBenchHub::WorkloadDispatch::DockerTarget.new(distro: "ubuntu")
    assert_equal "ubuntu:26.04", ubuntu_target.image
    assert_equal :docker, ubuntu_target.target_type

    fedora_target = LinuxBenchHub::WorkloadDispatch::DockerTarget.new(distro: "fedora")
    assert_equal "fedora:44", fedora_target.image

    debian_target = LinuxBenchHub::WorkloadDispatch::DockerTarget.new(distro: "debian")
    assert_equal "debian:13", debian_target.image

    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.standard
    cmd = ubuntu_target.build_docker_command(pipeline, { run_id: "test-run" }, "/tmp/out")
    assert_includes cmd, "docker"
    assert_includes cmd, "ubuntu:26.04"
    assert_includes cmd, "/tmp/out:/output"
  end

  def test_ssh_target_command_building
    ssh_target = LinuxBenchHub::WorkloadDispatch::SshTarget.new(
      host: "192.168.1.100",
      user: "testuser",
      port: 2222,
      key_path: "/tmp/id_rsa"
    )
    assert_equal :ssh, ssh_target.target_type

    cmd = ssh_target.build_ssh_command("echo hello")
    assert_equal ["ssh", "-p", "2222", "-i", "/tmp/id_rsa", "testuser@192.168.1.100", "echo hello"], cmd
  end

  def test_simulated_target_execution
    sim = LinuxBenchHub::WorkloadDispatch::SimulatedTarget.new
    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.standard(output_dir: @tmp_dir)

    result = sim.execute(pipeline, { run_id: "sim-test-run" })
    assert result.success?
    assert_includes result.composite_xml, "<PhoronixTestSuite>"
    assert_includes result.composite_xml, "pts/c-ray-2.0.0"
    assert_includes result.composite_xml, "pts/tinymembench-1.0.2"
    assert_includes result.composite_xml, "pts/fio-2.1.0"
  end

  # ==========================================
  # Dispatcher & Manifest Tests
  # ==========================================

  def test_full_simulated_dispatch
    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.standard(output_dir: @tmp_dir)
    target = LinuxBenchHub::WorkloadDispatch::SimulatedTarget.new
    dispatcher = LinuxBenchHub::WorkloadDispatch::Dispatcher.new

    result = dispatcher.dispatch(pipeline, target, run_id: "test-sim-dispatch")
    assert result.success?
    assert File.file?(result.composite_xml_path)
    assert File.file?(result.manifest_path)

    manifest = result.manifest
    assert_equal :success, manifest.status
    assert_equal "test-sim-dispatch", manifest.run_id
    assert_equal :simulated, manifest.target_type
    assert_equal 3, manifest.workloads.size

    cpu_w = manifest.workloads.find { |w| w[:category] == :cpu }
    assert_equal "passed", cpu_w[:status].to_s
    assert_operator cpu_w[:mean], :>, 0

    mem_w = manifest.workloads.find { |w| w[:category] == :memory }
    assert_equal "passed", mem_w[:status].to_s
    assert_operator mem_w[:mean], :>, 0

    disk_w = manifest.workloads.find { |w| w[:category] == :disk_io }
    assert_equal "passed", disk_w[:status].to_s
    assert_operator disk_w[:mean], :>, 0

    assert_includes manifest.summary_markdown, "Workload Dispatch Run: test-sim-dispatch"
    assert_includes manifest.summary_markdown, "Flexible I/O Tester"
  end

  def test_manifest_json_roundtrip
    manifest = LinuxBenchHub::WorkloadDispatch::Manifest.new(
      run_id: "roundtrip-test",
      pipeline_name: "Roundtrip",
      target_type: :local,
      distro: "Ubuntu 26.04",
      architecture: "x86_64",
      kernel: "6.17.0",
      status: :success,
      workloads: [{ category: :cpu, name: "C-Ray", mean: 120.5 }]
    )

    json_str = manifest.to_json
    loaded = LinuxBenchHub::WorkloadDispatch::Manifest.from_json(json_str)

    assert_equal manifest.run_id, loaded.run_id
    assert_equal manifest.status, loaded.status
    assert_equal manifest.distro, loaded.distro
    assert_equal manifest.architecture, loaded.architecture
  end

  def test_dispatcher_handles_preflight_failure
    failing_target = Class.new(LinuxBenchHub::WorkloadDispatch::BaseTarget) do
      def preflight_check(_pipeline)
        LinuxBenchHub::WorkloadDispatch::PreflightResult.new(
          ok: false,
          errors: ["Missing essential benchmark binary"],
          warnings: []
        )
      end
    end.new

    pipeline = LinuxBenchHub::WorkloadDispatch::Pipeline.standard(output_dir: @tmp_dir)
    dispatcher = LinuxBenchHub::WorkloadDispatch::Dispatcher.new

    result = dispatcher.dispatch(pipeline, failing_target, run_id: "preflight-fail")
    refute result.success?
    assert_equal :failed, result.manifest.status
    assert_includes result.manifest.errors, "Missing essential benchmark binary"
    assert File.file?(result.manifest_path)
  end

  # ==========================================
  # Module Convenience & CLI Tests
  # ==========================================

  def test_module_dispatch_convenience
    result = LinuxBenchHub::WorkloadDispatch.dispatch(
      workloads: %i[cpu memory disk_io],
      target: :simulated,
      output_dir: @tmp_dir
    )
    assert result.success?
    assert result.manifest.success?
  end

  def test_linux_benchmarking_standalone_helpers
    result = run_benchmark(
      workloads: %i[cpu memory disk_io],
      target: :simulated,
      output_dir: @tmp_dir
    )
    assert result.success?
  end

  def test_cli_execution
    cli_path = File.expand_path("bin/lbh-dispatch", __dir__)

    # Test --list
    stdout, stderr, status = Open3.capture3(cli_path, "--list")
    assert status.success?, "CLI --list failed: #{stderr}"
    assert_includes stdout, "Available LinuxBenchHub Benchmark Workloads"
    assert_includes stdout, "Flexible I/O Tester"

    # Test --simulate
    stdout, stderr, status = Open3.capture3(cli_path, "--simulate", "--output", @tmp_dir)
    assert status.success?, "CLI --simulate failed: #{stderr}"
    assert_includes stdout, "Status: SUCCESS"
    assert_includes stdout, "Standard Three-Tier Pipeline"
  end
end
