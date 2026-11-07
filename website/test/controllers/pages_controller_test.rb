require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home page is two combs, each with one kernel under three distro columns" do
    get root_url
    assert_response :success
    assert_select "h1.home-title", "Same kernel, three userlands."
    assert_select ".comb", 2
    assert_select ".comb .hex-head", 6
    assert_select ".comb a.hex-test", 24
    assert_select ".comb .hex-userland", 6
    assert_select ".comb a.hex-kernel[href='/compare/']", 2
    assert_select ".comb[data-arch='arm64'] a.hex-kernel[data-flip-id='kernel-arm64']"
    assert_select ".comb .comb-lattice [data-ring]", 130
    assert_select "a.hex-test[href='/tests/c-ray/'][data-distro='fedora'].is-best"
    assert_select "a.hex-test[data-test='c-ray'][data-distro='ubuntu'] .hex-gap", "1.6% behind"
    assert_select "a.hex-test[data-test='memcpy'][data-distro='fedora'] strong.hex-value"
    assert_select ".kernel-caption code", "Linux 7.0.0-1017-azure"
    assert_select "footer.colophon", text: /x86_64 runs: AMD EPYC 7763/
  end

  test "home page shows no-runs placeholder when a capture lacks a test" do
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
      get root_url
      assert_select "a.hex-test[data-test='memcpy'][data-distro='fedora'] .hex-none", "no runs"
    end
  end

  test "social preview tags use absolute URLs" do
    get root_url
    assert_select "meta[property='og:url'][content='https://linuxbenchhub.vercel.app/']"
    assert_select "meta[property='og:image'][content='https://linuxbenchhub.vercel.app/social-card.png']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name='twitter:image'][content='https://linuxbenchhub.vercel.app/social-card.png']"
  end
end
