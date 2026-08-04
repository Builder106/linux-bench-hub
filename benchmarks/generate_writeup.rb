#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates benchmarks/<distro>/<distro>.md from benchmarks/<distro>/composite-latest.xml.
#
# The R parsers under benchmarks/<distro>/Parse_composite_*.R print debug text
# and plots, they never wrote this markdown format, so it has no automated
# source. This script is that source: it reads the same composite.xml the R
# parsers and website/app/lib/benchmark_report/parser.rb both consume, and
# emits the spec-list / test-block markdown that parser.rb expects.
#
# Usage: ruby benchmarks/generate_writeup.rb ubuntu fedora debian

require "rexml/document"

def spec_pairs(csv_field)
  csv_field.to_s.split(", ").filter_map do |pair|
    key, value = pair.split(": ", 2)
    next unless key && value
    [key.strip, value.strip]
  end
end

def mean(values)
  values.sum / values.length.to_f
end

def median(values)
  sorted = values.sort
  mid = sorted.length / 2
  sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
end

def sample_stddev(values)
  m = mean(values)
  variance = values.sum { |v| (v - m)**2 } / (values.length - 1).to_f
  Math.sqrt(variance)
end

def fmt(n)
  format("%.3f", n).sub(/0+\z/, "").sub(/\.\z/, ".0")
end

def slugify(s)
  s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
end

# Pads every cell to a consistent column width so the emitted table satisfies
# markdownlint's MD060 (table-column-style), which requires uniform pipe
# spacing across header, delimiter, and data rows.
def build_run_table(scale, raw_values)
  run_header = "Run"
  value_header = "Value (#{scale})"
  formatted = raw_values.map { |v| fmt(v) }
  run_width = [run_header.length, raw_values.length.to_s.length].max
  value_width = [value_header.length, *formatted.map(&:length)].max

  rows = []
  rows << "| #{run_header.ljust(run_width)} | #{value_header.ljust(value_width)} |"
  rows << "| #{"-" * run_width} | #{"-" * value_width} |"
  formatted.each_with_index do |v, i|
    rows << "| #{(i + 1).to_s.ljust(run_width)} | #{v.ljust(value_width)} |"
  end
  rows
end

def build_markdown(distro, doc)
  system_node = doc.elements["PhoronixTestSuite/System"]
  hardware = spec_pairs(system_node.elements["Hardware"]&.text)
  software = spec_pairs(system_node.elements["Software"]&.text)
  os_line = software.find { |k, _| k == "OS" }&.last || distro.capitalize
  system_layer = software.find { |k, _| k == "System Layer" }&.last

  results = doc.get_elements("PhoronixTestSuite/Result")
  groups = results.group_by { |r| r.elements["Title"].text }

  lines = []
  lines << "# #{distro.capitalize} Benchmark Results"
  lines << ""
  lines << "This document provides detailed benchmarking results for #{os_line}, captured monthly by " \
           "LinuxBenchHub's CI pipeline#{system_layer ? " via #{system_layer}" : ""} using the Phoronix Test Suite."
  lines << ""
  lines << "## Table of Contents"
  lines << "1. [System Information](#system-information)"
  groups.keys.each_with_index do |title, i|
    heading = "#{title} Benchmark"
    lines << "#{i + 2}. [#{heading}](##{slugify(heading)})"
  end
  lines << ""
  lines << "## System Information"
  lines << ""
  lines << "### Hardware"
  hardware.each { |k, v| lines << "- **#{k}**: #{v}" }
  lines << ""
  lines << "### Software"
  software.each { |k, v| lines << "- **#{k}**: #{v}" }
  lines << ""
  lines << "---"

  test_number = 0
  groups.each do |title, tests|
    lines << ""
    lines << "## #{title} Benchmark"
    tests.each do |result|
      test_number += 1
      identifier = result.elements["Identifier"].text
      app_version = result.elements["AppVersion"]&.text.to_s
      arguments = result.elements["Arguments"]&.text.to_s
      description = result.elements["Description"]&.text.to_s
      scale = result.elements["Scale"]&.text.to_s
      display_format = result.elements["DisplayFormat"]&.text.to_s
      entry = result.elements["Data/Entry"]
      raw_values = entry.elements["RawString"].text.split(":").map(&:to_f)

      lines << ""
      lines << "### Test Identifier: `#{identifier}` (test #{test_number})"
      lines << ""
      lines << "#### Title: #{title} (test #{test_number})"
      lines << "- **App Version**: #{app_version}"
      lines << "- **Arguments**: `#{arguments}`"
      lines << "- **Description**: #{description}"
      lines << "- **Scale**: #{scale}"
      lines << "- **Display Format**: #{display_format}"
      lines << ""
      lines << "### Data Entries (test #{test_number})"
      lines << "- **Identifier**: #{entry.elements["Identifier"].text}"
      lines << "- **Value (#{scale})**: #{entry.elements["Value"].text}"
      lines << "- **Raw String (#{scale})**: `#{entry.elements["RawString"].text}`"
      lines << ""
      lines << "### Detailed Run Values (test #{test_number})"
      lines << ""
      lines.concat(build_run_table(scale, raw_values))
      lines << ""
      lines << "### Summary Statistics (test #{test_number})"
      lines << "- **Mean Value (#{scale})**: #{fmt(mean(raw_values))}"
      lines << "- **Median Value (#{scale})**: #{fmt(median(raw_values))}"
      lines << "- **Standard Deviation (#{scale})**: #{fmt(sample_stddev(raw_values))}"
    end
    lines << ""
    lines << "---"
  end

  lines.join("\n") + "\n"
end

distros = ARGV.empty? ? %w[ubuntu fedora debian] : ARGV
repo_root = File.expand_path("..", __dir__)

distros.each do |distro|
  xml_path = File.join(repo_root, "benchmarks", distro, "composite-latest.xml")
  md_path = File.join(repo_root, "benchmarks", distro, "#{distro}.md")
  doc = REXML::Document.new(File.read(xml_path))
  File.write(md_path, build_markdown(distro, doc))
  puts "wrote #{md_path}"
end
