class PagesController < ApplicationController
  Benchmark = Struct.new(:name, :test, :unit, :mean, :mean_label, :min, :max,
                         :median, :stddev, keyword_init: true)

  SAMPLE_BENCHMARKS = [
    Benchmark.new(name: "C-Ray", test: "pts/c-ray-2.0.0 · 1080p @ 16 rpp", unit: "Seconds",
                  mean: 1088.787, mean_label: "1,088", min: 767.61, max: 1447.948,
                  median: 1141.11, stddev: 222.509),
    Benchmark.new(name: "Tinymembench memcpy", test: "pts/tinymembench-1.0.2 · standard memcpy",
                  unit: "MB/s", mean: 11209.5, mean_label: "11,210", min: 7012.8,
                  max: 14624.8, median: 11873.6, stddev: 2761.1),
    Benchmark.new(name: "Tinymembench memset", test: "pts/tinymembench-1.0.2 · standard memset",
                  unit: "MB/s", mean: 23480.2, mean_label: "23,480", min: 10140.9,
                  max: 28912.0, median: 25745.6, stddev: 5731.1),
    Benchmark.new(name: "Aircrack-ng", test: "pts/aircrack-ng-1.3.0 · WPA dictionary attack",
                  unit: "k/s", mean: 4542.6, mean_label: "4,542", min: 2832.371,
                  max: 5432.095, median: 4943.083, stddev: 835.1)
  ].freeze

  STACK = [
    { label: "Capture", chips: [ "Phoronix Test Suite", "GitHub Actions", "ubuntu-latest" ] },
    { label: "Analyze", chips: %w[R xml2 dplyr ggplot2 tidyr] },
    { label: "Dashboard", chips: [ "Rails 8.0", "Ruby 3.3", "Hotwire", "Chartkick", "Groupdate", "Bootstrap" ] },
    { label: "Storage", chips: %w[SQLite Puma] },
    { label: "Auth", chips: %w[Devise] },
    { label: "Deploy", chips: %w[Docker Kamal] }
  ].freeze

  # name/version/stat all come from each distro's own writeup (DistroBenchmark
  # #version and #test) so the hex tiles can't drift out of sync with, or lag
  # behind, whatever release was last captured.
  HEADLINE_TEST_IDENTIFIER = "pts/c-ray-2.0.0"

  STATUS_ROWS = [
    { pill: "done", text: "Phoronix benchmark datasets for Ubuntu, Fedora, Debian (x86_64 & arm64)" },
    { pill: "done", text: "Ruby parser pipeline producing markdown writeups from <code>composite.xml</code>" },
    { pill: "done", text: "Monthly CI capture in <code>.github/workflows/capture-benchmarks.yml</code> — committing fresh runs back to <code>benchmarks/</code>" },
    { pill: "done", text: "Rails 8 showcase with static export engine deployed to Vercel (on-demand VM code retired)" },
    { pill: "todo", text: "Cross-distro comparison page & interactive metrics filter" }
  ].freeze

  def home
    @benchmarks = SAMPLE_BENCHMARKS
    @stack = STACK
    @distros = DistroBenchmark::DISTROS.map do |slug|
      parsed = DistroBenchmark.load(slug)
      { slug: slug, name: parsed.meta[:name], version: parsed.version,
        stat: headline_stat(parsed) }
    end
    @status_rows = STATUS_ROWS
  end

  private

  def headline_stat(parsed)
    test = parsed.test(HEADLINE_TEST_IDENTIFIER)
    return nil unless test && test.mean.positive?

    { value: test.mean, unit: test.unit, label: "#{test.title} mean" }
  end
end
