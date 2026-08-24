# frozen_string_literal: true

require "minitest/autorun"
require "rexml/document"

source = File.read(File.join(__dir__, "benchmarks", "generate_writeup.rb"))
eval(source.split("distros = ARGV.empty?").first, TOPLEVEL_BINDING, "generate_writeup.rb")

class GenerateWriteupTest < Minitest::Test
  def test_spec_pairs_ignores_malformed_entries
    assert_equal [["OS", "Ubuntu"], ["CPU", "Ampere"]], spec_pairs("OS: Ubuntu, broken, CPU: Ampere")
  end

  def test_statistics_and_formatting
    assert_equal 2.0, mean([1.0, 2.0, 3.0])
    assert_equal 2.0, median([1.0, 3.0, 2.0])
    assert_equal 2.5, median([1.0, 2.0, 3.0, 4.0])
    assert_in_delta 1.0, sample_stddev([1.0, 2.0, 3.0]), 0.001
    assert_equal "1.2", fmt(1.2)
    assert_equal "hello-world", slugify("Hello, world!")
  end

  def test_run_table_has_aligned_columns
    rows = build_run_table("MB/s", [1.0, 20.25])
    assert_equal 4, rows.length
    assert rows.all? { |row| row.start_with?("|") && row.end_with?("|") }
  end

  def test_build_markdown_includes_system_and_result_details
    xml = <<~XML
      <PhoronixTestSuite>
        <System><Hardware>CPU: Ampere</Hardware><Software>OS: Ubuntu, System Layer: Docker</Software></System>
        <Result><Title>Speed Test</Title><Identifier>pts/demo</Identifier><AppVersion>1</AppVersion>
          <Arguments>--fast</Arguments><Description>Demo</Description><Scale>MB/s</Scale><DisplayFormat>BAR</DisplayFormat>
          <Data><Entry><Identifier>run-1</Identifier><Value>2</Value><RawString>1:2:3</RawString></Entry></Data>
        </Result>
      </PhoronixTestSuite>
    XML
    output = build_markdown("ubuntu", REXML::Document.new(xml))
    assert_includes output, "# Ubuntu Benchmark Results"
    assert_includes output, "via Docker"
    assert_includes output, "pts/demo"
    assert_includes output, "Standard Deviation"
  end
end
