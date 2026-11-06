# frozen_string_literal: true

require_relative "hardware_telemetry/snapshot"
require_relative "hardware_telemetry/thermal_monitor"
require_relative "hardware_telemetry/counters"
require_relative "hardware_telemetry/sampler"
require_relative "hardware_telemetry/report"
require_relative "hardware_telemetry/simulated_provider"
require_relative "hardware_telemetry/collector"

module LinuxBenchHub
  # Deterministic Hardware Telemetry module providing low-overhead hardware counters
  # and thermal throttling monitoring during benchmark runs.
  module HardwareTelemetry
    class << self
      # Creates a new Collector instance configured with the specified options.
      def collector(**options)
        Collector.new(**options)
      end

      # Executes the given block wrapped in a hardware telemetry monitoring session.
      # Returns [block_result, report].
      def monitor(**options, &block)
        Collector.monitor(**options, &block)
      end

      # Captures an instantaneous Snapshot of system hardware and thermal counters.
      def snapshot(**options)
        Collector.new(**options).take_snapshot
      end

      # Reads the current thermal zones and throttling registers.
      def current_thermal_state(**options)
        ThermalMonitor.new(**options).read_state
      end

      # Reads current CPU and virtual memory performance counters.
      def current_counters(**options)
        Counters.new(**options).read_state
      end
    end
  end
end
