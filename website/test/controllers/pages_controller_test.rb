require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home page renders the showcase sections" do
    get root_url
    assert_response :success
    assert_select ".data-panel .data-row", 4
    assert_select ".hex-tile", 3
    assert_select ".status-panel .status-row", 5
    assert_select ".flowchart svg"
  end
end
