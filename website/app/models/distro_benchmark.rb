# Parses the per-distro benchmark writeups in benchmarks/<slug>/<slug>.md.
# Mirrors the parsing rules of the static showcase (site/lib/benchmarks.ts)
# so both consumers agree on what the markdown means.
class DistroBenchmark
  DISTROS = %w[ubuntu fedora debian].freeze

  # os_prefix strips the distro's own name off the parsed "OS" spec (e.g.
  # "Fedora Linux 44" -> "44") to get a display version straight from the
  # writeup, so it can't drift out of sync with the actual captured release
  # the way a hardcoded version string would.
  META = {
    "ubuntu" => { name: "Ubuntu", pts: "v10.8.4", os_prefix: /\AUbuntu\s+/ },
    "fedora" => { name: "Fedora", pts: "v10.8.4", os_prefix: /\AFedora Linux\s+/ },
    "debian" => { name: "Debian", pts: "v10.8.5", os_prefix: %r{\ADebian GNU/Linux\s+} }
  }.freeze

  KEY_VALUE_LINE = /^-\s+\*\*(.+?)\*\*:\s*(.*)$/

  SpecPair = Struct.new(:key, :value)
  RunRow = Struct.new(:run, :value)
  Test = Struct.new(:identifier, :title, :description, :app_version, :args,
                    :unit, :runs, :mean, :median, :stddev, keyword_init: true)
  Section = Struct.new(:name, :anchor, :tests, keyword_init: true)

  class << self
    def valid_slug?(slug)
      DISTROS.include?(slug)
    end

    def meta(slug)
      META.fetch(slug)
    end

    def benchmarks_root
      Pathname.new(ENV.fetch("BENCHMARKS_DIR", Rails.root.join("..", "benchmarks").to_s))
    end

    def load(slug)
      new(slug, File.read(benchmarks_root.join(slug, "#{slug}.md")))
    end
  end

  attr_reader :slug, :title, :intro, :hardware, :software, :sections

  def initialize(slug, markdown)
    @slug = slug
    parse(markdown)
  end

  def meta
    self.class.meta(slug)
  end

  # The captured release version (e.g. "26.04 LTS"), read straight off the
  # writeup's own "OS" spec rather than a hardcoded literal.
  def version
    os = software.find { |s| s.key == "OS" }&.value
    return "" unless os

    os.sub(meta[:os_prefix], "").strip
  end

  # Looks up a single parsed test by its Phoronix identifier (e.g.
  # "pts/c-ray-2.0.0"), for pulling a single "headline" stat out of a
  # writeup without the caller needing to know which section it lives in.
  def test(identifier)
    sections.flat_map(&:tests).find { |t| t.identifier == identifier }
  end

  private

  def parse(md)
    @title = md[/^#\s+(.+)$/, 1].to_s.strip
    @intro = md[/^#\s+[^\n]+\n+(.*?)\n+(?=^##\s)/m, 1].to_s.strip
    @hardware = parse_spec_list(md[/### Hardware\s*\n+(.*?)\n+###/m, 1].to_s)
    @software = parse_spec_list(md[/### Software\s*\n+(.*?)\n+---/m, 1].to_s)
    @sections = md.split(/(?=^##\s+)/)
      .select { |s| s.match?(/\A##\s+.*Benchmark/) }
      .map { |s| parse_section(s) }
  end

  def parse_section(section)
    name = section[/\A##\s+(.+)$/, 1].to_s.strip
    blocks = section.split(/(?=### Test Identifier:)/)[1..] || []
    Section.new(name: name, anchor: slugify(name), tests: blocks.map { |b| parse_test(b) })
  end

  def parse_test(block)
    table = block[/### Detailed Run (?:Times|Values)[^\n]*\n+(.*?)(?=\n###|\n---|\z)/m, 1]
    Test.new(
      identifier: block[/### Test Identifier:\s*`?([^`\n]+)`?/, 1].to_s.strip,
      title: block[/#### Title:\s*(.+?)(?:\s+\(test\s+\d+\))?\s*$/, 1].to_s.strip,
      description: find_key_value(block, /\ADescription\z/),
      app_version: find_key_value(block, /\AApp Version\z/),
      args: find_key_value(block, /\AArguments\z/),
      unit: block[/\*\*Mean (?:Time|Value) \(([^)]+)\)\*\*/, 1].to_s,
      runs: table ? parse_table(table) : [],
      mean: find_numeric(block, /\AMean/),
      median: find_numeric(block, /\AMedian/),
      stddev: find_numeric(block, /\AStandard Deviation/)
    )
  end

  def parse_spec_list(text)
    text.each_line.filter_map do |line|
      m = line.match(KEY_VALUE_LINE)
      SpecPair.new(m[1].strip, strip_backticks(m[2].strip)) if m
    end
  end

  def parse_table(text)
    lines = text.lines.select { |l| l.strip.start_with?("|") }
    return [] if lines.length < 3

    lines[2..].filter_map do |line|
      cells = line.split("|").map(&:strip).reject(&:empty?)
      run = Integer(cells[0], exception: false)
      value = Float(cells[1], exception: false)
      RunRow.new(run, value) if run && value
    end
  end

  def find_key_value(block, key_re)
    block.each_line do |line|
      m = line.match(KEY_VALUE_LINE)
      next unless m
      return strip_backticks(m[2].strip) if m[1].match?(key_re)
    end
    ""
  end

  def find_numeric(block, key_re)
    Float(find_key_value(block, key_re), exception: false) || 0.0
  end

  def strip_backticks(s)
    s.sub(/\A`(.*)`\z/, '\1')
  end

  def slugify(s)
    s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(\A-|-\z)/, "")
  end
end
