# frozen_string_literal: true

require "json"

module LinuxBenchHub
  # Offline exports of sampled stacks, never inferred function durations.
  module TraceExport
    HEADER = /\A\s*(\S.*?)\s+(\d+)\/(\d+)\s+\[(\d+)\]\s+(\d+)\.(\d{1,9}):\s+(\S+):\s*\z/
    FRAME = /\A\s+([0-9a-fA-F]+)\s+(.+)\s+\((.+)\)\s*\z/
    MAX_BYTES = 64 * 1024 * 1024
    MAX_SAMPLES = 100_000
    MAX_DEPTH = 512

    class Profile
      def initialize(input, event: nil)
        @samples = []
        current = nil
        bytes = 0
        input.each_line("\n", MAX_BYTES + 1).with_index(1) do |line, number|
          bytes += line.bytesize
          raise ArgumentError, "Trace exceeds #{MAX_BYTES} bytes" if bytes > MAX_BYTES
          line = line.chomp.force_encoding(Encoding::UTF_8)
          raise ArgumentError, "Invalid text at line #{number}" unless line.valid_encoding? && !line.match?(/[\x00-\x08\x0b-\x1f\x7f]/)
          if line.strip.empty?
            next
          elsif (match = HEADER.match(line))
            append(current) if current
            seconds = match[5].to_i
            timestamp = seconds * 1_000_000_000 + match[6].ljust(9, "0").to_i
            raise ArgumentError, "Timestamp exceeds signed 64-bit nanoseconds at line #{number}" if timestamp > 2**63 - 1

            current = { comm: match[1], pid: match[2].to_i, tid: match[3].to_i,
                        cpu: match[4].to_i, timestamp_ns: timestamp, event: match[7], frames: [] }
            raise ArgumentError, "Invalid process/thread/CPU ID at line #{number}" if current.values_at(:pid, :tid, :cpu).any? { |id| id > 2**31 - 1 }
          elsif line.lstrip.start_with?("#")
            next
          elsif current && (match = FRAME.match(line))
            raise ArgumentError, "Stack exceeds #{MAX_DEPTH} frames at line #{number}" if current[:frames].size >= MAX_DEPTH

            current[:frames] << { address: match[1], symbol: match[2].sub(/\+0x[0-9a-fA-F]+(?:\/0x[0-9a-fA-F]+)?\z/, ""), dso: match[3] }
          else
            raise ArgumentError, "Unsupported perf script record at line #{number}; use -F comm,pid,tid,cpu,time,event,ip,sym,dso"
          end
        end
        append(current) if current
        raise ArgumentError, "Trace has no stack samples" if @samples.empty?

        if event
          @samples.select! { |sample| sample[:event] == event }
          raise ArgumentError, "No samples for event #{event}" if @samples.empty?
        elsif @samples.map { |sample| sample[:event] }.uniq.size != 1
          raise ArgumentError, "Multiple events require --event to avoid mixing sample populations"
        end
        @samples = @samples.each_with_index.sort_by { |sample, index| [ sample[:timestamp_ns], index ] }.map(&:first)
      end

      def folded
        counts = Hash.new(0)
        @samples.each do |sample|
          root = "#{sample[:comm]}-#{sample[:pid]}/#{sample[:tid]}"
          frames = sample[:frames].reverse.map { |frame| label(frame) }
          stack = [ root, *frames ].map { |name| escape(name) }.join(";")
          counts[stack] += 1
        end
        counts.sort.map { |stack, count| "#{stack} #{count}\n" }.join
      end

      def perfetto
        origin = @samples.first[:timestamp_ns]
        events = []
        threads = @samples.uniq { |sample| sample.values_at(:pid, :tid) }
        threads.sort_by { |sample| sample.values_at(:pid, :tid) }.each do |sample|
          pid, tid, comm = sample.values_at(:pid, :tid, :comm)
          events << { ph: "M", name: "thread_name", pid: pid, tid: tid, args: { name: comm } }
        end
        @samples.each do |sample|
          events << {
            ph: "i", s: "t", cat: "perf.sample", name: label(sample[:frames].first),
            pid: sample[:pid], tid: sample[:tid], ts: (sample[:timestamp_ns] - origin) / 1000.0,
            args: { event: sample[:event], cpu: sample[:cpu], comm: sample[:comm],
                    timestamp_ns: sample[:timestamp_ns], stack: sample[:frames].reverse }
          }
        end
        JSON.pretty_generate({ traceEvents: events, displayTimeUnit: "ms",
                               metadata: { source: "perf script", timestamp_origin_ns: origin,
                                           event: @samples.first[:event], sample_count: @samples.size,
                                           weight: "one per recorded sample; not elapsed time" } }) + "\n"
      end

      private

      def append(sample)
        raise ArgumentError, "Sample has no call stack; record with perf record -g" if sample[:frames].empty?
        raise ArgumentError, "Trace exceeds #{MAX_SAMPLES} samples" if @samples.size >= MAX_SAMPLES

        @samples << sample
      end

      def label(frame)
        symbol = frame[:symbol]
        symbol = "#{symbol}@#{frame[:address]}" if symbol == "[unknown]"
        dso = frame[:dso]
        kernel = (dso.start_with?("[") && !%w[[unknown] [vdso] [vsyscall]].include?(dso)) || File.basename(dso) == "vmlinux" || dso.match?(/\.ko(?:\.(?:xz|gz|zst))?\z/)
        "#{symbol} (#{dso})#{'_[k]' if kernel}"
      end

      def escape(name)
        name.gsub("%", "%25").gsub(";", "%3B").gsub("#", "%23")
      end
    end
  end
end
