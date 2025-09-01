# typed: strict
# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Do not eager load code on boot.
  config.eager_load = false

  # Adds the ServerTiming middleware to the middleware stack.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails dev:cache to toggle Action Controller caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
    config.cache_store = :memory_store
  else
    config.cache_store = :null_store
  end

  # Raise exceptions for deprecations.
  config.active_support.deprecation = :raise

  # Annotate rendered view with template file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true
end
