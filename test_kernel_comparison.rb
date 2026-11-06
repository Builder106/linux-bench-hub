# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "open3"
require "rbconfig"
require_relative "lib/linux_bench_hub/kernel_comparison"

class KernelComparisonTest < Minitest::Test
  Capture = LinuxBenchHub::KernelComparison::Capture
  Engine = LinuxBenchHub::KernelComparison::Engine
  CLI = File.expand_path("bin/lbh-compare-kernels", __dir__)

  def xml(kernel: "6.18.0", arch: "x86_64", cpu: "Example CPU", samples: "100:100:100", proportion: "LIB")
    <<~XML
      <PhoronixTestSuite>
        <Generated><TestClient>Phoronix Test Suite v10.8.4</TestClient></Generated>
        <System>
          <Identifier>host</Identifier>
          <Hardware>Processor: #{cpu}, Motherboard: Board, Memory: 16GB, Disk: 100GB SSD</Hardware>
          <Software>OS: Debian 13, Kernel: #{kernel} (#{arch}), Compiler: GCC 14, File-System: ext4, System Layer: Native</Software>
        </System>
        <Result>
          <Identifier>pts/example-1.0.0</Identifier><AppVersion>1.0</AppVersion>
          <Arguments>--size 16</Arguments><Description>Read</Description>
          <Scale>Seconds</Scale><Proportion>#{proportion}</Proportion>
          <Data><Entry><Identifier>host</Identifier><Value>999</Value><RawString>#{samples}</RawString></Entry></Data>
        </Result>
      </PhoronixTestSuite>
    XML
  end

  def compare(before = xml, after = xml(kernel: "6.19.0"), threshold: 5)
    Engine.new(threshold_percent: threshold).compare(Capture.new(before), Capture.new(after))
  end

  def test_lower_is_better_regression_keeps_raw_evidence_and_ignores_rounded_value
    report = compare(xml(samples: "90:100:110"), xml(kernel: "6.19.0", samples: "110:120:130"))
    assert_equal "regression", report[:status]
    row = report[:metrics].first
    assert_equal "regression", row[:status]
    assert_equal [ 90.0, 100.0, 110.0 ], row[:baseline][:samples]
    assert_equal 100, row[:baseline][:mean]
    assert_equal 3, row[:baseline][:sample_count]
    assert_in_delta 20, row[:delta]
    assert_in_delta 20, row[:change_percent]
    assert_in_delta 20, row[:regression_percent]
    assert_equal({ "regression" => 1 }, report[:summary])
    assert_equal "6.19.0 (x86_64)", report[:candidate][:kernel]
  end

  def test_higher_is_better_regression_and_improvement
    before = xml(proportion: "HIB")
    worse = compare(before, xml(kernel: "6.19.0", samples: "80:80:80", proportion: "HIB"))
    assert_equal "regression", worse[:status]
    assert_in_delta 20, worse[:metrics].first[:regression_percent]
    assert_in_delta(-20, worse[:metrics].first[:change_percent])
    better = compare(before, xml(kernel: "6.19.0", samples: "120:120:120", proportion: "HIB"))
    assert_equal "passed", better[:status]
    assert_equal "improvement", better[:metrics].first[:status]
  end

  def test_lower_is_better_improvement_and_threshold_boundary
    better = compare(xml, xml(kernel: "6.19.0", samples: "80:80:80"))
    assert_equal "improvement", better[:metrics].first[:status]
    [ "95:95:95", "100:100:100", "105:105:105" ].each do |samples|
      report = compare(xml, xml(kernel: "6.19.0", samples: samples))
      assert_equal "passed", report[:status]
      assert_equal "unchanged", report[:metrics].first[:status]
    end
    assert_equal "regression", compare(xml, xml(kernel: "6.19.0", samples: "101"), threshold: 0)[:status]
  end

  def test_different_sample_counts_are_unpaired_traces
    report = compare(xml(samples: "100"), xml(kernel: "6.19.0", samples: "100:100"))
    assert_equal "passed", report[:status]
    assert_equal 1, report[:metrics].first[:baseline][:sample_count]
    assert_equal 2, report[:metrics].first[:candidate][:sample_count]
  end

  def test_metadata_mismatch_never_gets_performance_verdict
    changes = [
      [ "Example CPU", "Other CPU", "hardware" ], [ "16GB", "32GB", "hardware" ],
      [ "100GB SSD", "200GB SSD", "hardware" ], [ "x86_64", "aarch64", "architecture" ],
      [ "Debian 13", "Debian 14", "userland" ], [ "GCC 14", "GCC 15", "userland" ],
      [ "ext4", "overlayfs", "userland" ], [ "Native", "Docker", "userland" ],
      [ "v10.8.4", "v10.8.6", "pts_version" ]
    ]
    changes.each do |old, value, field|
      report = compare(xml, xml(kernel: "6.19.0", samples: "200").sub(old, value))
      assert_equal "incompatible", report[:status], field
      assert_includes report[:incompatibilities], "#{field} differs"
      assert_equal "incomparable", report[:metrics].first[:status]
      refute report[:metrics].first.key?(:change_percent)
    end
    assert_includes compare(xml, xml)[:incompatibilities], "Kernel versions must differ"
  end

  def test_metadata_order_does_not_matter_and_extra_details_are_visible
    after = xml(kernel: "6.19.0").sub("OS: Debian 13, Kernel: 6.19.0 (x86_64)", "Kernel: 6.19.0 (x86_64), OS: Debian 13")
    after = after.sub("</System>", '<JSON>{"kernel-parameters":"changed"}</JSON></System>')
    report = compare(xml, after)
    assert_equal "passed", report[:status]
    assert_equal 2, report[:warnings].size
    assert_includes report[:candidate][:system_details], "kernel-parameters"
  end

  def test_metric_contract_changes_are_added_and_removed
    [
      [ "pts/example-1.0.0", "pts/example-2.0.0" ], [ "<AppVersion>1.0", "<AppVersion>2.0" ],
      [ "--size 16", "--size 32" ], [ "<Description>Read", "<Description>Write" ],
      [ "Seconds", "Milliseconds" ], [ "LIB", "HIB" ]
    ].each do |old, value|
      report = compare(xml, xml(kernel: "6.19.0").sub(old, value))
      assert_equal "partial", report[:status], old
      assert_equal %w[added removed], report[:metrics].map { |r| r[:status] }.sort
      assert report[:metrics].none? { |r| r.key?(:change_percent) }
    end
  end

  def test_submetrics_are_matched_independently_of_result_order
    before = REXML::Document.new(xml)
    copy = before.root.elements["Result"].deep_clone
    copy.elements["Description"].text = "Write"
    before.root.add_element(copy)
    after = REXML::Document.new(before.to_s.sub("6.18.0", "6.19.0"))
    first = after.root.delete_element("Result")
    first.elements["Data/Entry/RawString"].text = "120:120:120"
    after.root.add_element(first)
    report = compare(before.to_s, after.to_s)
    assert_equal({ "regression" => 1, "unchanged" => 1 }, report[:summary])
    assert_equal %w[Read Write], report[:metrics].map { |r| r[:identity]["Description"] }
  end

  def test_partial_trace_still_reports_regressions
    before = REXML::Document.new(xml)
    copy = before.root.elements["Result"].deep_clone
    copy.elements["Description"].text = "Write"
    before.root.add_element(copy)
    report = compare(before.to_s, xml(kernel: "6.19.0", samples: "120"))
    assert_equal "partial", report[:status]
    assert_equal({ "regression" => 1, "removed" => 1 }, report[:summary])
  end

  def test_invalid_samples_are_rejected_without_to_f_coercion
    [ "", "garbage", "100:bad:100", "100:", ":100", "0", "-1", "NaN", "Infinity", "1e309", "1e-9999" ].each do |samples|
      assert_raises(ArgumentError, samples) { Capture.new(xml(samples: samples)) }
    end
  end

  def test_missing_fields_and_ambiguous_captures_are_rejected
    paths = %w[System/Identifier System/Hardware System/Software Generated/TestClient
               Result/Identifier Result/AppVersion Result/Arguments Result/Description
               Result/Scale Result/Proportion Result/Data/Entry/Identifier Result/Data/Entry/RawString Result]
    paths.each do |path|
      doc = REXML::Document.new(xml)
      node = doc.root.elements[path]
      node.parent.delete_element(node)
      assert_raises(ArgumentError, path) { Capture.new(doc.to_s) }
    end
    %w[System Result Result/Data/Entry].each do |path|
      doc = REXML::Document.new(xml)
      node = doc.root.elements[path]
      node.parent.add_element(node.deep_clone)
      assert_raises(ArgumentError, path) { Capture.new(doc.to_s) }
    end
    [
      xml.sub("LIB", "???"), xml.sub(" (x86_64)", ""),
      xml.sub("Processor: Example CPU, ", ""), xml.sub("Memory: 16GB, ", ""),
      xml.sub("Compiler: GCC 14, ", ""), xml.sub("OS: Debian 13, ", ""),
      xml.sub("Kernel: 6.18.0 (x86_64), ", ""),
      xml.sub("16GB", "16GB, Memory: 32GB"),
      xml.sub("<Entry><Identifier>host", "<Entry><Identifier>another-host")
    ].each { |input| assert_raises(ArgumentError) { Capture.new(input) } }
  end

  def test_xml_errors_and_entity_declarations_are_rejected
    [ "", "<broken>", "<Other/>", "<!DOCTYPE PhoronixTestSuite>#{xml}",
     '<!DOCTYPE PhoronixTestSuite [<!ENTITY secret SYSTEM "file:///etc/passwd">]>' + xml ].each do |input|
      assert_raises(ArgumentError) { Capture.new(input) }
    end
  end

  def test_threshold_and_arithmetic_validation
    [ -1, Float::INFINITY, Float::NAN, "bad" ].each do |value|
      assert_raises(ArgumentError) { Engine.new(threshold_percent: value) }
    end
    assert_raises(ArgumentError) { compare(xml(samples: "1e-300"), xml(kernel: "6.19.0", samples: "1e300")) }
    assert_equal "passed", compare(xml(samples: "1e308:1e308"), xml(kernel: "6.19.0", samples: "1e308:1e308"))[:status]
  end

  def test_real_archived_capture_uses_same_contract_and_deterministic_output
    path = File.expand_path("benchmarks/ubuntu/captures/composite-2026-07-01.xml", __dir__)
    baseline = Capture.load(path)
    candidate = Capture.new(File.read(path).sub("6.17.0-1018-azure", "6.17.0-1019-azure"))
    report = Engine.new.compare(baseline, candidate)
    assert_equal "passed", report[:status]
    assert_equal({ "unchanged" => 4 }, report[:summary])
    assert_equal JSON.generate(report), JSON.generate(Engine.new.compare(baseline, candidate))
    assert_equal path, report[:baseline][:path]
  end

  def test_cli_json_and_exit_codes
    Dir.mktmpdir("lbh-kernel-comparison") do |dir|
      before = File.join(dir, "baseline.xml")
      after = File.join(dir, "candidate.xml")
      File.write(before, xml)
      [
        [ xml(kernel: "6.19.0"), 0, "passed" ],
        [ xml(kernel: "6.19.0", samples: "120"), 1, "regression" ],
        [ xml(kernel: "6.19.0", cpu: "Other CPU"), 2, "incompatible" ],
        [ xml(kernel: "6.19.0").sub("--size 16", "--size 32"), 2, "partial" ]
      ].each do |input, code, expected|
        File.write(after, input)
        out, err, status = Open3.capture3(RbConfig.ruby, CLI, before, after)
        assert_equal code, status.exitstatus, err
        assert_empty err
        assert_equal expected, JSON.parse(out).fetch("status")
      end
      File.write(after, xml(kernel: "6.19.0", samples: "120"))
      out, err, status = Open3.capture3(RbConfig.ruby, CLI, "--threshold", "25", before, after)
      assert status.success?, err
      assert_equal 25, JSON.parse(out).fetch("threshold_percent")
      [ [ before ], [ before, "#{dir}/missing" ], [ "--threshold", "-1", before, after ],
       [ "--threshold", "bad", before, after ], [ "--unknown" ] ].each do |args|
        out, err, status = Open3.capture3(RbConfig.ruby, CLI, *args)
        assert_equal 2, status.exitstatus
        assert_empty out
        assert_includes err, "Kernel comparison failed:"
      end
      File.write(after, "<broken>")
      out, err, status = Open3.capture3(RbConfig.ruby, CLI, before, after)
      assert_equal 2, status.exitstatus
      assert_empty out
      refute_empty err
      out, err, status = Open3.capture3(RbConfig.ruby, CLI, "--help")
      assert status.success?
      assert_includes out, "Usage:"
      assert_empty err
      assert_equal xml, File.read(before)
    end
  end
end
