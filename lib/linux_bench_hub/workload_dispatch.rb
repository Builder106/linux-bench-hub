# frozen_string_literal: true

require_relative "workload_dispatch/workload"
require_relative "workload_dispatch/pipeline"
require_relative "workload_dispatch/target"
require_relative "workload_dispatch/manifest"
require_relative "workload_dispatch/dispatcher"

module LinuxBenchHub
  # Automated Workload Dispatch module providing reproducible benchmark pipelines
  # across CPU, memory bandwidth, and disk I/O.
  module WorkloadDispatch
    class << self
      def standard_pipeline(categories: %i[cpu memory disk_io], **options)
        Pipeline.standard(categories: categories, **options)
      end

      def target_for(type, **options)
        case type.to_s.downcase
        when "local"
          LocalTarget.new(**options)
        when "docker", "container"
          DockerTarget.new(**options)
        when "ssh", "remote"
          SshTarget.new(**options)
        when "simulated", "simulate", "dry_run", "dry-run"
          SimulatedTarget.new(**options)
        else
          raise ArgumentError, "Unknown target type: #{type}. Supported: local, docker, ssh, simulated"
        end
      end

      def dispatch(workloads: %i[cpu memory disk_io], target: :simulated, **options)
        run_id = options.delete(:run_id)
        logger = options.delete(:logger)

        pipeline_keys = %i[name output_dir results_name environment_variables pts_config_path
                         timeout_seconds telemetry telemetry_interval telemetry_options]
        pipeline_opts = options.slice(*pipeline_keys)
        target_opts = options.except(*pipeline_keys)

        pipeline = if workloads.is_a?(Pipeline)
                     workloads
                   else
                     Pipeline.standard(categories: Array(workloads), **pipeline_opts)
                   end

        target_obj = target.is_a?(BaseTarget) ? target : target_for(target, **target_opts)
        dispatcher = Dispatcher.new(logger: logger)
        dispatcher.dispatch(pipeline, target_obj, run_id: run_id)
      end
    end
  end
end
