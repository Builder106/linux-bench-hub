require "test_helper"

class BenchmarksControllerTest < ActionDispatch::IntegrationTest
  test "every distro page lights its own column in both combs" do
    DistroBenchmark::DISTROS.each do |slug|
      get benchmark_url(distro: slug)
      assert_response :success
      assert_select ".combs[data-lit='#{slug}']"
      assert_select "h1.lens-title[data-distro='#{slug}']"
      assert_select ".machine", 2
      assert_select ".warning", 0
    end
  end

  test "the ledger lists every run and names the missing ones" do
    get compare_benchmarks_url
    assert_response :success
    assert_select "table.ledger-table", 5
    assert_select ".ledger-gap", text: /Fedora x86_64 \(lbh-fedora-ci-2026-09-01\) recorded no Memcpy runs/
    assert_select "td.num", text: "304.872"
  end

  test "unknown distro is not routable" do
    assert_raises(ActionController::UrlGenerationError) do
      benchmark_url(distro: "arch")
    end
  end
end

class BenchmarksControllerActionTest < ActionController::TestCase
  tests BenchmarksController

  test "rejects an invalid distro slug" do
    assert_raises(ActionController::RoutingError) do
      @controller.instance_variable_set(:@_params, { "distro" => "arch" })
      @controller.send(:show)
    end
  end
end
