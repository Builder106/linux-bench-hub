# frozen_string_literal: true

require "json"

module LinuxBenchHub
  module HardwareTelemetry
    # Aggregated hardware telemetry and thermal report produced for a benchmark run.
    class Report
      attr_reader :duration_seconds, :sample_count, :deterministic,
                  :throttling_detected, :determinism_notes, :thermal,
                  :counters, :samples, :source

      def initialize(duration_seconds: 0.0,
                     sample_count: 0,
                     deterministic: nil,
                     throttling_detected: false,
                     determinism_notes: [],
                     thermal: {},
                     counters: {},
                     samples: [], source: "native")
        @duration_seconds = duration_seconds.to_f.round(3)
        @sample_count = sample_count.to_i
        @deterministic = deterministic.nil? ? nil : !!deterministic
        @source = source.to_s
        @throttling_detected = !!throttling_detected
        @determinism_notes = Array(determinism_notes).map(&:to_s)
        @thermal = symbolize(thermal || {})
        @counters = symbolize(counters || {})
        @samples = Array(samples).map { |s| s.is_a?(Hash) ? s.transform_keys(&:to_sym) : s }
      end

      def deterministic?
        @deterministic
      end

      def throttling_detected?
        @throttling_detected
      end

      def to_h
        {
          source: @source, scope: "host",
          duration_seconds: @duration_seconds,
          sample_count: @sample_count,
          deterministic: @deterministic,
          throttling_detected: @throttling_detected,
          determinism_notes: @determinism_notes,
          thermal: @thermal,
          counters: @counters,
          samples: @samples
        }
      end

      def to_json(*args)
        JSON.pretty_generate(to_h, *args)
      end

      def self.from_h(hash)
        h = hash.transform_keys(&:to_sym)
        new(
          source: h[:source] || "native",
          duration_seconds: h[:duration_seconds],
          sample_count: h[:sample_count],
          deterministic: h[:deterministic],
          throttling_detected: h[:throttling_detected],
          determinism_notes: h[:determinism_notes],
          thermal: h[:thermal],
          counters: h[:counters],
          samples: h[:samples]
        )
      end

      def self.from_json(json_str)
        from_h(JSON.parse(json_str, symbolize_names: true))
      end

      # Formats a clean, readable Markdown telemetry section for benchmark summaries.
      def summary_markdown
        status_label = @deterministic.nil? ? "UNVERIFIED" : (@deterministic ? "NO THROTTLING OBSERVED" : "THROTTLING OBSERVED")
        lines = [
          "## Deterministic Hardware Telemetry & Thermal Monitoring",
          "",
          "- **Source / Scope**: #{@source} / host",
          "- **Thermal Verification**: #{status_label}"
        ]

        unless @determinism_notes.empty?
          lines << "- **Determinism Flags**:"
          @determinism_notes.each do |note|
            lines << "  - #{note}"
          end
        end

        # Thermal metrics
        pkg_events = @thermal[:package_throttle_delta] || "N/A"
        core_events = @thermal[:core_throttle_delta] || "N/A"
        throttle_time = @thermal.values_at(:package_throttle_time_ms_delta, :core_throttle_time_ms_delta).compact
        throttle_time = throttle_time.empty? ? "N/A" : throttle_time.sum

        peak_t = @thermal[:peak_celsius] ? "#{@thermal[:peak_celsius]}°C" : "N/A"
        init_t = @thermal[:initial_celsius] ? "#{@thermal[:initial_celsius]}°C" : "N/A"
        headroom = @thermal[:headroom_celsius] ? "#{@thermal[:headroom_celsius]}°C to critical trip" : "N/A"

        lines << "- **Thermal Range**: #{init_t} init -> #{peak_t} peak (Headroom: #{headroom})"
        lines << "- **Thermal Throttling**: #{pkg_events} package events, #{core_events} core events (#{throttle_time}ms)"

        # Counter metrics
        ctxt_tot = @counters[:context_switches_total]
        ctxt_rate = @counters[:context_switches_per_sec]
        if ctxt_tot
          lines << "- **Context Switches**: #{format_number(ctxt_tot)} (#{format_number(ctxt_rate)}/s)"
        end

        pg_tot = @counters[:page_faults_total]
        pg_rate = @counters[:page_faults_per_sec]
        if pg_tot
          lines << "- **Page Faults**: #{format_number(pg_tot)} (#{format_number(pg_rate)}/s)"
        end

        cpu_u = @counters[:cpu_utilization]
        if cpu_u && !cpu_u.empty?
          u_str = "#{cpu_u[:user_pct]}% user, #{cpu_u[:system_pct]}% system, #{cpu_u[:idle_pct]}% idle, #{cpu_u[:iowait_pct]}% iowait"
          lines << "- **CPU Utilization**: #{u_str}"
        end

        freq = @counters[:frequency_mhz]
        if freq && freq[:avg_mhz]
          lines << "- **CPU Frequency**: #{freq[:avg_mhz]} MHz avg (Min: #{freq[:min_mhz]} MHz, Max: #{freq[:max_mhz]} MHz, Gov: #{freq[:governor]})"
        end

        perf = @counters[:perf_counters]
        if perf && perf.key?(:available)
          values = perf[:values]
          if perf[:available]
            lines << "- **Hardware Counters (host)**: #{values.map { |key, value| "#{key}=#{value}" }.join(', ')}"
          else
            lines << "- **Hardware Counters**: unavailable (#{perf[:error]})"
          end
        elsif perf && perf[:ipc]
          lines << "- **Hardware IPC**: #{perf[:ipc]} (#{format_number(perf[:instructions])} insn / #{format_number(perf[:cycles])} cycles)"
        end

        lines.join("\n") + "\n"
      end

      private

      def symbolize(value)
        case value
        when Hash then value.to_h { |key, item| [key.to_sym, symbolize(item)] }
        when Array then value.map { |item| symbolize(item) }
        else value
        end
      end

      def format_number(val)
        return "N/A" if val.nil?

        if val.is_a?(Float)
          parts = sprintf("%.1f", val).split(".")
          parts[0].gsub(/(\d)(?=(\d\d\d)+(?!\d))/, '\\1,') + "." + parts[1]
        else
          val.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, '\\1,')
        end
      end
    end
  end
end
