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
    assert_select "table.ledger-table tbody tr", 6 * 5
    assert_select "tr[data-distro='fedora'] .ledger-none", "no runs in lbh-fedora-ci-2026-09-01"
    assert_select ".ledger-runs span", text: "304.872"
    assert_select "td.is-best .best-tag", BenchTest::ALL.size * Capture::ARCHES.size
    assert_select "tr[data-distro='fedora'] td.is-best", text: /\A304\.6 best\z/
  end

  test "the ledger holds both kernel cells and takes each test name from the comb" do
    get compare_benchmarks_url
    Capture::ARCHES.each do |arch|
      assert_select ".ledger-kernels a.hex-kernel[href='/'][data-flip-id='kernel-#{arch}']", 1
    end
    BenchTest::ALL.each do |test|
      assert_select "h2.ledger-name a[href='/tests/#{test.slug}/'] [data-flip-id='name-#{test.slug}']", test.name
      assert_select "table[aria-labelledby='ledger-#{test.slug}']"
    end
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
