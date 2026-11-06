# frozen_string_literal: true

require "json"

module LinuxBenchHub
  module KernelComparison
    # Deterministic, direction-aware diffs; thresholds are policy, not significance tests.
    class Engine
      def initialize(threshold_percent: 5.0)
        @threshold = Float(threshold_percent)
        unless @threshold.finite? && @threshold >= 0
          raise ArgumentError, "Threshold must be finite and nonnegative"
        end
      end

      def compare(baseline, candidate)
        reasons = %i[architecture hardware userland pts_version].filter_map do |field|
          "#{field} differs" unless baseline.metadata[field] == candidate.metadata[field]
        end
        if baseline.metadata[:kernel] == candidate.metadata[:kernel]
          reasons << "Kernel versions must differ"
        end
        warnings = [ "Recorded metadata cannot establish identical hosts or isolate kernel causality; inspect telemetry and environment before attribution." ]
        if baseline.metadata[:system_details] != candidate.metadata[:system_details]
          warnings << "System details differ; inspect baseline and candidate metadata."
        end
        rows = (baseline.metrics.keys | candidate.metrics.keys).sort.map do |key|
          before = baseline.metrics[key]
          after = candidate.metrics[key]
          row = { identity: (before || after).fetch(:identity), baseline: before, candidate: after }
          if before.nil? || after.nil?
            row.merge(status: before.nil? ? "added" : "removed")
          elsif !reasons.empty?
            row.merge(status: "incomparable")
          else
            diff_metric(row, before, after)
          end
        end
        counts = rows.group_by { |row| row.fetch(:status) }.transform_values(&:size)
        status = if !reasons.empty?
                   "incompatible"
        elsif counts.key?("added") || counts.key?("removed")
                   "partial"
        elsif counts.key?("regression")
                   "regression"
        else
                   "passed"
        end
        {
          schema_version: 1, status: status, threshold_percent: @threshold,
          baseline: baseline.metadata, candidate: candidate.metadata,
          incompatibilities: reasons, warnings: warnings,
          summary: counts, metrics: rows
        }
      end

      private

      def diff_metric(row, before, after)
        delta = after.fetch(:mean) - before.fetch(:mean)
        change = (delta / before.fetch(:mean)) * 100.0
        raise ArgumentError, "Non-finite percentage change" unless change.finite?
        regression = row.fetch(:identity).fetch("Proportion") == "LIB" ? change : -change
        status = if regression > @threshold
                   "regression"
        elsif regression < -@threshold
                   "improvement"
        else
                   "unchanged"
        end
        row.merge(status: status, delta: delta, change_percent: change, regression_percent: regression)
      end
    end
  end
end
