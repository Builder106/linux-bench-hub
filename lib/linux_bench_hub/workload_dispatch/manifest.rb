# frozen_string_literal: true

require "json"
require "time"
require_relative "../hardware_telemetry/report"

module LinuxBenchHub
  module WorkloadDispatch
    # Execution manifest capturing run parameters, environment details, and performance metrics.
    class Manifest
      attr_accessor :run_id, :pipeline_name, :target_type, :distro,
                    :architecture, :kernel, :started_at, :completed_at,
                    :duration_seconds, :status, :workloads, :artifacts,
                    :hardware_telemetry, :errors

      def initialize(run_id:, pipeline_name:, target_type:, distro: nil,
                     architecture: nil, kernel: nil, started_at: nil,
                     completed_at: nil, duration_seconds: 0.0, status: :pending,
                     workloads: [], artifacts: {}, hardware_telemetry: nil, errors: [])
        @run_id = run_id.to_s
        @pipeline_name = pipeline_name.to_s
        @target_type = target_type.to_sym
        @distro = distro
        @architecture = architecture
        @kernel = kernel
        @started_at = started_at ? parse_time(started_at) : Time.now.utc
        @completed_at = completed_at ? parse_time(completed_at) : nil
        @duration_seconds = duration_seconds.to_f
        @status = status.to_sym
        @workloads = Array(workloads).map { |w| w.is_a?(Hash) ? w.transform_keys(&:to_sym) : w }
        @artifacts = (artifacts || {}).transform_keys(&:to_sym)
        @hardware_telemetry = hardware_telemetry.is_a?(Hash) ? hardware_telemetry.transform_keys(&:to_sym) : hardware_telemetry
        @errors = Array(errors).map(&:to_s)
      end

      def success?
        @status == :success
      end

      def deterministic?
        return nil if @hardware_telemetry.nil?

        @hardware_telemetry[:deterministic]
      end

      def throttling_detected?
        return false if @hardware_telemetry.nil?

        !!@hardware_telemetry[:throttling_detected]
      end

      def to_h
        {
          run_id: @run_id,
          pipeline_name: @pipeline_name,
          target_type: @target_type,
          distro: @distro,
          architecture: @architecture,
          kernel: @kernel,
          started_at: @started_at&.iso8601,
          completed_at: @completed_at&.iso8601,
          duration_seconds: @duration_seconds,
          status: @status,
          workloads: @workloads,
          hardware_telemetry: @hardware_telemetry,
          artifacts: @artifacts,
          errors: @errors
        }
      end

      def to_json(*args)
        JSON.pretty_generate(to_h, *args)
      end

      def save(path)
        File.write(path, to_json)
      end

      def self.from_json(str)
        data = JSON.parse(str, symbolize_names: true)
        new(**data)
      end

      def summary_markdown
        rows = [
          "# Workload Dispatch Run: #{@run_id}",
          "",
          "- **Status**: #{@status.to_s.upcase}",
          "- **Pipeline**: #{@pipeline_name}",
          "- **Target**: #{@target_type}",
          "- **Distro / Arch**: #{@distro || 'N/A'} (#{@architecture || 'N/A'})",
          "- **Kernel**: #{@kernel || 'N/A'}",
          "- **Duration**: #{@duration_seconds.round(2)}s"
        ]

        if @hardware_telemetry
          det_label = deterministic?.nil? ? "UNVERIFIED" : (deterministic? ? "NO THROTTLING OBSERVED" : "THROTTLING OBSERVED")
          rows << "- **Hardware Determinism**: #{det_label}#{throttling_detected? ? ' (Thermal throttling detected)' : ''}"
        end

        rows << ""
        rows << "## Benchmark Workload Results"
        rows << ""
        rows << "| Category | Workload | Metric / Scale | Mean | StdDev | Status |"
        rows << "| :--- | :--- | :--- | :--- | :--- | :--- |"

        @workloads.each do |w|
          mean_str = w[:mean] ? sprintf("%.2f", w[:mean]) : "N/A"
          stddev_str = w[:stddev] ? sprintf("%.2f", w[:stddev]) : "N/A"
          scale_str = "#{w[:scale] || w[:unit]}#{w[:lower_is_better] ? ' (LIB)' : ' (HIB)'}"
          rows << "| #{w[:category]} | #{w[:name] || w[:identifier]} | #{scale_str} | #{mean_str} | #{stddev_str} | #{w[:status]} |"
        end

        content = rows.join("\n") + "\n"

        if @hardware_telemetry
          report = HardwareTelemetry::Report.from_h(@hardware_telemetry)
          content += "\n" + report.summary_markdown
        end

        content
      end

      private

      def parse_time(time_val)
        case time_val
        when Time then time_val.utc
        when String then Time.parse(time_val).utc
        else Time.now.utc
        end
      end
    end
  end
end
