# frozen_string_literal: true

require "fileutils"
require "pathname"
require "rexml/document"
require_relative "workload"
require_relative "pipeline"
require_relative "target"
require_relative "manifest"
require_relative "../hardware_telemetry"

module LinuxBenchHub
  module WorkloadDispatch
    # Struct returned by Dispatcher#dispatch.
    DispatchResult = Struct.new(:success, :manifest, :execution_result,
                                :output_dir, :composite_xml_path, :manifest_path,
                                :telemetry_report, :telemetry_path,
                                keyword_init: true) do
      def success?
        !!success
      end

      def deterministic?
        manifest&.deterministic?
      end

      def throttling_detected?
        manifest&.throttling_detected?
      end
    end

    # Orchestrates reproducible workload dispatch across targets.
    class Dispatcher
      attr_reader :logger

      def initialize(logger: nil)
        @logger = logger
      end

      # Dispatches a benchmark pipeline on a target.
      def dispatch(pipeline, target, run_id: nil)
        pipeline.validate!

        effective_run_id = run_id || generate_run_id(pipeline, target)
        run_output_dir = pipeline.output_dir.join(effective_run_id)
        FileUtils.mkdir_p(run_output_dir)

        log("Starting workload dispatch '#{effective_run_id}' using target '#{target.name}'")

        # Step 1: Preflight check
        preflight = target.preflight_check(pipeline)
        unless preflight.ok?
          log("Preflight check failed: #{preflight.errors.join('; ')}")
          manifest = build_failed_manifest(pipeline, target, effective_run_id, preflight.errors)
          manifest_path = run_output_dir.join("manifest.json")
          manifest.save(manifest_path)

          return DispatchResult.new(
            success: false,
            manifest: manifest,
            execution_result: ExecutionResult.new(
              success: false,
              stdout: "",
              stderr: preflight.errors.join("\n"),
              exit_code: 1,
              composite_xml: nil,
              install_failures: []
            ),
            output_dir: run_output_dir.to_s,
            composite_xml_path: nil,
            manifest_path: manifest_path.to_s
          )
        end

        # Step 2: Execution & Telemetry Collection
        started_at = Time.now.utc
        run_context = {
          run_id: effective_run_id,
          output_dir: run_output_dir.to_s
        }

        telemetry_collector = nil
        if pipeline.telemetry_enabled?
          mode = case target.target_type
                 when :simulated then :simulated
                 when :ssh, :docker then :unavailable
                 else :native
                 end
          opts = {
            mode: mode,
            interval: pipeline.telemetry_interval,
            logger: @logger
          }.merge(pipeline.telemetry_options).merge(mode: mode)
          telemetry_collector = HardwareTelemetry::Collector.new(**opts)
          telemetry_collector.start
        end

        begin
          exec_res = target.execute(pipeline, run_context)
        ensure
          telemetry_report = telemetry_collector&.stop
        end
        completed_at = Time.now.utc
        duration = completed_at - started_at

        telemetry_path = nil
        if telemetry_report
          telemetry_path = run_output_dir.join("telemetry.json")
          File.write(telemetry_path, telemetry_report.to_json)
        end

        # Step 3: Artifact parsing & manifest generation
        composite_path = nil
        parsed_results = []
        system_info = {}

        if exec_res.composite_xml
          composite_path = run_output_dir.join("composite.xml")
          File.write(composite_path, exec_res.composite_xml)
          system_info, parsed_results = parse_composite_xml(exec_res.composite_xml)
        end

        workload_summaries = map_workload_results(pipeline, parsed_results, exec_res.install_failures)

        status = determine_status(exec_res, workload_summaries)

        manifest = Manifest.new(
          run_id: effective_run_id,
          pipeline_name: pipeline.name,
          target_type: target.target_type,
          distro: system_info[:os] || (target.respond_to?(:distro) ? target.distro : nil),
          architecture: system_info[:arch] || RUBY_PLATFORM,
          kernel: system_info[:kernel],
          started_at: started_at,
          completed_at: completed_at,
          duration_seconds: duration,
          status: status,
          workloads: workload_summaries,
          hardware_telemetry: telemetry_report&.to_h,
          artifacts: {
            composite_xml: composite_path&.to_s,
            manifest_json: run_output_dir.join("manifest.json").to_s,
            telemetry_json: telemetry_path&.to_s,
            summary_markdown: run_output_dir.join("summary.md").to_s
          }.compact,
          errors: exec_res.install_failures.map { |f| "#{f[:test]} install failed" }
        )

        manifest_path = run_output_dir.join("manifest.json")
        manifest.save(manifest_path)

        summary_path = run_output_dir.join("summary.md")
        File.write(summary_path, manifest.summary_markdown)

        log("Completed dispatch '#{effective_run_id}' with status: #{status} (deterministic: #{manifest.deterministic?})")

        DispatchResult.new(
          success: status == :success,
          manifest: manifest,
          execution_result: exec_res,
          output_dir: run_output_dir.to_s,
          composite_xml_path: composite_path&.to_s,
          manifest_path: manifest_path.to_s,
          telemetry_report: telemetry_report,
          telemetry_path: telemetry_path&.to_s
        )
      end

      private

      def log(msg)
        return unless @logger

        if @logger.respond_to?(:info)
          @logger.info("[WorkloadDispatch] #{msg}")
        else
          @logger.puts("[WorkloadDispatch] #{msg}")
        end
      end

      def generate_run_id(pipeline, target)
        date_stamp = Time.now.utc.strftime("%Y%m%d-%H%M%S")
        target_slug = target.target_type.to_s
        target_slug += "-#{target.distro}" if target.respond_to?(:distro) && target.distro
        "lbh-#{target_slug}-#{date_stamp}"
      end

      def build_failed_manifest(pipeline, target, run_id, errors)
        Manifest.new(
          run_id: run_id,
          pipeline_name: pipeline.name,
          target_type: target.target_type,
          started_at: Time.now.utc,
          completed_at: Time.now.utc,
          duration_seconds: 0.0,
          status: :failed,
          workloads: pipeline.workloads.map { |w| { category: w.category, name: w.name, status: :skipped } },
          errors: errors
        )
      end

      def determine_status(exec_res, workload_summaries)
        return :failed unless exec_res.success?

        all_ok = workload_summaries.all? { |w| w[:status] == :passed }
        any_ok = workload_summaries.any? { |w| w[:status] == :passed }

        if all_ok
          :success
        elsif any_ok
          :partial
        else
          :failed
        end
      end

      def parse_composite_xml(xml_content)
        doc = REXML::Document.new(xml_content)
        system_info = {}

        if (sys_node = doc.elements["//System"])
          if (hw_node = sys_node.elements["Hardware"])
            hw_text = hw_node.text.to_s.strip
            system_info[:processor] = hw_text[/Processor:\s*([^,]+)/, 1]
            system_info[:memory] = hw_text[/Memory:\s*([^,]+)/, 1]
            system_info[:disk] = hw_text[/Disk:\s*([^,]+)/, 1]
          end
          if (sw_node = sys_node.elements["Software"])
            sw_text = sw_node.text.to_s.strip
            system_info[:os] = sw_text[/OS:\s*([^,]+)/, 1]
            system_info[:kernel] = sw_text[/Kernel:\s*([^,]+)/, 1]
            system_info[:arch] = system_info[:kernel]&.slice(/\(([^)]+)\)\z/, 1)
          end
        end

        results = []
        doc.elements.each("//Result") do |res_node|
          identifier = res_node.elements["Identifier"]&.text&.strip
          title = res_node.elements["Title"]&.text&.strip
          desc = res_node.elements["Description"]&.text&.strip
          scale = res_node.elements["Scale"]&.text&.strip
          proportion = res_node.elements["Proportion"]&.text&.strip

          raw_str = res_node.elements["Data/Entry/RawString"]&.text&.strip
          runs = raw_str ? raw_str.split(":").map(&:strip).map(&:to_f) : []
          val_str = res_node.elements["Data/Entry/Value"]&.text&.strip
          mean = val_str ? val_str.to_f : (runs.empty? ? nil : runs.sum / runs.size)

          stddev = if runs.size >= 2
                     Math.sqrt(runs.sum { |v| (v - mean)**2 } / (runs.size - 1))
                   else
                     0.0
                   end

          results << {
            identifier: identifier,
            title: title,
            description: desc,
            scale: scale,
            lower_is_better: proportion == "LIB",
            runs: runs,
            mean: mean,
            stddev: stddev
          }
        end

        [system_info, results]
      rescue => e
        [{ error: e.message }, []]
      end

      def map_workload_results(pipeline, parsed_results, install_failures)
        failed_tests = install_failures.map { |f| f[:test] }

        pipeline.workloads.map do |workload|
          matched = parsed_results.select { |r| r[:identifier] == workload.test_identifier }

          is_install_failed = failed_tests.any? { |t| workload.test_identifier.include?(t) }

          if is_install_failed
            {
              category: workload.category,
              name: workload.name,
              identifier: workload.test_identifier,
              status: :failed,
              error: "Benchmark test installation failed"
            }
          elsif matched.empty?
            {
              category: workload.category,
              name: workload.name,
              identifier: workload.test_identifier,
              status: :missing,
              error: "Result not found in composite output"
            }
          elsif matched.size == 1
            entry = matched.first
            {
              category: workload.category,
              name: workload.name,
              identifier: workload.test_identifier,
              description: entry[:description],
              scale: entry[:scale],
              lower_is_better: entry[:lower_is_better],
              mean: entry[:mean],
              stddev: entry[:stddev],
              runs: entry[:runs],
              status: :passed
            }
          else
            # Workload has multiple sub-results (e.g. tinymembench: memcpy and memset)
            sub_metrics = matched.map do |m|
              {
                description: m[:description],
                scale: m[:scale],
                lower_is_better: m[:lower_is_better],
                mean: m[:mean],
                stddev: m[:stddev],
                runs: m[:runs]
              }
            end
            {
              category: workload.category,
              name: workload.name,
              identifier: workload.test_identifier,
              sub_metrics: sub_metrics,
              mean: matched.map { |m| m[:mean] }.sum / matched.size,
              status: :passed
            }
          end
        end
      end
    end
  end
end
