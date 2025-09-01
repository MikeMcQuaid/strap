# typed: strict
# frozen_string_literal: true

require_relative "boot"

# Only require the Rails components we actually need
require "action_controller/railtie"
require "action_view/railtie"

# These are required for the application to work properly
require "active_support/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Strap
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Configure generators for code generation.
    config.generators.test_framework :rspec,
                                     system_specs:     true,
                                     request_specs:    true,
                                     fixtures:         false,
                                     view_specs:       false,
                                     helper_specs:     false,
                                     routing_specs:    false,
                                     controller_specs: false

    # Secret key base configuration for session signing/encryption
    # SESSION_SECRET used for backwards compatibility with Sinatra version.
    # Generate a secure secret if none provided for multi-worker environments
    config.secret_key_base = ENV["SESSION_SECRET"] ||
                             Rails.application.credentials.secret_key_base ||
                             ENV["SECRET_KEY_BASE"] ||
                             SecureRandom.hex(64)

    # Configure authentication cookie for e.g. GitHub OAuth state.
    config.session_store :cookie_store, key: :_strap_session, secure: Rails.env.production?

    # Strap configuration variables
    config.strap_issues_url = ENV.fetch("STRAP_ISSUES_URL", nil)
    config.strap_before_install = ENV.fetch("STRAP_BEFORE_INSTALL", nil)
    config.custom_homebrew_tap = ENV.fetch("CUSTOM_HOMEBREW_TAP", nil)
    config.custom_brew_command = ENV.fetch("CUSTOM_BREW_COMMAND", nil)
  end
end
