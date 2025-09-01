# typed: true
# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

RSpec.configure do |config|
  # Configure test types based on directory structure
  config.define_derived_metadata(file_path: %r{/spec/system/}) do |metadata|
    metadata[:type] = :system
  end

  config.define_derived_metadata(file_path: %r{/spec/requests/}) do |metadata|
    metadata[:type] = :request
  end

  # Include appropriate test helpers
  config.include Rack::Test::Methods, type: :system
  config.include ActionDispatch::IntegrationTest::Behavior, type: :request
end
