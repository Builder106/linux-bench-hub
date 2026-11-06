# frozen_string_literal: true

require "thread"

module LinuxBenchHub
  module HardwareTelemetry
    # Fixed-rate polling with bounded storage and an interruptible wait.
    class Sampler
      DEFAULT_INTERVAL_SECONDS = 1.0
      MAX_SAMPLES = 3600

      attr_reader :interval, :max_samples

      def initialize(collector, interval: DEFAULT_INTERVAL_SECONDS, max_samples: MAX_SAMPLES)
        @collector = collector
        @interval = Float(interval)
        @max_samples = Integer(max_samples)
        raise ArgumentError, "interval must be finite and at least 0.1s" unless @interval.finite? && @interval >= 0.1
        raise ArgumentError, "max_samples must be positive" unless @max_samples.positive?

        @samples = []
        @mutex = Mutex.new
        @wake = ConditionVariable.new
        @running = false
      end

      def running?
        @mutex.synchronize { @running }
      end

      def start
        @mutex.synchronize do
          return if @running

          @running = true
          @thread = Thread.new { sample_loop }
        end
      end

      def stop
        @mutex.synchronize do
          @running = false
          @wake.broadcast
        end
        if @thread && !@thread.join(2.0)
          @thread.kill.join
        end
        samples
      end

      def samples
        @mutex.synchronize { @samples.dup }
      end

      def add_sample(sample)
        @mutex.synchronize do
          @samples.shift if @samples.size >= @max_samples
          @samples << sample
        end
      end

      private

      def sample_loop
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        index = 0
        loop do
          deadline = start_time + (index + 1) * @interval
          active = @mutex.synchronize do
            while @running && (remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)).positive?
              @wake.wait(@mutex, remaining)
            end
            @running
          end
          break unless active

          index += 1
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          sample = @collector.capture_sample(index: index, elapsed: elapsed)
          add_sample(sample) if sample
          # Skip missed deadlines instead of producing a burst of catch-up reads.
          index = [ index, (elapsed / @interval).floor ].max
        end
      ensure
        @mutex.synchronize { @running = false }
      end
    end
  end
end
