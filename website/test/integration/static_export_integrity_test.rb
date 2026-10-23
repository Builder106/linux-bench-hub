require "test_helper"

class StaticExportIntegrityTest < ActionDispatch::IntegrationTest
  EXPECTED_PAGES = (%w[index.html compare/index.html 404.html] +
    DistroBenchmark::DISTROS.map { |slug| "benchmarks/#{slug}/index.html" } +
    BenchTest::SLUGS.map { |slug| "tests/#{slug}/index.html" }).freeze

  test "all public routes export successfully with local links intact" do
    Rails.application.load_tasks
    Rake::Task["export:static"].invoke
    EXPECTED_PAGES.each do |relative_path|
      path = Rails.root.join("export", relative_path)
      assert_path_exists path
      path.read.scan(/(?:href|src)="([^"]+)"/).flatten.each do |asset|
        next unless asset.start_with?("/") && !asset.start_with?("//")
        target = Rails.root.join("export", asset.delete_prefix("/"))
        target = target.join("index.html") if asset.end_with?("/")
        assert_path_exists target, "#{relative_path} references missing #{asset}"
      end
    end
  end

  test "route table exposes only exported slugs" do
    assert_equal %w[debian fedora ubuntu], DistroBenchmark::DISTROS.sort
    assert_response :success, get("/")
    assert_response :success, get("/compare")
    DistroBenchmark::DISTROS.each { |slug| assert_response :success, get("/benchmarks/#{slug}") }
    BenchTest::SLUGS.each { |slug| assert_response :success, get("/tests/#{slug}/") }
    assert_response :not_found, get("/benchmarks/arch")
    assert_response :not_found, get("/tests/blender")
  end
end
