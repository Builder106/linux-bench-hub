# The comb: flat-top hexes in three columns. The middle column sits half a
# cell higher, so the kernel cell under it touches the bottom cell of every
# column. Rows: 0 distro heads, 1 to 4 tests, 5 userland, 6 the kernel.
module CombHelper
  def comb_cell(col, row) = "--col: #{col}; --row: #{row}; --lift: #{col == 1 ? '0.5' : '0'}"

  # The best mean in a row, honouring whether higher or lower is better.
  def best_mean(results)
    means = results.compact.map(&:mean)
    return nil if means.empty?

    results.compact.first.lower_is_better ? means.min : means.max
  end

  # How far a result trails the best in its row, in plain words.
  def behind(result, best)
    return "best" if result.mean == best

    gap = (result.mean - best).abs / best * 100
    "#{format('%.1f', gap)}% behind"
  end

  def short_compiler(capture) = capture.compiler.sub(/\s+\d{8}\z/, "")
end
