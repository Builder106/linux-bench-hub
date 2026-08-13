# LinuxBenchHub Website (Rails 8 Showcase)

The web showcase for **LinuxBenchHub** &mdash; a static showcase app built with Rails 8 (`--skip-active-record`) that renders benchmark writeups for Ubuntu, Fedora, and Debian.

## Architecture

- **Data Source**: Parses per-distro markdown writeups located under `../benchmarks/<distro>/<distro>.md`via`DistroBenchmark` (`app/models/distro_benchmark.rb`).
- **Static Export**: Generates static HTML and compiled assets into `export/`via`bin/rails export:static` (`lib/tasks/export.rake`).
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
