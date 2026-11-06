# frozen_string_literal: true

module LinuxBenchHub
  module WorkloadDispatch
    # Represents a single benchmark workload specification.
    class Workload
      CATEGORIES = %i[cpu memory disk_io].freeze

      attr_reader :id, :name, :category, :test_identifier, :description,
                  :arguments, :unit, :lower_is_better, :interactive_answers,
                  :dependencies, :timeout_seconds

      def initialize(id:, name:, category:, test_identifier:, description:,
                     arguments: "", unit:, lower_is_better: false,
                     interactive_answers: [], dependencies: [], timeout_seconds: 1800)
        unless CATEGORIES.include?(category.to_sym)
          raise ArgumentError, "Invalid category: #{category}. Must be one of #{CATEGORIES.inspect}"
        end

        @id = id.to_s
        @name = name.to_s
        @category = category.to_sym
        @test_identifier = test_identifier.to_s
        @description = description.to_s
        @arguments = arguments.to_s
        @unit = unit.to_s
        @lower_is_better = !!lower_is_better
        @interactive_answers = Array(interactive_answers).map(&:to_s)
        @dependencies = Array(dependencies).map(&:to_s)
        @timeout_seconds = timeout_seconds.to_i
      end

      def lower_is_better?
        @lower_is_better
      end

      # Built-in standard benchmark workloads
      CPU = new(
        id: "cpu-c-ray",
        name: "C-Ray Raytracing",
        category: :cpu,
        test_identifier: "pts/c-ray-2.0.0",
        description: "Multithreaded CPU raytracing performance at 1080p with 16 rays per pixel",
        arguments: "-s 1920x1080 -r 16",
        unit: "Seconds",
        lower_is_better: true,
        interactive_answers: ["1", "16"],
        dependencies: ["build-essential"],
        timeout_seconds: 3600
      )

      MEMORY = new(
        id: "memory-tinymembench",
        name: "Tinymembench Sub-Cache Bandwidth",
        category: :memory,
        test_identifier: "pts/tinymembench-1.0.2",
        description: "Sub-cache memory bandwidth measuring standard memcpy and memset throughput",
        arguments: "",
        unit: "MB/s",
        lower_is_better: false,
        interactive_answers: [],
        dependencies: ["build-essential"],
        timeout_seconds: 3600
      )

      DISK_IO = new(
        id: "disk-fio",
        name: "Flexible I/O Tester",
        category: :disk_io,
        test_identifier: "pts/fio-2.1.0",
        description: "Synchronous and asynchronous random and sequential disk I/O throughput",
        arguments: "4KB Random Read - Linux AIO - Yes - 1",
        unit: "MB/s",
        lower_is_better: false,
        # Answers for PTS fio interactive prompts:
        # 1: Type (Random Read)
        # 1: Engine (Linux AIO)
        # 1: Direct I/O (Yes)
        # 1: Block Size (4KB)
        interactive_answers: ["1", "1", "1", "1"],
        dependencies: %w[build-essential libaio-dev],
        timeout_seconds: 3600
      )

      STANDARD_WORKLOADS = [CPU, MEMORY, DISK_IO].freeze

      STANDARD_TIERS = {
        cpu: CPU,
        memory: MEMORY,
        disk_io: DISK_IO
      }.freeze

      class << self
        def registry
          @registry ||= reset_registry!
        end

        def reset_registry!
          @registry = STANDARD_WORKLOADS.each_with_object({}) { |w, h| h[w.id] = w }
        end

        def register(workload)
          registry[workload.id] = workload
        end

        def all
          registry.values
        end

        def find(id_or_category)
          key = id_or_category.to_s
          registry[key] || all.find { |w| w.category == key.to_sym || w.test_identifier == key }
        end

        def for_category(category)
          cat_sym = category.to_sym
          all.select { |w| w.category == cat_sym }
        end
      end
    end
  end
end
