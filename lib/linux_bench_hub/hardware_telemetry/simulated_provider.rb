# frozen_string_literal: true

require_relative "snapshot"
require_relative "report"

module LinuxBenchHub
  module HardwareTelemetry
    # High-fidelity deterministic simulated telemetry provider for testing,
    # CI pipelines, and dry-run benchmarks.
    class SimulatedProvider
      attr_accessor :simulate_throttling

      def initialize(simulate_throttling: false)
        @simulate_throttling = !!simulate_throttling
      end

      # Generates a point-in-time Snapshot representing simulated system state.
      def generate_snapshot(phase: :initial, duration: 10.0, timestamp: nil, monotonic_time: nil)
        ts = timestamp || Time.now.utc
        mono = monotonic_time || Process.clock_gettime(Process::CLOCK_MONOTONIC)

        if phase == :initial
          build_initial_snapshot(ts, mono)
        else
          build_final_snapshot(ts, mono, duration)
        end
      end

      # Generates a complete Report for a simulated execution run.
      def generate_report(duration: 10.0, sample_count: 10)
        dur = [ duration.to_f, 0.1 ].max

        if @simulate_throttling
          build_throttled_report(dur, sample_count)
        else
          build_nominal_report(dur, sample_count)
        end
      end

      private

      def build_initial_snapshot(ts, mono)
        Snapshot.new(
          timestamp: ts,
          monotonic_time: mono,
          cpu_stats: {
            user: 500_000, nice: 100, system: 120_000, idle: 4_000_000,
            iowait: 15_000, irq: 2_000, softirq: 5_000, steal: 0,
            ctxt: 10_000_000, processes: 80_000, procs_running: 2, procs_blocked: 0
          },
          vm_stats: { pgfault: 2_500_000, pgmajfault: 4_500, pgpgin: 100_000, pgpgout: 200_000 },
          cpu_freq: {
            cores: [ 3200.0, 3200.0, 3200.0, 3200.0 ],
            min_mhz: 3200.0, max_mhz: 3200.0, avg_mhz: 3200.0, governor: "performance"
          },
          thermal: {
            zones: [ { id: "thermal_zone0", type: "x86_pkg_temp", temp_c: 42.5,
                      trip_points: [ { index: 0, type: "critical", temp_c: 100.0 } ] } ],
            package_throttle_count: 0,
            core_throttle_count: 0,
            package_throttle_time_ms: 0,
            core_throttle_time_ms: 0,
            mean_temp_c: 42.5,
            max_temp_c: 42.5
          },
          perf_counters: {
            cycles: 100_000_000,
            instructions: 220_000_000,
            cache_misses: 45_000,
            cache_references: 900_000
          }
        )
      end

      def build_final_snapshot(ts, mono, duration)
        dur_ticks = (duration * 100).to_i
        user_add = (dur_ticks * 0.91).to_i
        sys_add = (dur_ticks * 0.06).to_i
        idle_add = (dur_ticks * 0.02).to_i
        iowait_add = (dur_ticks * 0.01).to_i

        ctxt_add = (duration * 2450).to_i
        pgfault_add = (duration * 410).to_i

        if @simulate_throttling
          final_temp = 101.5
          pkg_throttle = 14
          core_throttle = 8
          pkg_time = 420
          core_time = 240
          cores = [ 1400.0, 1400.0, 1400.0, 1400.0 ]
        else
          final_temp = 68.4
          pkg_throttle = 0
          core_throttle = 0
          pkg_time = 0
          core_time = 0
          cores = [ 3200.0, 3200.0, 3200.0, 3200.0 ]
        end

        Snapshot.new(
          timestamp: ts,
          monotonic_time: mono + duration,
          cpu_stats: {
            user: 500_000 + user_add, nice: 100, system: 120_000 + sys_add,
            idle: 4_000_000 + idle_add, iowait: 15_000 + iowait_add,
            irq: 2_000, softirq: 5_000, steal: 0,
            ctxt: 10_000_000 + ctxt_add, processes: 80_000 + (duration * 5).to_i,
            procs_running: 4, procs_blocked: 0
          },
          vm_stats: {
            pgfault: 2_500_000 + pgfault_add, pgmajfault: 4_500 + (duration * 2).to_i,
            pgpgin: 100_000, pgpgout: 200_000
          },
          cpu_freq: {
            cores: cores,
            min_mhz: cores.min, max_mhz: cores.max, avg_mhz: (cores.sum / cores.size).round(1),
            governor: "performance"
          },
          thermal: {
            zones: [ { id: "thermal_zone0", type: "x86_pkg_temp", temp_c: final_temp,
                      trip_points: [ { index: 0, type: "critical", temp_c: 100.0 } ] } ],
            package_throttle_count: pkg_throttle,
            core_throttle_count: core_throttle,
            package_throttle_time_ms: pkg_time,
            core_throttle_time_ms: core_time,
            mean_temp_c: final_temp,
            max_temp_c: final_temp
          },
          perf_counters: {
            cycles: 100_000_000 + (duration * 3_200_000_000).to_i,
            instructions: 220_000_000 + (duration * 7_040_000_000).to_i,
            cache_misses: 45_000 + (duration * 12_000).to_i,
            cache_references: 900_000 + (duration * 240_000).to_i
          }
        )
      end

      def build_nominal_report(dur, sample_count)
        samples = generate_sample_series(dur, sample_count, 42.5, 68.4, 3200.0)

        Report.new(
          source: "simulated",
          duration_seconds: dur,
          sample_count: sample_count,
          deterministic: true,
          throttling_detected: false,
          determinism_notes: [],
          thermal: {
            throttling_detected: false,
            package_throttle_delta: 0,
            core_throttle_delta: 0,
            package_throttle_time_ms_delta: 0,
            core_throttle_time_ms_delta: 0,
            initial_celsius: 42.5,
            final_celsius: 67.2,
            peak_celsius: 68.4,
            min_celsius: 42.5,
            mean_celsius: 58.6,
            critical_temp_celsius: 100.0,
            headroom_celsius: 31.6,
            zones: [ { id: "thermal_zone0", type: "x86_pkg_temp", initial_celsius: 42.5, final_celsius: 67.2 } ]
          },
          counters: {
            context_switches_total: (dur * 2450).to_i,
            context_switches_per_sec: 2450.0,
            page_faults_total: (dur * 410).to_i,
            page_faults_per_sec: 410.0,
            maj_page_faults_total: (dur * 2).to_i,
            maj_page_faults_per_sec: 2.0,
            process_forks_total: (dur * 5).to_i,
            process_forks_per_sec: 5.0,
            cpu_utilization: {
              user_pct: 91.0,
              system_pct: 6.0,
              idle_pct: 2.0,
              iowait_pct: 1.0,
              steal_pct: 0.0
            },
            frequency_mhz: {
              min_mhz: 3200.0,
              max_mhz: 3200.0,
              avg_mhz: 3200.0,
              governor: "performance"
            },
            perf_counters: {
              cycles: (dur * 3_200_000_000).to_i,
              instructions: (dur * 7_040_000_000).to_i,
              ipc: 2.2,
              cache_misses: (dur * 12_000).to_i,
              cache_miss_rate_pct: 5.0,
              cycles_per_sec: 3_200_000_000,
              instructions_per_sec: 7_040_000_000
            }
          },
          samples: samples
        )
      end

      def build_throttled_report(dur, sample_count)
        samples = generate_sample_series(dur, sample_count, 55.0, 101.5, 1400.0)

        Report.new(
          source: "simulated",
          duration_seconds: dur,
          sample_count: sample_count,
          deterministic: false,
          throttling_detected: true,
          determinism_notes: [
            "Thermal throttling detected: 14 package events, 8 core events (420ms total)",
            "CPU core frequency throttled by 56.3% (3200.0 MHz down to 1400.0 MHz)"
          ],
          thermal: {
            throttling_detected: true,
            package_throttle_delta: 14,
            core_throttle_delta: 8,
            package_throttle_time_ms_delta: 420,
            core_throttle_time_ms_delta: 240,
            initial_celsius: 55.0,
            final_celsius: 99.8,
            peak_celsius: 101.5,
            min_celsius: 55.0,
            mean_celsius: 88.4,
            critical_temp_celsius: 100.0,
            headroom_celsius: 0.0,
            zones: [ { id: "thermal_zone0", type: "x86_pkg_temp", initial_celsius: 55.0, final_celsius: 99.8 } ]
          },
          counters: {
            context_switches_total: (dur * 1800).to_i,
            context_switches_per_sec: 1800.0,
            page_faults_total: (dur * 280).to_i,
            page_faults_per_sec: 280.0,
            maj_page_faults_total: (dur * 2).to_i,
            maj_page_faults_per_sec: 2.0,
            process_forks_total: (dur * 3).to_i,
            process_forks_per_sec: 3.0,
            cpu_utilization: {
              user_pct: 82.0,
              system_pct: 12.0,
              idle_pct: 4.0,
              iowait_pct: 2.0,
              steal_pct: 0.0
            },
            frequency_mhz: {
              min_mhz: 1400.0,
              max_mhz: 3200.0,
              avg_mhz: 1850.0,
              governor: "performance"
            },
            perf_counters: {
              cycles: (dur * 1_850_000_000).to_i,
              instructions: (dur * 2_775_000_000).to_i,
              ipc: 1.5,
              cache_misses: (dur * 18_000).to_i,
              cache_miss_rate_pct: 8.5,
              cycles_per_sec: 1_850_000_000,
              instructions_per_sec: 2_775_000_000
            }
          },
          samples: samples
        )
      end

      def generate_sample_series(duration, count, start_temp, peak_temp, target_freq)
        cnt = [ count.to_i, 0 ].max
        return [] if cnt.zero?
        interval = duration / cnt.to_f
        temp_step = (peak_temp - start_temp) / cnt.to_f

        (1..cnt).map do |i|
          elapsed = (i * interval).round(2)
          current_temp = (start_temp + (i * temp_step)).round(1)
          {
            sample_index: i,
            elapsed_seconds: elapsed,
            temp_c: current_temp,
            avg_freq_mhz: target_freq,
            ctxt_delta: (elapsed * 2400).to_i
          }
        end
      end
    end
  end
end
