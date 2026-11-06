# frozen_string_literal: true

# Standalone CLI and programmatic interface for automated workload dispatch.
# Provides reproducible benchmark pipelines for CPU, memory bandwidth, and disk I/O.

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "fileutils"
require "json"
require "open3"
require "timeout"
require "linux_bench_hub/workload_dispatch"

# Backward-compatible helper methods for ad-hoc benchmark runners

def ensure_packages_installed(packages = %w[build-essential php-cli php-xml libaio-dev])
  packages.each do |pkg|
    result, _, _ = Open3.capture3("dpkg -l #{pkg}") rescue ["", nil, nil]
    if result.empty? || !result.include?("ii")
      puts "Notice: Package '#{pkg}' not registered in local dpkg database."
    end
  end
end

def test_installed?(test_name)
  stdout, _, status = Open3.capture3("phoronix-test-suite", "list-installed-tests") rescue ["", nil, nil]
  return false unless status&.success?

  stdout.include?(test_name)
end

def install_test(test_name)
  puts "Installing benchmark test: #{test_name}..."
  stdout, stderr, status = Open3.capture3("phoronix-test-suite", "install", test_name)
  unless status.success?
    warn "Failed to install #{test_name}: #{stderr}"
  end
  status.success?
end

def run_benchmark(workloads: %i[cpu memory disk_io], target: :local, output_dir: "captures",
                  run_id: nil, telemetry: true, telemetry_options: {})
  puts "Dispatching automated workload pipeline: #{workloads.join(', ')} (target: #{target})..."
  result = LinuxBenchHub::WorkloadDispatch.dispatch(
    workloads: workloads,
    target: target,
    output_dir: output_dir,
    run_id: run_id,
    telemetry: telemetry,
    telemetry_options: telemetry_options,
    logger: $stdout
  )
  puts "Workload dispatch finished with status: #{result.success? ? 'SUCCESS' : 'FAILED'}"
  result
end

# Main entry point for CLI execution
if __FILE__ == $PROGRAM_NAME
  target_arg = ARGV.include?("--simulate") || ARGV.include?("-s") ? :simulated : :local
  workloads_arg = %i[cpu memory disk_io]

  if (w_idx = ARGV.index("--workloads") || ARGV.index("-w"))
    workloads_str = ARGV[w_idx + 1]
    workloads_arg = workloads_str.split(",").map(&:strip).map(&:to_sym) if workloads_str
  end

  out_dir = "captures"
  if (o_idx = ARGV.index("--output") || ARGV.index("-o"))
    out_dir = ARGV[o_idx + 1] if ARGV[o_idx + 1]
  end

  result = run_benchmark(
    workloads: workloads_arg,
    target: target_arg,
    output_dir: out_dir
  )

  exit(result.success? ? 0 : 1)
end
