# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "better_html"
gem "bootsnap"
gem "faraday-retry"
gem "octokit", ">= 10"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"
gem "propshaft"
gem "puma"
gem "rails", ">= 8"
gem "sorbet-runtime"
gem "tailwindcss-rails"

group :development do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "erb_lint", require: false
  gem "rubocop", require: false
  gem "rubocop-capybara", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
  gem "rubocop-sorbet", require: false
  gem "sorbet", require: false
  gem "sorbet-static-and-runtime", require: false
  gem "tapioca", ">= 0.17", require: false
end

group :test do
  gem "rspec-rails", require: false
  gem "simplecov", require: false
end
