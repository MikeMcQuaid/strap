# frozen_string_literal: true

worker_processes (ENV["WEB_CONCURRENCY"] || 3).to_i

# needed to avoid multiple workers from having different session secrets
require "securerandom"
ENV["SESSION_SECRET"] = SecureRandom.hex unless ENV["SESSION_SECRET"]
