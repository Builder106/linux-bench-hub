Rails.application.routes.draw do
  root "pages#home"

  get "compare", to: "benchmarks#compare", as: :compare_benchmarks

  get "tests/:test", to: "tests#show", as: :bench_test,
    constraints: { test: /memcpy|memset|c-ray|aircrack-ng/ }

  get "benchmarks/:distro", to: "benchmarks#show", as: :benchmark,
    constraints: { distro: /ubuntu|fedora|debian/ }

  get "up" => "rails/health#show", as: :rails_health_check
end
