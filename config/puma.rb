# frozen_string_literal: true

# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
max_threads_count = ENV.fetch("WEB_CONCURRENCY", 3)
min_threads_count = ENV.fetch("WEB_CONCURRENCY") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Enable tailwindcss live rebuilding in development
plugin :tailwindcss if ENV.fetch("RAILS_ENV", nil) == "development"

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
if (puma_pidfile = ENV.fetch("PUMA_PIDFILE", nil))
  pidfile puma_pidfile
end
