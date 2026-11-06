# frozen_string_literal: true

require "time"
require_relative "snapshot"
require_relative "thermal_monitor"
require_relative "counters"
require_relative "sampler"
require_relative "report"
require_relative "simulated_provider"
require_relative "perf_counters"

module LinuxBenchHub
  module HardwareTelemetry
    # Host-wide observations around a benchmark, using monotonic elapsed time.
    class Collector
      attr_reader :mode, :interval, :procfs_root, :sysfs_root,
                  :initial_snapshot, :final_snapshot, :sampler

      def initialize(mode: :auto, interval: 1.0, procfs_root: "/proc", sysfs_root: "/sys",
                     simulate_throttling: false, logger: nil, perf: true, perf_executable: "perf")
        @mode = mode.to_sym
        raise ArgumentError, "Unknown telemetry mode: #{@mode}" unless [:auto, :native, :simulated, :unavailable].include?(@mode)

        @interval = Float(interval)
        unless @interval.finite? && (@interval.zero? || @interval >= 0.1)
          raise ArgumentError, "interval must be zero or finite and at least 0.1s"
        end
        @procfs_root = procfs_root.to_s
        @sysfs_root = sysfs_root.to_s
        @logger = logger
        @thermal_monitor = ThermalMonitor.new(sysfs_root: @sysfs_root)
        @counters = Counters.new(procfs_root: @procfs_root, sysfs_root: @sysfs_root)
        @simulated_provider = SimulatedProvider.new(simulate_throttling: simulate_throttling)
        @perf = PerfCounters.new(executable: perf_executable) if perf && ![:simulated, :unavailable].include?(@mode)
      end

      def start
        raise ArgumentError, "Telemetry session already started" if @started_at

        @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @initial_snapshot = take_snapshot
        @peak_temp = @initial_snapshot.thermal[:max_temp_c]
        @last_thermal = @initial_snapshot.thermal
        @observed_throttling = false
        @perf&.start
        if @interval.positive? && ![:simulated, :unavailable].include?(@mode)
          @sampler = Sampler.new(self, interval: @interval)
          @sampler.start
        end
        self
      end

      def take_snapshot
        return @simulated_provider.generate_snapshot if @mode == :simulated
        return Snapshot.new if @mode == :unavailable

        state = @counters.read_state
        Snapshot.new(cpu_stats: state[:cpu_stats], vm_stats: state[:vm_stats],
                     cpu_freq: state[:cpu_freq], thermal: @thermal_monitor.read_state)
      end

      def capture_sample(index: nil, elapsed: 0.0)
        thermal = @thermal_monitor.read_state
        peak = thermal[:max_temp_c]
        @peak_temp = [@peak_temp, peak].compact.max
        delta = @thermal_monitor.compute_delta(@last_thermal, thermal)
        @observed_throttling ||= delta[:throttling_detected]
        @last_thermal = thermal
        freq = @counters.read_cpu_freq
        {
          sample_index: index, elapsed_seconds: elapsed.round(3), temp_c: peak,
          avg_freq_mhz: freq[:avg_mhz], thermal_state: thermal
        }
      end

      def stop
        return @report if @report
        raise ArgumentError, "Telemetry session has not started" unless @started_at

        samples = @sampler ? @sampler.stop : []
        pmu = @perf&.stop
        @final_snapshot = take_snapshot
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
        if @mode == :simulated
          @report = @simulated_provider.generate_report(duration: duration, sample_count: 0)
          return @report
        end

        thermal = @thermal_monitor.compute_delta(@initial_snapshot.thermal, @final_snapshot.thermal, samples)
        thermal[:peak_celsius] = [thermal[:peak_celsius], @peak_temp].compact.max
        thermal[:throttling_detected] ||= @observed_throttling
        if thermal[:peak_celsius] && thermal[:critical_temp_celsius]
          thermal[:headroom_celsius] = thermal[:critical_temp_celsius] - thermal[:peak_celsius]
        end
        counters = if @initial_snapshot.cpu_stats.empty? || @final_snapshot.cpu_stats.empty?
                     {}
                   else
                     @counters.compute_delta(@initial_snapshot, @final_snapshot, duration)
                   end
        counters[:perf_counters] = pmu if pmu
        notes = []
        notes << "Thermal throttling observed during this run" if thermal[:throttling_detected]
        notes << "Throttle counters unavailable, reset, or changed during this run" unless thermal[:throttling_available]
        notes << "Kernel counters unavailable" if counters.empty? || !counters.key?(:cpu_utilization)
        notes << "Remote target telemetry requires collection on the target host" if @mode == :unavailable
        deterministic = if thermal[:throttling_detected]
                          false
                        elsif thermal[:throttling_available] && counters.key?(:cpu_utilization)
                          true
                        end
        @report = Report.new(duration_seconds: duration, sample_count: samples.size,
                             deterministic: deterministic, throttling_detected: thermal[:throttling_detected],
                             determinism_notes: notes, thermal: thermal, counters: counters,
                             samples: samples, source: @mode == :unavailable ? "unavailable" : "native")
      end

      def self.monitor(**options)
        collector = new(**options)
        collector.start
        begin
          result = yield(collector)
        ensure
          report = collector.stop
        end
        [result, report]
      end
    end
  end
end
