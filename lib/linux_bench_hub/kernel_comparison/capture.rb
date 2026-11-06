# frozen_string_literal: true

require "rexml/document"

module LinuxBenchHub
  module KernelComparison
    # Strict reader for the existing single-system PTS sample-trace contract.
    class Capture
      IDENTITY_FIELDS = %w[Identifier AppVersion Arguments Description Scale Proportion].freeze
      attr_reader :metadata, :metrics

      def self.load(path)
        new(File.read(path), path: path.to_s)
      end

      def initialize(xml, path: nil)
        # PTS captures do not need DTDs or entities, including external entities.
        raise ArgumentError, "DTD and entity declarations are unsupported" if xml.match?(/<!\s*(?:DOCTYPE|ENTITY)\b/i)

        doc = REXML::Document.new(xml)
        root = doc.root
        raise ArgumentError, "Expected PhoronixTestSuite root" unless root&.name == "PhoronixTestSuite"
        systems = root.get_elements("System")
        raise ArgumentError, "Expected exactly one system" unless systems.size == 1

        system = systems.first
        system_id = required(system, "Identifier")
        hardware = pairs(required(system, "Hardware"))
        %w[Processor Memory].each do |field|
          raise ArgumentError, "Missing hardware #{field}" if hardware.fetch(field, "").empty?
        end
        software = pairs(required(system, "Software"))
        %w[OS Kernel Compiler].each do |field|
          raise ArgumentError, "Missing software #{field}" if software.fetch(field, "").empty?
        end
        kernel = software.delete("Kernel")
        arch = kernel[/\(([^()]+)\)\z/, 1]
        raise ArgumentError, "Kernel must record architecture in parentheses" unless arch

        @metadata = {
          path: path, kernel: kernel, architecture: arch, hardware: hardware,
          userland: software, pts_version: required(root, "Generated/TestClient"),
          system_details: system.elements["JSON"]&.text.to_s.strip
        }
        @metrics = root.get_elements("Result").each_with_object({}) do |node, metrics|
          IDENTITY_FIELDS.each do |field|
            raise ArgumentError, "Missing metric #{field}" unless node.elements[field]
          end
          identity = IDENTITY_FIELDS.to_h { |field| [ field, node.elements[field]&.text.to_s.strip ] }
          %w[Identifier AppVersion Scale Proportion].each { |field| required(node, field) }
          unless %w[LIB HIB].include?(identity.fetch("Proportion"))
            raise ArgumentError, "Unsupported metric proportion"
          end
          key = identity.values
          raise ArgumentError, "Duplicate metric: #{key.inspect}" if metrics.key?(key)
          entries = node.get_elements("Data/Entry")
          raise ArgumentError, "Expected one data entry per metric" unless entries.size == 1
          unless required(entries.first, "Identifier") == system_id
            raise ArgumentError, "Metric entry does not match capture system"
          end

          samples = required(entries.first, "RawString").split(":", -1).map do |value|
            number = Float(value.strip)
            raise ArgumentError, "Samples must be finite and positive" unless number.finite? && number.positive?
            number
          end
          # Divide first to avoid overflowing a finite mean during summation.
          mean = samples.sum { |value| value / samples.size }
          raise ArgumentError, "Non-finite sample mean" unless mean.finite? && mean.positive?
          metrics[key] = { identity: identity, samples: samples, mean: mean, sample_count: samples.size }
        end
        raise ArgumentError, "Capture contains no metrics" if @metrics.empty?
      rescue REXML::ParseException => e
        raise ArgumentError, "Invalid PTS XML: #{e.message.lines.first.to_s.strip}"
      end

      private

      def required(node, field)
        value = node.elements[field]&.text.to_s.strip
        raise ArgumentError, "Missing #{field}" if value.empty?
        value
      end

      def pairs(text)
        entries = text.scan(/([A-Z][\w\- ]*): (.*?)(?=, [A-Z][\w\- ]*: |\z)/)
        raise ArgumentError, "Duplicate metadata field" unless entries.map(&:first).uniq.size == entries.size
        entries.to_h
      end
    end
  end
end
