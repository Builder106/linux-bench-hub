# frozen_string_literal: true

require "pathname"
require_relative "workload"

module LinuxBenchHub
  module WorkloadDispatch
    # Configured sequence of workloads to be executed together as a reproducible pipeline.
    class Pipeline
      attr_reader :name, :workloads, :output_dir, :results_name,
                  :environment_variables, :pts_config_path, :timeout_seconds,
                  :telemetry, :telemetry_interval, :telemetry_options

      def initialize(name: "LBH Standard Benchmark Pipeline",
                     workloads: [],
                     output_dir: "captures",
                     results_name: nil,
                     environment_variables: {},
                     pts_config_path: nil,
                     timeout_seconds: 7200,
                     telemetry: true,
                     telemetry_interval: 1.0,
                     telemetry_options: {})
        @name = name.to_s
        @workloads = resolve_workloads(workloads)
        @output_dir = Pathname.new(output_dir)
        @results_name = results_name || default_results_name
        @environment_variables = (environment_variables || {}).transform_keys(&:to_s)
        @pts_config_path = pts_config_path ? Pathname.new(pts_config_path) : nil
        @timeout_seconds = timeout_seconds.to_i
        @telemetry = telemetry.nil? ? true : !!telemetry
        @telemetry_interval = Float(telemetry_interval)
        unless @telemetry_interval.finite? && (@telemetry_interval.zero? || @telemetry_interval >= 0.1)
          raise ArgumentError, "telemetry_interval must be zero or finite and at least 0.1s"
        end
        @telemetry_options = (telemetry_options || {}).transform_keys(&:to_sym)
      end

      def telemetry_enabled?
        @telemetry
      end

      # Factory method for a standard three-tier pipeline covering CPU, Memory, and Disk I/O.
      def self.standard(categories: %i[cpu memory disk_io], output_dir: "captures", **options)
        selected = categories.map do |cat|
          Workload::STANDARD_TIERS[cat.to_sym] || Workload.find(cat) || raise(ArgumentError, "Unknown workload: #{cat}")
        end.compact.uniq

        new(
          name: "Standard Three-Tier Pipeline (#{categories.join(', ')})",
          workloads: selected,
          output_dir: output_dir,
          **options
        )
      end

      def categories
        @workloads.map(&:category).uniq
      end

      def covers_three_tiers?
        (%i[cpu memory disk_io] - categories).empty?
      end

      # Deterministic answers piped to stdin for Phoronix Test Suite's batch-benchmark.
      def batch_input_string
        answers = @workloads.flat_map(&:interactive_answers)
        return "" if answers.empty?

        answers.join("\n") + "\n"
      end

      # Phoronix Test Suite test identifiers to run.
      def pts_arguments
        @workloads.map(&:test_identifier)
      end

      def validate!
        raise ArgumentError, "Pipeline must contain at least one workload" if @workloads.empty?

        @workloads.each do |w|
          unless w.is_a?(Workload)
            raise ArgumentError, "Invalid workload: #{w.inspect}. Must be an instance of Workload"
          end
        end

        true
      end

      private

      def default_results_name
        date_str = Time.now.utc.strftime("%Y-%m-%d")
        "lbh-dispatch-#{date_str}"
      end

      def resolve_workloads(items)
        Array(items).map do |item|
          case item
          when Workload then item
          when Symbol, String then Workload.find(item) || raise(ArgumentError, "Unknown workload: #{item}")
          else
            raise ArgumentError, "Cannot resolve workload from #{item.inspect}"
          end
        end
      end
    end
  end
end
