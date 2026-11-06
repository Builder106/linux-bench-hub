# frozen_string_literal: true

require "minitest/autorun"
require "rexml/document"
require "open3"
require "tmpdir"
require "fileutils"
require "yaml"

class WorkloadDispatchTest < Minitest::Test
  ROOT = File.expand_path(__dir__)
  SCRIPTS = File.join(ROOT, ".github/scripts")

  def setup
    @dir = Dir.mktmpdir("lbh-dispatch-test")
    @fixture = File.join(@dir, "capture.xml")
    @output = File.join(@dir, "output")
    @log = File.join(@dir, "run-root")
    @document = REXML::Document.new(File.read(File.join(ROOT, "benchmarks/ubuntu/captures/composite-2026-09-01.xml")))
    @document.elements.each("PhoronixTestSuite/Result/Data/Entry/RawString") do |raw|
      raw.text = raw.text.split(":").first(3).join(":")
    end
    %w[read write].each do |operation|
      result = @document.root.add_element("Result")
      {
        "Identifier" => "pts/fio-2.1.0",
        "Arguments" => "#{operation} libaio 1 1m unused 1",
        "Description" => "Type: Sequential #{operation.capitalize} - Engine: Linux AIO - Direct: Yes - Block Size: 1MB - Jobs: 1",
        "Scale" => "MB/s"
      }.each { |name, value| result.add_element(name).text = value }
      entry = result.add_element("Data").add_element("Entry")
      entry.add_element("Value").text = "100"
      entry.add_element("RawString").text = "99:100:101"
    end
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def write_fixture
    File.write(@fixture, @document.to_s)
  end

  def validate
    write_fixture
    Open3.capture3("php", File.join(SCRIPTS, "validate-workloads.php"), @fixture)
  end

  def test_accepts_complete_capture
    stdout, stderr, status = validate
    assert status.success?, stderr
    assert_includes stdout, "Validated CPU, memory bandwidth, and disk I/O"
  end

  def test_rejects_each_missing_metric
    original = @document.to_s
    @document.root.get_elements("Result").each_index do |index|
      @document = REXML::Document.new(original)
      result = @document.root.get_elements("Result")[index]
      @document.root.delete_element(result)
      _stdout, stderr, status = validate
      refute status.success?, "Accepted missing #{result.elements['Description'].text}"
      assert_includes stderr, "Missing workload result"
    end
  end

  def test_rejects_changed_arguments_units_and_sample_counts
    result = @document.root.get_elements("Result").last
    { "Identifier" => "pts/fio-9.9.9", "Arguments" => "write libaio 0 4k unused 1", "Scale" => "IOPS", "Data/Entry/RawString" => "1:2" }.each do |path, bad_value|
      field = result.elements[path]
      original = field.text
      field.text = bad_value
      refute validate.last.success?, "Accepted #{path}=#{bad_value}"
      field.text = original
    end
  end

  def test_rejects_nonpositive_nonfinite_and_nonnumeric_measurements
    entry = @document.root.get_elements("Result").last.elements["Data/Entry"]
    %w[0 -1 NaN Infinity 1e999 broken].each do |value|
      entry.elements["RawString"].text = "99:#{value}:101"
      refute validate.last.success?, "Accepted sample #{value}"
    end
    entry.elements["RawString"].text = "99:100:101"
    entry.elements["Value"].text = "0"
    refute validate.last.success?
  end

  def test_rejects_merged_systems_and_entries
    @document.root.add_element(@document.root.elements["System"].deep_clone)
    refute validate.last.success?
    @document.root.delete_element(@document.root.get_elements("System").last)
    data = @document.root.get_elements("Result").last.elements["Data"]
    data.add_element(data.elements["Entry"].deep_clone)
    refute validate.last.success?
  end

  def test_rejects_missing_and_malformed_xml
    [ nil, "<broken", "<Other/>", "<PhoronixTestSuite/>" ].each do |content|
      File.write(@fixture, content) if content
      _stdout, _stderr, status = Open3.capture3("php", File.join(SCRIPTS, "validate-workloads.php"), @fixture)
      refute status.success?
    end
  end

  def run_dispatch(mode = "complete")
    write_fixture
    fake = File.join(@dir, "phoronix-test-suite")
    File.write(fake, <<~BASH)
      #!/usr/bin/env bash
      set -euo pipefail
      case "$1" in
        batch-setup) cat >/dev/null ;;
        batch-benchmark)
          test "$2" = local/lbh-workloads
          test "$FORCE_TIMES_TO_RUN" = 3
          test -f "$PTS_USER_PATH_OVERRIDE/test-suites/local/lbh-workloads/suite-definition.xml"
          test -f "$PTS_USER_PATH_OVERRIDE/user-config.xml"
          test "$PTS_TEST_INSTALL_ROOT_PATH" = "$PTS_USER_PATH_OVERRIDE"installed-tests/
          grep -F "<ResultsDirectory>$PTS_USER_PATH_OVERRIDE"test-results/ "${PTS_USER_PATH_OVERRIDE}user-config.xml" >/dev/null
          ! read -r unexpected
          printf '%s' "$PTS_USER_PATH_OVERRIDE" > "$FAKE_LOG"
          test "$FAKE_MODE" != failure || exit 17
          if [ "$FAKE_MODE" = missing ]; then
            # A valid but unrelated result must never be selected.
            mkdir -p "$PTS_USER_PATH_OVERRIDE/test-results/stale"
            cp "$FAKE_CAPTURE" "$PTS_USER_PATH_OVERRIDE/test-results/stale/composite.xml"
          else
            mkdir -p "$PTS_USER_PATH_OVERRIDE/test-results/$TEST_RESULTS_NAME"
            cp "$FAKE_CAPTURE" "$PTS_USER_PATH_OVERRIDE/test-results/$TEST_RESULTS_NAME/composite.xml"
          fi ;;
        *) exit 18 ;;
      esac
    BASH
    FileUtils.chmod(0o755, fake)
    Open3.capture3({ "PATH" => "#{@dir}:#{ENV.fetch('PATH')}", "FAKE_CAPTURE" => @fixture,
                    "FAKE_LOG" => @log, "FAKE_MODE" => mode },
                  "bash", File.join(SCRIPTS, "run-workloads.sh"), @output)
  end

  def test_dispatch_publishes_readable_xml_and_cleans_scratch_storage
    _stdout, stderr, status = run_dispatch
    assert status.success?, stderr
    assert_equal File.read(@fixture), File.read(File.join(@output, "composite.xml"))
    assert_equal 0o644, File.stat(File.join(@output, "composite.xml")).mode & 0o777
    refute Dir.exist?(File.read(@log))
    refute Dir.glob(File.join(@output, ".composite.*")).any?
  end

  def test_failed_missing_and_partial_dispatch_preserve_previous_output
    FileUtils.mkdir_p(@output)
    previous = File.join(@output, "composite.xml")
    File.write(previous, "previous capture")
    %w[failure missing partial].each do |mode|
      @document.root.delete_element(@document.root.get_elements("Result").last) if mode == "partial"
      _stdout, stderr, status = run_dispatch(mode)
      refute status.success?, stderr
      assert_equal "previous capture", File.read(previous)
      refute Dir.exist?(File.read(@log))
    end
  end

  def test_all_capture_matrices_have_disk_dependencies_and_share_runner
    workflow = YAML.load_file(File.join(ROOT, ".github/workflows/capture-benchmarks.yml"))
    %w[capture capture-ampere-arm64].each do |job_name|
      job = workflow.fetch("jobs").fetch(job_name)
      matrix = job.fetch("strategy").fetch("matrix").fetch("include")
      assert_equal %w[debian fedora ubuntu], matrix.map { |row| row.fetch("distro") }.sort
      matrix.each { |row| assert_match(/libaio-(dev|devel)\b/, row.fetch("pkg_install")) }
      assert_includes job.fetch("steps").filter_map { |step| step["run"] }.join("\n"), "container-capture.sh"
    end
  end
end
