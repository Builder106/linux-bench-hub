namespace :export do
  desc "Render every page to static HTML + assets in export/, for hosts with no Ruby backend (e.g. Vercel)"
  task static: :environment do
    require "action_dispatch/testing/integration"

    out_dir = Rails.root.join("export")
    FileUtils.rm_rf(out_dir)
    FileUtils.mkdir_p(out_dir)

    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host = "127.0.0.1"

    pages = { "/" => "index.html", "/compare" => "compare/index.html" }
    DistroBenchmark::DISTROS.each do |slug|
      pages["/benchmarks/#{slug}"] = "benchmarks/#{slug}/index.html"
    end

    asset_paths = {}

    pages.each do |route, rel_path|
      session.get(route)
      raise "GET #{route} returned #{session.response.status}" unless session.response.status == 200

      html = session.response.body
      html.scan(%r{(?:href|src)="(/assets/[^"]+)"}).flatten.each { |a| asset_paths[a] = true }

      dest = out_dir.join(rel_path)
      FileUtils.mkdir_p(dest.dirname)
      File.write(dest, html)
      puts "page  #{route.ljust(24)} -> export/#{rel_path}"
    end

    asset_paths.each_key do |asset_path|
      session.get(asset_path)
      raise "GET #{asset_path} returned #{session.response.status}" unless session.response.status == 200

      dest = out_dir.join(asset_path.delete_prefix("/"))
      FileUtils.mkdir_p(dest.dirname)
      File.binwrite(dest, session.response.body)
      puts "asset #{asset_path.ljust(24)} -> export/#{asset_path.delete_prefix('/')}"
    end

    Dir.glob(Rails.root.join("public", "*")).each do |entry|
      FileUtils.cp_r(entry, out_dir)
    end

    puts "\nStatic export written to #{out_dir}"
  end
end
