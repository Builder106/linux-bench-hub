# frozen_string_literal: true

require "pathname"

module LinuxBenchHub
  module HardwareTelemetry
    # Low-overhead reader and analyzer for kernel and hardware counters
    # sourced from /proc/stat, /proc/vmstat, /proc/cpuinfo, and sysfs cpufreq.
    class Counters
      DEFAULT_PROCFS_ROOT = "/proc"
      DEFAULT_SYSFS_ROOT = "/sys"

      attr_reader :procfs_root, :sysfs_root

      def initialize(procfs_root: DEFAULT_PROCFS_ROOT, sysfs_root: DEFAULT_SYSFS_ROOT)
        @procfs_root = Pathname.new(procfs_root)
        @sysfs_root = Pathname.new(sysfs_root)
      end

      # Reads instantaneous hardware counters across procfs and sysfs.
      def read_state
        {
          cpu_stats: read_cpu_stats,
          vm_stats: read_vm_stats,
          cpu_freq: read_cpu_freq
        }
      end

      # Reads CPU ticks and scheduler metrics from /proc/stat.
      def read_cpu_stats
        stat_file = @procfs_root.join("stat")
        return {} unless stat_file.file?

        res = {
          user: 0, nice: 0, system: 0, idle: 0, iowait: 0,
          irq: 0, softirq: 0, steal: 0, guest: 0, guest_nice: 0,
          ctxt: 0, processes: 0, procs_running: 0, procs_blocked: 0
        }

        File.foreach(stat_file) do |line|
          case line
          when /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/
            res[:user] = Regexp.last_match(1).to_i
            res[:nice] = Regexp.last_match(2).to_i
            res[:system] = Regexp.last_match(3).to_i
            res[:idle] = Regexp.last_match(4).to_i
            res[:iowait] = Regexp.last_match(5).to_i
            res[:irq] = Regexp.last_match(6).to_i
            res[:softirq] = Regexp.last_match(7).to_i
            res[:steal] = Regexp.last_match(8).to_i
            res[:guest] = Regexp.last_match(9).to_i
            res[:guest_nice] = Regexp.last_match(10).to_i
          when /^ctxt\s+(\d+)/
            res[:ctxt] = Regexp.last_match(1).to_i
          when /^processes\s+(\d+)/
            res[:processes] = Regexp.last_match(1).to_i
          when /^procs_running\s+(\d+)/
            res[:procs_running] = Regexp.last_match(1).to_i
          when /^procs_blocked\s+(\d+)/
            res[:procs_blocked] = Regexp.last_match(1).to_i
          end
        end

        res
      rescue SystemCallError, IOError
        {}
      end

      # Reads virtual memory counters from /proc/vmstat.
      def read_vm_stats
        vmstat_file = @procfs_root.join("vmstat")
        return {} unless vmstat_file.file?

        res = { pgfault: 0, pgmajfault: 0, pgpgin: 0, pgpgout: 0 }

        File.foreach(vmstat_file) do |line|
          case line
          when /^pgfault\s+(\d+)/
            res[:pgfault] = Regexp.last_match(1).to_i
          when /^pgmajfault\s+(\d+)/
            res[:pgmajfault] = Regexp.last_match(1).to_i
          when /^pgpgin\s+(\d+)/
            res[:pgpgin] = Regexp.last_match(1).to_i
          when /^pgpgout\s+(\d+)/
            res[:pgpgout] = Regexp.last_match(1).to_i
          end
        end

        res
      rescue SystemCallError, IOError
        {}
      end

      # Reads CPU frequencies and governor from /sys/devices/system/cpu/cpufreq
      # with fallback to /proc/cpuinfo.
      def read_cpu_freq
        cpu_path = @sysfs_root.join("devices/system/cpu")
        frequencies = []
        governor = nil

        if cpu_path.directory?
          Dir.glob(cpu_path.join("cpu[0-9]*").to_s).sort.each do |cpu_dir|
            cpufreq_dir = Pathname.new(cpu_dir).join("cpufreq")
            next unless cpufreq_dir.directory?

            freq_raw = read_trimmed_file(cpufreq_dir.join("scaling_cur_freq"))
            frequencies << (freq_raw.to_f / 1000.0).round(1) if freq_raw

            governor ||= read_trimmed_file(cpufreq_dir.join("scaling_governor"))
          end
        end

        if frequencies.empty?
          frequencies = read_cpuinfo_frequencies
        end

        avg_freq = frequencies.empty? ? nil : (frequencies.sum / frequencies.size).round(1)

        {
          cores: frequencies,
          min_mhz: frequencies.min,
          max_mhz: frequencies.max,
          avg_mhz: avg_freq,
          governor: governor || "unknown"
        }
      end

      # Computes counter deltas, per-second rates, and CPU utilization breakdown
      # between initial and final snapshots.
      def compute_delta(initial_snapshot, final_snapshot, duration_seconds)
        dur = [duration_seconds.to_f, 0.001].max
        init_cpu = initial_snapshot.cpu_stats || {}
        fin_cpu = final_snapshot.cpu_stats || {}
        init_vm = initial_snapshot.vm_stats || {}
        fin_vm = final_snapshot.vm_stats || {}

        # Context switches
        ctxt_delta = [0, (fin_cpu[:ctxt] || 0) - (init_cpu[:ctxt] || 0)].max
        ctxt_rate = (ctxt_delta / dur).round(1)

        # Page faults
        pgfault_delta = [0, (fin_vm[:pgfault] || 0) - (init_vm[:pgfault] || 0)].max
        pgfault_rate = (pgfault_delta / dur).round(1)

        pgmajfault_delta = [0, (fin_vm[:pgmajfault] || 0) - (init_vm[:pgmajfault] || 0)].max
        pgmajfault_rate = (pgmajfault_delta / dur).round(1)

        # Process creations (forks)
        procs_delta = [0, (fin_cpu[:processes] || 0) - (init_cpu[:processes] || 0)].max
        procs_rate = (procs_delta / dur).round(1)

        # CPU Utilization Breakdown
        utilization = compute_cpu_utilization(init_cpu, fin_cpu)

        # Frequency metrics
        freq_stats = summarize_frequencies(initial_snapshot.cpu_freq, final_snapshot.cpu_freq)

        # Performance counters (if perf enabled)
        perf_delta = compute_perf_delta(initial_snapshot.perf_counters, final_snapshot.perf_counters, dur)

        {
          context_switches_total: ctxt_delta,
          context_switches_per_sec: ctxt_rate,
          page_faults_total: pgfault_delta,
          page_faults_per_sec: pgfault_rate,
          maj_page_faults_total: pgmajfault_delta,
          maj_page_faults_per_sec: pgmajfault_rate,
          process_forks_total: procs_delta,
          process_forks_per_sec: procs_rate,
          cpu_utilization: utilization,
          frequency_mhz: freq_stats,
          perf_counters: perf_delta
        }
      end

      private

      def read_trimmed_file(path)
        return nil unless path.file?

        File.read(path).strip
      rescue SystemCallError, IOError
        nil
      end

      def read_cpuinfo_frequencies
        cpuinfo = @procfs_root.join("cpuinfo")
        return [] unless cpuinfo.file?

        freqs = []
        File.foreach(cpuinfo) do |line|
          if line =~ /^cpu MHz\s*:\s*([\d.]+)/
            freqs << Regexp.last_match(1).to_f.round(1)
          end
        end
        freqs
      rescue SystemCallError, IOError
        []
      end

      def compute_cpu_utilization(init, fin)
        user_ticks = [0, ((fin[:user] || 0) + (fin[:nice] || 0)) - ((init[:user] || 0) + (init[:nice] || 0))].max
        system_ticks = [0, ((fin[:system] || 0) + (fin[:irq] || 0) + (fin[:softirq] || 0)) -
                           ((init[:system] || 0) + (init[:irq] || 0) + (init[:softirq] || 0))].max
        idle_ticks = [0, (fin[:idle] || 0) - (init[:idle] || 0)].max
        iowait_ticks = [0, (fin[:iowait] || 0) - (init[:iowait] || 0)].max
        steal_ticks = [0, (fin[:steal] || 0) - (init[:steal] || 0)].max

        total_ticks = user_ticks + system_ticks + idle_ticks + iowait_ticks + steal_ticks
        if total_ticks.positive?
          {
            user_pct: ((user_ticks / total_ticks.to_f) * 100.0).round(2),
            system_pct: ((system_ticks / total_ticks.to_f) * 100.0).round(2),
            idle_pct: ((idle_ticks / total_ticks.to_f) * 100.0).round(2),
            iowait_pct: ((iowait_ticks / total_ticks.to_f) * 100.0).round(2),
            steal_pct: ((steal_ticks / total_ticks.to_f) * 100.0).round(2)
          }
        else
          { user_pct: 0.0, system_pct: 0.0, idle_pct: 100.0, iowait_pct: 0.0, steal_pct: 0.0 }
        end
      end

      def summarize_frequencies(init_freq, fin_freq)
        init_f = (init_freq || {}).transform_keys(&:to_sym)
        fin_f = (fin_freq || {}).transform_keys(&:to_sym)

        all_cores = Array(init_f[:cores]) + Array(fin_f[:cores])
        min_mhz = all_cores.empty? ? (fin_f[:min_mhz] || init_f[:min_mhz]) : all_cores.min
        max_mhz = all_cores.empty? ? (fin_f[:max_mhz] || init_f[:max_mhz]) : all_cores.max
        avg_mhz = all_cores.empty? ? (fin_f[:avg_mhz] || init_f[:avg_mhz]) : (all_cores.sum / all_cores.size).round(1)

        {
          min_mhz: min_mhz,
          max_mhz: max_mhz,
          avg_mhz: avg_mhz,
          governor: fin_f[:governor] || init_f[:governor] || "unknown"
        }
      end

      def compute_perf_delta(init_perf, fin_perf, duration)
        return nil if (init_perf || {}).empty? && (fin_perf || {}).empty?

        init = (init_perf || {}).transform_keys(&:to_sym)
        fin = (fin_perf || {}).transform_keys(&:to_sym)

        cycles = [0, (fin[:cycles] || 0) - (init[:cycles] || 0)].max
        instructions = [0, (fin[:instructions] || 0) - (init[:instructions] || 0)].max
        cache_misses = [0, (fin[:cache_misses] || 0) - (init[:cache_misses] || 0)].max
        cache_refs = [0, (fin[:cache_references] || 0) - (init[:cache_references] || 0)].max

        ipc = cycles.positive? ? (instructions.to_f / cycles).round(2) : nil
        cache_miss_rate = cache_refs.positive? ? ((cache_misses.to_f / cache_refs) * 100.0).round(2) : nil

        {
          cycles: cycles,
          instructions: instructions,
          ipc: ipc,
          cache_misses: cache_misses,
          cache_miss_rate_pct: cache_miss_rate,
          cycles_per_sec: (cycles / duration).round(0),
          instructions_per_sec: (instructions / duration).round(0)
        }
      end
    end
  end
end
