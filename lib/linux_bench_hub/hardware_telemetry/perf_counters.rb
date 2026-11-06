# frozen_string_literal: true

require "tempfile"

module LinuxBenchHub
  module HardwareTelemetry
    # Counts host-wide PMU events without sampling stacks or recording traces.
    # perf is optional; unsupported events and permission failures stay explicit.
    class PerfCounters
      EVENTS = %w[cycles instructions cache-references cache-misses].freeze

      def initialize(executable: "perf")
        @executable = executable
      end

      def start
        @output = Tempfile.new("lbh-perf")
        @pid = Process.spawn({ "LC_ALL" => "C" }, @executable, "stat", "-a",
                             "--no-big-num", "-x", ";", "-e", EVENTS.join(","),
                             out: File::NULL, err: @output)
        self
      rescue SystemCallError => e
        @error = e.message
        self
      end

      def stop
        if @pid
          # perf stat with no command counts until SIGINT. Always reap it.
          begin
            Process.kill("INT", @pid)
          rescue Errno::ESRCH
            # Permission checks can make perf exit before the workload does.
          end
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2.0
          until Process.waitpid(@pid, Process::WNOHANG)
            if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
              Process.kill("KILL", @pid)
              Process.waitpid(@pid)
              break
            end
            sleep 0.01
          end
          @pid = nil
        end
        @output&.rewind
        values = self.class.parse(@output ? @output.read : "")
        {
          available: !values.empty?, scope: "host", values: values,
          unavailable_events: EVENTS.reject { |event| values.key?(event.tr("-", "_").to_sym) },
          error: values.empty? ? (@error || "PMU events unavailable or perf access denied") : nil
        }
      ensure
        @output&.close!
        @output = nil
      end

      def self.parse(output)
        output.each_line.each_with_object({}) do |line, values|
          count, _unit, event = line.strip.split(";")
          next unless EVENTS.include?(event) && count&.match?(/\A\d+(?:\.\d+)?\z/)

          values[event.tr("-", "_").to_sym] = count.to_i
        end
      end
    end
  end
end
