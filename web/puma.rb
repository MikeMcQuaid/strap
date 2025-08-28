# frozen_string_literal: true

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma.
max_threads_count = ENV.fetch("WEB_CONCURRENCY", 3)
min_threads_count = ENV.fetch("WEB_CONCURRENCY") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
worker_timeout 3600 if ENV.fetch("RACK_ENV", "development") == "development"

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RACK_ENV", "development")

# Optionally specifies the `pidfile` that Puma will use.
if (puma_pidfile = ENV.fetch("PUMA_PIDFILE", nil))
  pidfile puma_pidfile
end

# needed to avoid multiple workers from having different session secrets
require "securerandom"
ENV["SESSION_SECRET"] = SecureRandom.hex(64) unless ENV["SESSION_SECRET"]
