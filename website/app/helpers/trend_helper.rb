module TrendHelper
  # Formats raw metric numbers into human-readable performance display strings.
  def format_metric(val, unit = "")
    return "N/A" if val.nil?

    formatted = val.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    unit.empty? ? formatted : "#{formatted} #{unit}"
  end
end
