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
    assert_select ".pull-row[data-arch='x86_64'] .run-lane[data-distro='fedora'] .raw", "352.805:353.344:352.965"
    assert_select ".run-lane .band i[data-flip-id='c-ray-fedora-x86_64-0']"
    assert_select ".loupe-steps a[href='/tests/memset/']", "Previous: Memset"
    assert_select ".loupe-steps a[href='/tests/aircrack-ng/']", "Next: Aircrack-ng"
  end

  test "a distro with no runs says which capture lacks them" do
    incomplete = Capture.new("fedora", "x86_64", <<~XML)
      <?xml version="1.0"?>
      <PhoronixTestSuite>
        <Generated><Title>lbh-fedora-ci-2026-11-01</Title><TestClient>Phoronix Test Suite v10.8.6</TestClient></Generated>
        <System>
          <Hardware>Processor: AMD EPYC 7763 64-Core (2 Cores / 4 Threads), Motherboard: Microsoft Virtual Machine (Hyper-V UEFI v4.1 BIOS), Memory: 16GB</Hardware>
          <Software>OS: Fedora Linux 44, Kernel: 7.0.0-1017-azure (x86_64), Compiler: GCC 16.2.1 20260819, File-System: overlayfs, System Layer: Docker</Software>
          <TimeStamp>2026-11-01 14:01:00</TimeStamp>
        </System>
      </PhoronixTestSuite>
    XML
    mock = Capture.all.map { |c| c.distro == "fedora" && c.arch == "x86_64" ? incomplete : c }
    with_stubbed_captures(mock) do
      get "/tests/memcpy/"
      assert_select ".pull-row[data-arch='x86_64'] .run-lane[data-distro='fedora'] .raw-empty", "no runs in lbh-fedora-ci-2026-11-01"
      assert_select ".pull-row[data-arch='x86_64'] .hex-test[data-distro='fedora'] .hex-none", "no runs"
    end
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
