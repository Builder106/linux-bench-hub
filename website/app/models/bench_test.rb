# The four results every capture records. Tinymembench writes two results
# under one identifier, so a test is matched by identifier and description.
class BenchTest
  attr_reader :slug, :name, :identifier, :description, :summary

  def initialize(slug:, name:, identifier:, summary:, description: nil)
    @slug = slug
    @name = name
    @identifier = identifier
    @description = description
    @summary = summary
  end

  ALL = [
    new(slug: "memcpy", name: "Memcpy", identifier: "pts/tinymembench-1.0.2", description: "Standard Memcpy",
        summary: "Tinymembench copies a block of memory with the C library's memcpy and reports how many megabytes it moved each second."),
    new(slug: "memset", name: "Memset", identifier: "pts/tinymembench-1.0.2", description: "Standard Memset",
        summary: "Tinymembench fills a block of memory with memset and reports how many megabytes it wrote each second."),
    new(slug: "c-ray", name: "C-Ray", identifier: "pts/c-ray-2.0.0",
        summary: "C-Ray ray traces one 1920 by 1080 scene at 16 rays per pixel on every thread and reports how many seconds it took."),
    new(slug: "aircrack-ng", name: "Aircrack-ng", identifier: "pts/aircrack-ng-1.3.0",
        summary: "Aircrack-ng runs its WPA passphrase benchmark and reports how many keys it tested each second.")
  ].freeze

  SLUGS = ALL.map(&:slug).freeze

  def self.find(slug) = ALL.find { |t| t.slug == slug }

  def matches?(result)
    result.identifier == identifier && (description.nil? || result.description == description)
  end

  def position = ALL.index(self)
  def previous
    ALL[position - 1] if position.positive?
  end

  def following = ALL[position + 1]
end
