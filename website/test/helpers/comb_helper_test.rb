require "test_helper"

class CombHelperTest < ActionView::TestCase
  include CombHelper

  Result = Struct.new(:mean, :lower_is_better)

  test "the middle column sits half a cell higher" do
    assert_equal "--col: 0; --row: 3; --lift: 0", comb_cell(0, 3)
    assert_equal "--col: 1; --row: 6; --lift: 0.5", comb_cell(1, 6)
  end

  test "best honours whether lower or higher is better, and skips missing runs" do
    assert_equal 304.6, best_mean([ Result.new(366.1, true), Result.new(304.6, true), nil ])
    assert_equal 8865.0, best_mean([ Result.new(6989.0, false), Result.new(8865.0, false) ])
    assert_nil best_mean([ nil, nil ])
  end

  test "describes how far a result trails the best" do
    assert_equal "best", behind(Result.new(304.6, true), 304.6)
    assert_equal "20.2% behind", behind(Result.new(366.1, true), 304.6)
    assert_equal "21.2% behind", behind(Result.new(6989.0, false), 8865.0)
  end

  test "drops the build date from a compiler string" do
    assert_equal "GCC 16.2.1", short_compiler(Struct.new(:compiler).new("GCC 16.2.1 20260819"))
    assert_equal "GCC 15.2.0", short_compiler(Struct.new(:compiler).new("GCC 15.2.0"))
  end
end
