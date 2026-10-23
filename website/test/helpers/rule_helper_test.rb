require "test_helper"

class RuleHelperTest < ActionView::TestCase
  include RuleHelper

  test "zoomed scales pad their runs, even when every run is equal" do
    lo, hi = zoom_range([ 300.0, 310.0 ])
    assert_in_delta 298.5, lo
    assert_in_delta 311.5, hi
    lo, hi = zoom_range([ 200.0, 200.0 ])
    assert_in_delta 199.0, lo
    assert_in_delta 201.0, hi
  end

  test "positions and formats run values" do
    assert_equal "50.000", rule_pct(15, 10, 20)
    assert_equal "25,155", run_value(25_154.6)
    assert_equal "304.9", run_value(304.872)
    assert_equal "47.25", run_value(47.25)
  end

  test "labels direction, flip ids and lanes" do
    assert_equal "lower is better", direction(Capture::Result.new(lower_is_better: true))
    assert_equal "higher is better", direction(Capture::Result.new(lower_is_better: false))

    capture = Struct.new(:distro, :arch, :name).new("debian", "arm64", "Debian")
    assert_equal "c-ray-debian-arm64-2", flip_id(BenchTest.find("c-ray"), capture, 2)

    result = Capture::Result.new(runs: [ 237.107, 238.025, 237.961 ], unit: "Seconds")
    assert_equal "Debian arm64: 3 runs from 237.1 to 238.0 Seconds, mean 237.7", lane_summary(capture, result)
  end
end
