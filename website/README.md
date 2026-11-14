# LinuxBenchHub Website (Rails 8 Showcase)

This Rails 8 app (`--skip-active-record`) renders LinuxBenchHub's benchmark writeups for Ubuntu, Fedora, and Debian as a static site.

## Architecture

- **Data Source**: `DistroBenchmark` (`app/models/distro_benchmark.rb`) parses the per-distro Markdown writeups under `../benchmarks/<distro>/<distro>.md`.
- **Static Export**: `bin/rails export:static` (`lib/tasks/export.rake`) writes static HTML and compiled assets to `export/`.
- **Deployment**: Deployed directly to Vercel via static export ([`vercel.json`](../vercel.json)).

## Local Development

```bash

# Install dependencies

bundle install

# Run local development server (http://localhost:3000)

bin/rails server

# Run Minitest suite

bundle exec rake test

# Export static site locally

bin/rails export:static
```
