# frozen_string_literal: true

worker_processes (ENV["WEB_CONCURRENCY"] || 3).to_i
