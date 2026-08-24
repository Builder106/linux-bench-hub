require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "formats statistics across display thresholds" do
    assert_equal "—", format_stat(nil)
    assert_equal "—", format_stat(0)
    assert_equal "—", format_stat(Float::NAN)
    assert_equal "1.234", format_stat(1.2345)
    assert_equal "12.34", format_stat(12.345)
    assert_equal "123.4", format_stat(123.45)
    assert_equal "1,235", format_stat(1234.5)
  end

  test "formats chart ticks across display thresholds" do
    assert_equal "1.23", format_tick(1.234)
    assert_equal "12.3", format_tick(12.34)
    assert_equal "123", format_tick(123.4)
    assert_equal "1,235", format_tick(1234.5)
  end

  test "calculates spread and flow geometry" do
    assert_in_delta 50.0, spread_pct(15.0, 10.0, 20.0)
    assert_equal "56.00,0.00 28.00,-48.50 -28.00,-48.50 -56.00,0.00 -28.00,48.50 28.00,48.50", flow_hex_points
    geometry = flow_arrow_geometry(0, 0, 10, 0)
    assert_equal({ ax: 6.0, ay: 0.0, angle: 0.0 }, geometry)
  end
end
