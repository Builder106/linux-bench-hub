require "test_helper"

class CaptureTest < ActiveSupport::TestCase
  def xml(kernel: "6.17.0-1022-azure (x86_64)", raw: "304.872:304.414:304.554")
    <<~XML
      <?xml version="1.0"?>
      <PhoronixTestSuite>
        <Generated><Title>lbh-fedora-ci-2026-09-01</Title><TestClient>Phoronix Test Suite v10.8.6</TestClient></Generated>
        <System>
          <Hardware>Processor: AMD EPYC 9V74 80-Core (2 Cores / 4 Threads), Motherboard: Microsoft Virtual Machine (Hyper-V UEFI v4.1 BIOS), Memory: 16GB</Hardware>
          <Software>OS: Fedora Linux 44, Kernel: #{kernel}, Compiler: GCC 16.2.1 20260819, File-System: overlayfs, System Layer: Docker</Software>
          <TimeStamp>2026-09-01 11:18:08</TimeStamp>
        </System>
        <Result>
          <Identifier>pts/c-ray-2.0.0</Identifier><Title>C-Ray</Title><AppVersion>2.0</AppVersion>
          <Arguments>-s 1920x1080 -r 16</Arguments><Description>Resolution: 1080p - Rays Per Pixel: 16</Description>
          <Scale>Seconds</Scale><Proportion>LIB</Proportion>
          <Data><Entry><RawString>#{raw}</RawString></Entry></Data>
        </Result>
      </PhoronixTestSuite>
    XML
  end

  test "reads the machine and every run from a composite" do
    capture = Capture.new("fedora", "x86_64", xml)
    assert_equal "lbh-fedora-ci-2026-09-01", capture.title
    assert_equal "10.8.6", capture.pts_version
    assert_equal "AMD EPYC 9V74", capture.cpu
    assert_equal "2 Cores / 4 Threads", capture.threads
    assert_equal "Fedora", capture.name
    assert_equal "44", capture.version
    assert_equal "GCC 16.2.1 20260819", capture.compiler
    assert_equal "Docker", capture.system_layer
    assert_equal Date.new(2026, 9, 1), capture.date
    assert_equal "Microsoft Virtual Machine (Hyper-V UEFI v4.1 BIOS)", capture.hardware["Motherboard"]
    assert_equal "#{Capture::REPO_URL}/blob/main/benchmarks/fedora/composite-latest.xml", capture.xml_url

    result = capture.result_for(BenchTest.find("c-ray"))
    assert_equal [ 304.872, 304.414, 304.554 ], result.runs
    assert result.lower_is_better
    assert_in_delta 304.613, result.mean, 0.001
    assert_in_delta 0.2346, result.stddev, 0.001
    assert_nil capture.result_for(BenchTest.find("memcpy"))
  end

  test "a single run has no spread" do
    result = Capture.new("fedora", "x86_64", xml(raw: "304.5")).results.first
    assert_in_delta 0.0, result.stddev
  end

  test "flags a capture whose kernel does not match its folder" do
    assert_not Capture.new("fedora", "x86_64", xml).misfiled?
    assert Capture.new("fedora", "x86_64", xml(kernel: "6.17.0-1018-oracle (aarch64)")).misfiled?
    assert_not Capture.new("fedora", "arm64", xml(kernel: "6.17.0-1018-oracle (aarch64)")).misfiled?
    assert_not Capture.new("fedora", "x86_64", xml(kernel: "unknown")).misfiled?
  end

  test "loads the six latest captures from the repository" do
    captures = Capture.all
    assert_equal 6, captures.size
    assert_equal %w[ubuntu fedora debian].product(Capture::ARCHES), captures.map { |c| [ c.distro, c.arch ] }
    assert captures.none?(&:misfiled?)
    assert_match %r{/benchmarks/ubuntu-arm64/composite-latest.xml\z}, captures[1].xml_url
  end
end
