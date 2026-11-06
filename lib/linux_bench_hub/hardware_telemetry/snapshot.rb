# frozen_string_literal: true

require "time"

module LinuxBenchHub
  module HardwareTelemetry
    # Point-in-time snapshot of system hardware counters, CPU frequencies,
    # and thermal throttling registers.
    class Snapshot
      attr_reader :timestamp, :monotonic_time, :cpu_stats, :vm_stats,
                  :cpu_freq, :thermal, :perf_counters

      def initialize(timestamp: Time.now.utc,
                     monotonic_time: Process.clock_gettime(Process::CLOCK_MONOTONIC),
                     cpu_stats: {},
                     vm_stats: {},
                     cpu_freq: {},
                     thermal: {},
                     perf_counters: {})
        @timestamp = timestamp.is_a?(String) ? Time.parse(timestamp).utc : timestamp.utc
        @monotonic_time = monotonic_time.to_f
        @cpu_stats = (cpu_stats || {}).transform_keys(&:to_sym)
        @vm_stats = (vm_stats || {}).transform_keys(&:to_sym)
        @cpu_freq = (cpu_freq || {}).transform_keys(&:to_sym)
        @thermal = (thermal || {}).transform_keys(&:to_sym)
        @perf_counters = (perf_counters || {}).transform_keys(&:to_sym)
      end

      def to_h
        {
          timestamp: @timestamp.iso8601(3),
          monotonic_time: @monotonic_time,
          cpu_stats: @cpu_stats,
          vm_stats: @vm_stats,
          cpu_freq: @cpu_freq,
          thermal: @thermal,
          perf_counters: @perf_counters
        }
      end

      def self.from_h(hash)
        new(
          timestamp: hash[:timestamp] || hash["timestamp"],
          monotonic_time: hash[:monotonic_time] || hash["monotonic_time"],
          cpu_stats: hash[:cpu_stats] || hash["cpu_stats"],
          vm_stats: hash[:vm_stats] || hash["vm_stats"],
          cpu_freq: hash[:cpu_freq] || hash["cpu_freq"],
          thermal: hash[:thermal] || hash["thermal"],
          perf_counters: hash[:perf_counters] || hash["perf_counters"]
        )
      end
    end
  end
end
