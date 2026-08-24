require "test_helper"

class TrendHelperTest < ActiveSupport::TestCase
  include TrendHelper

  test "formats missing and present metrics" do
    assert_equal "N/A", format_metric(nil)
    assert_equal "123,456 MB/s", format_metric(123456, "MB/s")
    assert_equal "123,456", format_metric(123456)
  end
end
