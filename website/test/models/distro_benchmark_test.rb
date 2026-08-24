require "test_helper"

class DistroBenchmarkTest < ActiveSupport::TestCase
  SAMPLE_MD = <<~MD
    # Ubuntu Benchmark Results

    This document provides detailed benchmarking results for Ubuntu.

    ## Table of Contents
    1. [System Information](#system-information)

    ## System Information

    ### Hardware
    - **Processor**: AMD EPYC 9V74 80-Core (2 Cores / 4 Threads)
    - **Memory**: 16GB

    ### Software
    - **OS**: Ubuntu 26.04 LTS
    - **Kernel**: `6.17.0-1018-azure (x86_64)`

    ---

    ## Tinymembench Benchmark

    ### Test Identifier: `pts/tinymembench-1.0.2` (test 1)

    #### Title: Tinymembench (test 1)
    - **App Version**: 2018-05-28
    - **Arguments**: ``
    - **Description**: Standard Memcpy

    ### Detailed Run Values (test 1)

    | Run | Value (MB/s) |
    | --- | ------------ |
    | 1   | 20870.0      |
    | 2   | 22694.8      |

    ### Summary Statistics (test 1)
    - **Mean Value (MB/s)**: 21782.4
    - **Median Value (MB/s)**: 21782.4
    - **Standard Deviation (MB/s)**: 912.4

    ---
  MD

  test "parses title, intro, and spec lists" do
    parsed = DistroBenchmark.new("ubuntu", SAMPLE_MD)
    assert_equal "Ubuntu Benchmark Results", parsed.title
    assert_equal "This document provides detailed benchmarking results for Ubuntu.", parsed.intro
    assert_equal %w[Processor Memory], parsed.hardware.map(&:key)
    assert_equal "6.17.0-1018-azure (x86_64)", parsed.software.last.value
  end

  test "parses benchmark sections with tests and runs" do
    parsed = DistroBenchmark.new("ubuntu", SAMPLE_MD)
    assert_equal 1, parsed.sections.length

    section = parsed.sections.first
    assert_equal "Tinymembench Benchmark", section.name
    assert_equal "tinymembench-benchmark", section.anchor

    test_block = section.tests.first
    assert_equal "pts/tinymembench-1.0.2", test_block.identifier
    assert_equal "Tinymembench", test_block.title
    assert_equal "Standard Memcpy", test_block.description
    assert_equal "MB/s", test_block.unit
    assert_equal [ 1, 2 ], test_block.runs.map(&:run)
    assert_in_delta 21782.4, test_block.mean
    assert_in_delta 912.4, test_block.stddev
  end

  test "loads the real writeups for every distro" do
    DistroBenchmark::DISTROS.each do |slug|
      parsed = DistroBenchmark.load(slug)
      assert parsed.title.present?, "#{slug}: expected a title"
      assert parsed.hardware.any?, "#{slug}: expected hardware specs"
      assert parsed.sections.any?, "#{slug}: expected benchmark sections"
    end
  end

  test "handles missing optional fields and malformed tables" do
    markdown = <<~MD
      # Minimal

      ## Empty Benchmark

      ### Test Identifier: `pts/empty`
      #### Title: Empty

      ### Detailed Run Values
      | Run | Value |
      | --- | --- |
      | bad | nope |
    MD
    parsed = DistroBenchmark.new("ubuntu", markdown)
    test = parsed.sections.first.tests.first

    assert_equal "", parsed.version
    assert_equal "", test.description
    assert_equal "", test.app_version
    assert_equal "", test.args
    assert_equal [], test.runs
    assert_equal 0.0, test.mean
    assert_equal 0.0, test.median
    assert_equal 0.0, test.stddev
  end

  test "handles a table without enough rows" do
    markdown = <<~MD
      # Minimal

      ## Empty Benchmark

      ### Test Identifier: `pts/empty`
      #### Title: Empty

      ### Detailed Run Values
      | Run | Value |
      | --- | --- |
    MD
    parsed = DistroBenchmark.new("ubuntu", markdown)
    assert_empty parsed.sections.first.tests.first.runs
  end

  test "ignores malformed spec lines and tests without a run table" do
    markdown = <<~MD
      # Minimal

      ### Hardware
      not a key value
      ### Software
      not a key value
      ---

      ## Empty Benchmark

      ### Test Identifier: `pts/empty`
      #### Title: Empty
    MD
    parsed = DistroBenchmark.new("ubuntu", markdown)
    assert_empty parsed.hardware
    assert_empty parsed.software
    assert_empty parsed.sections.first.tests.first.runs
  end

  test "returns nil for an unknown test identifier" do
    parsed = DistroBenchmark.new("ubuntu", SAMPLE_MD)
    assert_nil parsed.test("pts/missing")
  end
end
