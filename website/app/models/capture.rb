require "nokogiri"

# One Phoronix Test Suite composite.xml: the machine a capture ran on and every
# run it recorded. This is the site's only data source; the Markdown writeups
# are a manual step the capture workflow never reruns.
class Capture
  ARCHES = %w[x86_64 arm64].freeze
  REPO_URL = "https://github.com/Builder106/linux-bench-hub".freeze

  Result = Struct.new(:identifier, :title, :description, :arguments, :app_version,
                      :unit, :lower_is_better, :raw, :runs, keyword_init: true) do
    def mean = runs.sum / runs.size

    def stddev
      return 0.0 if runs.size < 2

      Math.sqrt(runs.sum { |v| (v - mean)**2 } / (runs.size - 1))
    end
  end

  attr_reader :distro, :arch, :title, :timestamp, :pts_version, :hardware, :software, :results

  class << self
    def benchmarks_root
      Pathname.new(ENV.fetch("BENCHMARKS_DIR", Rails.root.join("..", "benchmarks").to_s))
    end

    def folder(distro, arch) = arch == "arm64" ? "#{distro}-arm64" : distro

    def load(distro, arch)
      path = benchmarks_root.join(folder(distro, arch), "composite-latest.xml")
      new(distro, arch, File.read(path))
    end

    def all
      DistroBenchmark::DISTROS.product(ARCHES).map { |distro, arch| load(distro, arch) }
    end
  end

  def initialize(distro, arch, xml)
    @distro = distro
    @arch = arch
    doc = Nokogiri::XML(xml)
    @title = doc.at_xpath("//Generated/Title").text
    @pts_version = doc.at_xpath("//Generated/TestClient").text.delete_prefix("Phoronix Test Suite v")
    system = doc.at_xpath("//System")
    @timestamp = Time.zone.parse(system.at_xpath("TimeStamp").text)
    @hardware = pairs(system.at_xpath("Hardware").text)
    @software = pairs(system.at_xpath("Software").text)
    @results = doc.xpath("//Result").map { |node| parse_result(node) }
  end

  def name = DistroBenchmark.meta(distro)[:name]
  def processor = hardware.fetch("Processor", "")
  def cpu = processor.sub(/\s+\(.*\)\z/, "").sub(/\s+\d+-Core\z/, "")
  def threads = processor[/\((.*)\)\z/, 1]
  def machine = hardware.fetch("Motherboard", "").sub(/\s+\(.*\)\z/, "")
  def os = software.fetch("OS", "")
  def version = os.sub(meta_prefix, "").strip
  def kernel = software.fetch("Kernel", "")
  def compiler = software.fetch("Compiler", "")
  def system_layer = software.fetch("System Layer", "")
  def date = timestamp.to_date
  def xml_url = "#{REPO_URL}/blob/main/benchmarks/#{self.class.folder(distro, arch)}/composite-latest.xml"

  # The kernel string names the architecture the runs actually used. A
  # capture filed under the wrong folder (as happened in August 2026) shows
  # up here instead of being drawn on the wrong lane silently.
  def misfiled?
    reported = kernel[/\((\w+)\)\z/, 1]
    reported.present? && reported != { "x86_64" => "x86_64", "arm64" => "aarch64" }.fetch(arch)
  end

  def result_for(test) = results.find { |r| test.matches?(r) }

  private

  def meta_prefix = DistroBenchmark.meta(distro)[:os_prefix]

  # "Processor: AMD EPYC 9V74 80-Core (2 Cores / 4 Threads), Motherboard: ..."
  def pairs(text)
    text.scan(/([A-Z][\w\- ]*): (.*?)(?=, [A-Z][\w\- ]*: |\z)/).to_h
  end

  def parse_result(node)
    raw = node.at_xpath("Data/Entry/RawString").text
    Result.new(
      identifier: node.at_xpath("Identifier").text,
      title: node.at_xpath("Title").text,
      description: node.at_xpath("Description").text,
      arguments: node.at_xpath("Arguments").text,
      app_version: node.at_xpath("AppVersion").text,
      unit: node.at_xpath("Scale").text,
      lower_is_better: node.at_xpath("Proportion").text == "LIB",
      raw: raw,
      runs: raw.split(":").map(&:to_f)
    )
  end
end
