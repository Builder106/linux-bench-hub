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
    assert_select "a.hex-test[data-test='c-ray'][data-distro='ubuntu'] .hex-gap", "20.2% behind"
    assert_select "a.hex-test[data-test='memcpy'][data-distro='fedora'] .hex-none", "no runs"
    assert_select ".kernel-caption code", "Linux 6.17.0-1022-azure"
    assert_select "footer.colophon", text: /x86_64 runs: AMD EPYC 9V74/
  end
end
