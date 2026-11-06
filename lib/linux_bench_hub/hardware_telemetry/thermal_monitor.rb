# frozen_string_literal: true

require "pathname"

module LinuxBenchHub
  module HardwareTelemetry
    # Reads thermal zones and lifetime throttle counters without privileged writes.
    class ThermalMonitor
      DEFAULT_SYSFS_ROOT = "/sys"
      METRICS = {
        package_throttle_count: "package_throttle_count",
        core_throttle_count: "core_throttle_count",
        package_throttle_time_ms: "package_throttle_total_time_ms",
        core_throttle_time_ms: "core_throttle_total_time_ms"
      }.freeze

      attr_reader :sysfs_root

      def initialize(sysfs_root: DEFAULT_SYSFS_ROOT)
        @sysfs_root = Pathname.new(sysfs_root)
      end

      def read_state
        zones = read_thermal_zones
        temps = zones.filter_map { |zone| zone[:temp_c] }
        read_throttle_counters.merge(
          zones: zones,
          mean_temp_c: temps.empty? ? nil : (temps.sum / temps.size).round(2),
          max_temp_c: temps.max
        )
      end

      def read_thermal_zones
        Dir.glob(@sysfs_root.join("class/thermal/thermal_zone*").to_s).sort.map do |path|
          dir = Pathname.new(path)
          temp = read_integer(dir.join("temp"))
          trips = Dir.glob(dir.join("trip_point_*_temp").to_s).sort.filter_map do |trip|
            idx = File.basename(trip)[/trip_point_(\d+)_temp/, 1]
            value = read_integer(Pathname.new(trip))
            next unless value

            { index: idx.to_i, type: read_file(dir.join("trip_point_#{idx}_type")), temp_c: value / 1000.0 }
          end
          { id: dir.basename.to_s, type: read_file(dir.join("type")) || dir.basename.to_s,
            temp_c: temp ? temp / 1000.0 : nil, trip_points: trips }
        end
      end

      def read_throttle_counters
        readings = METRICS.to_h { |key, _| [ key, {} ] }
        Dir.glob(@sysfs_root.join("devices/system/cpu/cpu[0-9]*").to_s).sort.each do |path|
          dir = Pathname.new(path)
          package = read_file(dir.join("topology/physical_package_id"))
          METRICS.each do |key, filename|
            value = read_integer(dir.join("thermal_throttle", filename))
            next unless value && value >= 0

            # Keep per-CPU baselines: CPUs can come and go during a run. Package
            # counters are broadcast, so aggregate their deltas by package below.
            readings[key][dir.basename.to_s] = { value: value, package: package }
          end
        end
        readings.to_h do |key, values|
          [ key, aggregate(values, key) ]
        end.merge(throttle_readings: readings)
      end

      def compute_delta(initial_state, final_state, samples = [])
        states = [ initial_state ] + samples.filter_map { |sample| sample[:thermal_state] } + [ final_state ]
        deltas = METRICS.to_h do |key, _|
          baseline = initial_state.dig(:throttle_readings, key) || {}
          totals = {}
          previous = baseline
          states.drop(1).each do |state|
            next unless state.key?(:throttle_readings)

            current = state.dig(:throttle_readings, key)
            next unless current && !current.empty?

            current.each do |cpu, entry|
              old = previous[cpu]
              next unless old && old[:package] == entry[:package] && entry[:value] >= old[:value]

              totals[cpu] ||= { value: 0, package: entry[:package] }
              totals[cpu][:value] += entry[:value] - old[:value]
            end
            previous = current
          end
          [ key, aggregate(totals, key) ]
        end
        supported = [ :package_throttle_count, :core_throttle_count ].any? do |key|
          initial = initial_state.dig(:throttle_readings, key) || {}
          final = final_state.dig(:throttle_readings, key) || {}
          readings = states.select { |state| state.key?(:throttle_readings) }.map { |state| state.dig(:throttle_readings, key) || {} }
          !initial.empty? && initial.keys.sort == final.keys.sort && readings.each_cons(2).all? do |before, after|
            before.keys.sort == after.keys.sort && before.all? do |cpu, entry|
              last = after[cpu]
              last[:package] == entry[:package] && last[:value] >= entry[:value]
            end
          end
        end
        temps = states.filter_map { |state| state[:max_temp_c] }
        peak = temps.max
        critical = final_state.fetch(:zones, []).flat_map { |zone| zone[:trip_points] }.filter_map do |trip|
          trip[:temp_c] if trip[:type] == "critical"
        end.min
        {
          throttling_available: supported,
          throttling_detected: deltas.values.compact.any?(&:positive?),
          package_throttle_delta: deltas[:package_throttle_count],
          core_throttle_delta: deltas[:core_throttle_count],
          package_throttle_time_ms_delta: deltas[:package_throttle_time_ms],
          core_throttle_time_ms_delta: deltas[:core_throttle_time_ms],
          initial_celsius: initial_state[:max_temp_c], final_celsius: final_state[:max_temp_c],
          peak_celsius: peak, min_celsius: temps.min,
          mean_celsius: temps.empty? ? nil : (temps.sum / temps.size).round(2),
          critical_temp_celsius: critical,
          headroom_celsius: peak && critical ? (critical - peak).round(2) : nil,
          zones: final_state[:zones] || []
        }
      end

      private

      def aggregate(values, key)
        return nil if values.empty?
        return values.values.sum { |entry| entry[:value] } unless key.to_s.start_with?("package")

        values.group_by { |cpu, entry| entry[:package] || cpu }.values.sum do |entries|
          entries.map { |_, entry| entry[:value] }.max
        end
      end

      def read_file(path)
        File.read(path).strip
      rescue SystemCallError, IOError
        nil
      end

      def read_integer(path)
        Integer(read_file(path), 10)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
