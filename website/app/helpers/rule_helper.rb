# Number formatting and the zoomed scale under a test's pulled-out row.
module RuleHelper
  # A test's runs span only their own range, padded so the outermost ticks
  # sit off the ends.
  def zoom_range(values)
    lo, hi = values.minmax
    pad = (hi - lo) * 0.15
    pad = hi * 0.005 if pad.zero?
    [ lo - pad, hi + pad ]
  end

  def rule_pct(value, lo, hi)
    format("%.3f", (value - lo).fdiv(hi - lo) * 100)
  end

  def run_value(value)
    return number_with_delimiter(value.round) if value >= 1000
    return format("%.1f", value) if value >= 100

    format("%.2f", value)
  end

  def direction(result)
    result.lower_is_better ? "lower is better" : "higher is better"
  end

  def flip_id(test, capture, index) = "#{test.slug}-#{capture.distro}-#{capture.arch}-#{index}"

  def lane_summary(capture, result)
    "#{capture.name} #{capture.arch}: #{pluralize(result.runs.size, 'run')} from " \
      "#{run_value(result.runs.min)} to #{run_value(result.runs.max)} #{result.unit}, " \
      "mean #{run_value(result.mean)}"
  end
end
