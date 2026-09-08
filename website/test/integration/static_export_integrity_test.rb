require "test_helper"

class StaticExportIntegrityTest < ActionDispatch::IntegrationTest
  EXPECTED_PAGES = %w[index.html compare/index.html benchmarks/ubuntu/index.html benchmarks/fedora/index.html benchmarks/debian/index.html].freeze

  test "all public routes export successfully with local links intact" do
    Rails.application.load_tasks
    Rake::Task["export:static"].invoke
    EXPECTED_PAGES.each do |relative_path|
      path = Rails.root.join("export", relative_path)
      assert_path_exists path
      path.read.scan(/(?:href|src)="([^"]+)"/).flatten.each do |asset|
        next unless asset.start_with?("/") && !asset.start_with?("//")
        assert_path_exists Rails.root.join("export", asset.delete_prefix("/")), "#{relative_path} references missing #{asset}"
      end
    end
  end

  test "route table exposes only exported benchmark slugs" do
    assert_equal %w[debian fedora ubuntu], DistroBenchmark::DISTROS.sort
    assert_response :success, get("/")
    assert_response :success, get("/compare")
    DistroBenchmark::DISTROS.each { |slug| assert_response :success, get("/benchmarks/#{slug}") }
    assert_response :not_found, get("/benchmarks/arch")
  end
end
