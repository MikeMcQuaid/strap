# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "bootsnap"
gem "faraday-retry"
gem "octokit"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"
gem "puma"
gem "rails", ">= 8"
gem "sorbet-runtime"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails"
  gem "sorbet"
  gem "sorbet-static-and-runtime"
  gem "tapioca", ">= 0.17", require: false
end

group :development do
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rails"
  gem "rubocop-rspec"
  gem "rubocop-rspec_rails"
  gem "rubocop-sorbet"
end
