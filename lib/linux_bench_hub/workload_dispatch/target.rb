# frozen_string_literal: true

require "open3"
require "fileutils"
require "pathname"
require "rexml/document"

module LinuxBenchHub
  module WorkloadDispatch
    # Struct representing preflight validation results.
    PreflightResult = Struct.new(:ok, :errors, :warnings, keyword_init: true) do
      def ok?
        !!ok
      end
    end

    # Struct representing raw execution output.
    ExecutionResult = Struct.new(:success, :stdout, :stderr, :exit_code,
                                 :composite_xml, :install_failures, keyword_init: true) do
      def success?
        !!success
      end
    end

    # Abstract base target for workload execution environments.
    class BaseTarget
      attr_reader :name, :options

      def initialize(name: nil, **options)
        @name = (name || default_name).to_s
        @options = options
      end

      def target_type
        :base
      end

      def preflight_check(_pipeline)
        PreflightResult.new(ok: true, errors: [], warnings: [])
      end

      def execute(_pipeline, _run_context)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      protected

      def default_name
        (self.class.name || "anonymous").split("::").last.sub(/Target\z/, "").downcase
      end
    end

    # Native local execution on the current machine using installed tools.
    class LocalTarget < BaseTarget
      def target_type
        :local
      end

      def preflight_check(pipeline)
        errors = []
        warnings = []

        pts_path = find_executable("phoronix-test-suite")
        if pts_path.nil?
          errors << "phoronix-test-suite executable not found on PATH"
        end

        pipeline.workloads.each do |w|
          w.dependencies.each do |dep|
            # Note: informational check
            warnings << "Dependency '#{dep}' required for workload '#{w.id}'" unless package_installed?(dep)
          end
        end

        PreflightResult.new(ok: errors.empty?, errors: errors, warnings: warnings)
      end

      def execute(pipeline, run_context)
        pre = preflight_check(pipeline)
        unless pre.ok?
          return ExecutionResult.new(
            success: false,
            stdout: "",
            stderr: pre.errors.join("\n"),
            exit_code: 1,
            composite_xml: nil,
            install_failures: []
          )
        end

        configure_pts_batch(pipeline)

        cmd = ["phoronix-test-suite", "batch-benchmark", *pipeline.pts_arguments]
        stdin_data = pipeline.batch_input_string
        env = {
          "TEST_RESULTS_NAME" => run_context[:run_id],
          "PTS_SILENT_MODE" => "1"
        }.merge(pipeline.environment_variables)

        stdout, stderr, status = Open3.capture3(env, *cmd, stdin_data: stdin_data)

        composite_content = find_composite_xml
        install_failures = check_install_failures

        ExecutionResult.new(
          success: status.success? && !composite_content.nil?,
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          composite_xml: composite_content,
          install_failures: install_failures
        )
      end

      private

      def find_executable(name)
        ENV["PATH"].to_s.split(File::PATH_SEPARATOR).each do |dir|
          bin = File.join(dir, name)
          return bin if File.file?(bin) && File.executable?(bin)
        end
        nil
      end

      def package_installed?(_name)
        true
      end

      def configure_pts_batch(pipeline)
        if pipeline.pts_config_path && File.file?(pipeline.pts_config_path)
          pts_dir = File.expand_path("~/.phoronix-test-suite")
          FileUtils.mkdir_p(pts_dir)
          FileUtils.cp(pipeline.pts_config_path, File.join(pts_dir, "user-config.xml"))
        end

        # Non-interactive answer stream to guarantee batch setup is configured
        Open3.capture3("phoronix-test-suite", "batch-setup", stdin_data: "y\nn\nn\nn\nn\nn\nn\n")
      end

      def find_composite_xml
        search_dirs = [
          "/var/lib/phoronix-test-suite",
          File.expand_path("~/.phoronix-test-suite")
        ]

        search_dirs.each do |dir|
          next unless Dir.exist?(dir)

          matches = Dir.glob(File.join(dir, "**", "composite.xml"))
          unless matches.empty?
            latest = matches.max_by { |f| File.mtime(f) }
            return File.read(latest) if latest && File.file?(latest)
          end
        end

        nil
      end

      def check_install_failures
        search_dirs = [
          "/var/lib/phoronix-test-suite/installed-tests/pts",
          File.expand_path("~/.phoronix-test-suite/installed-tests/pts")
        ]

        failures = []
        search_dirs.each do |dir|
          next unless Dir.exist?(dir)

          Dir.glob(File.join(dir, "*", "install-failed.log")).each do |log|
            test_name = File.basename(File.dirname(log))
            content = File.read(log) rescue "Could not read failure log"
            failures << { test: test_name, log: content }
          end
        end

        failures
      end
    end

    # Containerized workload dispatch using Docker.
    class DockerTarget < BaseTarget
      DISTRO_IMAGES = {
        "ubuntu" => "ubuntu:26.04",
        "fedora" => "fedora:44",
        "debian" => "debian:13"
      }.freeze

      attr_reader :distro, :image

      def initialize(distro: "ubuntu", image: nil, **options)
        @distro = distro.to_s
        @image = image || DISTRO_IMAGES.fetch(@distro, "ubuntu:26.04")
        super(name: "docker-#{@distro}", **options)
      end

      def target_type
        :docker
      end

      def preflight_check(_pipeline)
        errors = []
        _, _, status = Open3.capture3("docker", "--version") rescue [nil, nil, nil]
        errors << "Docker executable not found or not functional" unless status&.success?

        PreflightResult.new(ok: errors.empty?, errors: errors, warnings: [])
      end

      def build_docker_command(pipeline, run_context, host_output_dir)
        [
          "docker", "run", "--rm",
          "--name", "lbh-dispatch-#{run_context[:run_id]}",
          "-v", "#{host_output_dir}:/output",
          "-e", "TEST_RESULTS_NAME=#{run_context[:run_id]}",
          "-e", "PTS_SILENT_MODE=1",
          @image,
          "/bin/bash", "-c",
          container_script(pipeline)
        ]
      end

      def execute(pipeline, run_context)
        pre = preflight_check(pipeline)
        unless pre.ok?
          return ExecutionResult.new(
            success: false,
            stdout: "",
            stderr: pre.errors.join("\n"),
            exit_code: 1,
            composite_xml: nil,
            install_failures: []
          )
        end

        host_output_dir = File.expand_path(run_context[:output_dir])
        FileUtils.mkdir_p(host_output_dir)

        cmd = build_docker_command(pipeline, run_context, host_output_dir)
        stdout, stderr, status = Open3.capture3(*cmd)

        composite_file = File.join(host_output_dir, "composite.xml")
        composite_content = File.read(composite_file) if File.file?(composite_file)

        ExecutionResult.new(
          success: status.success? && !composite_content.nil?,
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          composite_xml: composite_content,
          install_failures: []
        )
      end

      private

      def container_script(pipeline)
        tests = pipeline.pts_arguments.join(" ")
        answers = pipeline.batch_input_string.gsub("\n", "\\n")
        <<~BASH.strip
          set -euo pipefail
          printf 'y\\nn\\nn\\nn\\nn\\nn\\nn\\n' | phoronix-test-suite batch-setup
          printf '#{answers}' | phoronix-test-suite batch-benchmark #{tests}
          composite=$(find /var/lib/phoronix-test-suite /root/.phoronix-test-suite -name composite.xml -print -quit 2>/dev/null || true)
          if [ -n "$composite" ]; then cp "$composite" /output/composite.xml; fi
        BASH
      end
    end

    # Remote workload dispatch over SSH.
    class SshTarget < BaseTarget
      attr_reader :host, :user, :port, :key_path

      def initialize(host:, user: "ubuntu", port: 22, key_path: nil, **options)
        @host = host.to_s
        @user = user.to_s
        @port = port.to_i
        @key_path = key_path
        super(name: "ssh-#{@user}@#{@host}:#{@port}", **options)
      end

      def target_type
        :ssh
      end

      def preflight_check(_pipeline)
        errors = []
        cmd = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-p", @port.to_s]
        cmd += ["-i", @key_path] if @key_path
        cmd += ["#{@user}@#{@host}", "echo ok"]

        _, _, status = Open3.capture3(*cmd) rescue [nil, nil, nil]
        errors << "Cannot connect via SSH to #{@user}@#{@host}:#{@port}" unless status&.success?

        PreflightResult.new(ok: errors.empty?, errors: errors, warnings: [])
      end

      def build_ssh_command(remote_command)
        cmd = ["ssh", "-p", @port.to_s]
        cmd += ["-i", @key_path] if @key_path
        cmd += ["#{@user}@#{@host}", remote_command]
        cmd
      end

      def execute(pipeline, run_context)
        pre = preflight_check(pipeline)
        unless pre.ok?
          return ExecutionResult.new(
            success: false,
            stdout: "",
            stderr: pre.errors.join("\n"),
            exit_code: 1,
            composite_xml: nil,
            install_failures: []
          )
        end

        tests = pipeline.pts_arguments.join(" ")
        answers = pipeline.batch_input_string.gsub("\n", "\\n")
        remote_script = <<~REMOTE.strip
          export TEST_RESULTS_NAME="#{run_context[:run_id]}"
          printf 'y\\nn\\nn\\nn\\nn\\nn\\nn\\n' | phoronix-test-suite batch-setup
          printf '#{answers}' | phoronix-test-suite batch-benchmark #{tests}
          composite=$(find /var/lib/phoronix-test-suite "$HOME/.phoronix-test-suite" -name composite.xml -print -quit 2>/dev/null || true)
          if [ -n "$composite" ]; then cat "$composite"; fi
        REMOTE

        cmd = build_ssh_command(remote_script)
        stdout, stderr, status = Open3.capture3(*cmd)

        composite_content = stdout.include?("<PhoronixTestSuite>") ? stdout[/(<PhoronixTestSuite>.*<\/PhoronixTestSuite>)/m, 1] : nil

        ExecutionResult.new(
          success: status.success? && !composite_content.nil?,
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          composite_xml: composite_content,
          install_failures: []
        )
      end
    end

    # Deterministic simulated target for validation, testing, and dry-runs.
    class SimulatedTarget < BaseTarget
      attr_reader :mock_results

      def initialize(mock_results: nil, **options)
        @mock_results = mock_results || default_mock_results
        super(name: "simulated-deterministic", **options)
      end

      def target_type
        :simulated
      end

      def preflight_check(_pipeline)
        PreflightResult.new(ok: true, errors: [], warnings: [])
      end

      def execute(pipeline, run_context)
        xml = generate_mock_composite_xml(pipeline, run_context)

        ExecutionResult.new(
          success: true,
          stdout: "Simulated benchmark dispatch completed for #{pipeline.workloads.size} workloads.",
          stderr: "",
          exit_code: 0,
          composite_xml: xml,
          install_failures: []
        )
      end

      private

      def default_mock_results
        {
          "pts/c-ray-2.0.0" => {
            title: "C-Ray",
            description: "1080p, 16 Rays Per Pixel",
            app_version: "2.0",
            arguments: "-s 1920x1080 -r 16",
            scale: "Seconds",
            proportion: "LIB",
            runs: [215.4, 212.1, 213.8]
          },
          "pts/tinymembench-1.0.2" => [
            {
              title: "Tinymembench",
              description: "Standard Memcpy",
              app_version: "2018-05-28",
              arguments: "",
              scale: "MB/s",
              proportion: "HIB",
              runs: [24150.2, 24890.5, 24320.1]
            },
            {
              title: "Tinymembench",
              description: "Standard Memset",
              app_version: "2018-05-28",
              arguments: "",
              scale: "MB/s",
              proportion: "HIB",
              runs: [46200.4, 45980.2, 46150.9]
            }
          ],
          "pts/fio-2.1.0" => {
            title: "Flexible I/O Tester",
            description: "Type: Random Read - IO Engine: Linux AIO - Direct: Yes - Block Size: 4KB",
            app_version: "3.37",
            arguments: "4KB Random Read - Linux AIO - Yes - 1",
            scale: "MB/s",
            proportion: "HIB",
            runs: [1280.5, 1294.2, 1288.7]
          }
        }
      end

      def generate_mock_composite_xml(pipeline, run_context)
        run_date = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
        doc = REXML::Document.new
        doc << REXML::XMLDecl.new("1.0")

        root = doc.add_element("PhoronixTestSuite")
        gen = root.add_element("Generated")
        gen.add_element("Title").text = run_context[:run_id] || "lbh-simulated-dispatch"
        gen.add_element("LastModified").text = run_date
        gen.add_element("TestClient").text = "Phoronix Test Suite v10.8.6"
        gen.add_element("Description").text = "Deterministic simulated benchmark dispatch run."

        sys = root.add_element("System")
        sys.add_element("Identifier").text = "LinuxBenchHub Dispatch Runner"
        sys.add_element("Hardware").text = "Processor: Synthetic Benchmark CPU (4 Cores), Motherboard: LBH Virtual Machine, Memory: 16GB, Disk: 256GB Virtual Disk, Graphics: virtual_drmfb"
        sys.add_element("Software").text = "OS: LinuxBenchHub OS, Kernel: 6.17.0-custom (x86_64), Compiler: GCC 15.2.0, File-System: ext4, System Layer: Pipeline"
        sys.add_element("User").text = "root"
        sys.add_element("TimeStamp").text = run_date
        sys.add_element("TestClientVersion").text = "10.8.6"

        pipeline.workloads.each do |workload|
          test_key = workload.test_identifier
          mock_data = @mock_results[test_key] || fallback_mock_data(workload)
          entries = mock_data.is_a?(Array) ? mock_data : [mock_data]

          entries.each do |entry|
            res = root.add_element("Result")
            res.add_element("Identifier").text = test_key
            res.add_element("Title").text = entry[:title]
            res.add_element("AppVersion").text = entry[:app_version]
            res.add_element("Arguments").text = entry[:arguments]
            res.add_element("Description").text = entry[:description]
            res.add_element("Scale").text = entry[:scale]
            res.add_element("Proportion").text = entry[:proportion]
            res.add_element("DisplayFormat").text = "BAR_GRAPH"

            data_elem = res.add_element("Data")
            entry_elem = data_elem.add_element("Entry")
            entry_elem.add_element("Identifier").text = "Synthetic Benchmark CPU"
            mean_val = entry[:runs].sum / entry[:runs].size
            entry_elem.add_element("Value").text = sprintf("%.1f", mean_val)
            entry_elem.add_element("RawString").text = entry[:runs].join(":")
          end
        end

        output = String.new
        doc.write(output, 2)
        output
      end

      def fallback_mock_data(workload)
        {
          title: workload.name,
          description: workload.description,
          app_version: "1.0",
          arguments: workload.arguments,
          scale: workload.unit,
          proportion: workload.lower_is_better? ? "LIB" : "HIB",
          runs: [100.0, 102.5, 99.8]
        }
      end
    end
  end
end
