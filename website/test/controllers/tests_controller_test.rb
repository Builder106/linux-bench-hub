require "test_helper"

class TestsControllerTest < ActionDispatch::IntegrationTest
  test "every test pulls its row out of both combs with every run" do
    BenchTest::ALL.each do |test|
      get bench_test_url(test: test.slug)
      assert_response :success
      assert_select "h1.pull-name [data-flip-id='name-#{test.slug}']", test.name
      assert_select ".pull-row", 2
      assert_select ".pull-cells .hex-test", 6
      assert_select ".run-lane", 6
    end
  end

  test "c-ray shows each capture's runs verbatim and steps to its neighbours" do
    get "/tests/c-ray/"
    assert_select ".pull-row[data-arch='x86_64'] .hex-test.is-best[data-distro='fedora']"
    assert_select ".pull-row[data-arch='x86_64'] .run-lane[data-distro='fedora'] .raw", "304.872:304.414:304.554"
    assert_select ".run-lane .band i[data-flip-id='c-ray-fedora-x86_64-0']"
    assert_select ".loupe-steps a[href='/tests/memset/']", "Previous: Memset"
    assert_select ".loupe-steps a[href='/tests/aircrack-ng/']", "Next: Aircrack-ng"
  end

  test "a distro with no runs says which capture lacks them" do
    get "/tests/memcpy/"
    assert_select ".pull-row[data-arch='x86_64'] .run-lane[data-distro='fedora'] .raw-empty", "no runs in lbh-fedora-ci-2026-09-01"
    assert_select ".pull-row[data-arch='x86_64'] .hex-test[data-distro='fedora'] .hex-none", "no runs"
  end
end

class TestsControllerActionTest < ActionController::TestCase
  tests TestsController

  test "rejects an unknown test" do
    assert_raises(ActionController::RoutingError) do
      @controller.instance_variable_set(:@_params, { "test" => "blender" })
      @controller.send(:show)
    end
  end
end
