require "test_helper"

class BenchTestTest < ActiveSupport::TestCase
  Result = Struct.new(:identifier, :description)

  test "matches results by identifier and, for tinymembench, description" do
    memcpy = BenchTest.find("memcpy")
    assert memcpy.matches?(Result.new("pts/tinymembench-1.0.2", "Standard Memcpy"))
    assert_not memcpy.matches?(Result.new("pts/tinymembench-1.0.2", "Standard Memset"))
    assert BenchTest.find("c-ray").matches?(Result.new("pts/c-ray-2.0.0", "anything"))
    assert_nil BenchTest.find("blender")
  end

  test "steps between tests in plate order" do
    assert_equal %w[memcpy memset c-ray aircrack-ng], BenchTest::SLUGS
    assert_nil BenchTest.find("memcpy").previous
    assert_equal "memset", BenchTest.find("c-ray").previous.slug
    assert_equal "aircrack-ng", BenchTest.find("c-ray").following.slug
    assert_nil BenchTest.find("aircrack-ng").following
  end
end
