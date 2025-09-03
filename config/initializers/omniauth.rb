# typed: strict
# frozen_string_literal: true

# Don't worry: these credentials are not sensitive but just use for
# "Strap (development)" with the URL and callback both set to localhost.
GITHUB_KEY = T.let(
  if Rails.env.production?
    ENV.fetch("GITHUB_KEY")
  else
    ENV.fetch("GITHUB_KEY", "b28d0c47b8925e999e49")
  end,
  String
)
GITHUB_SECRET = T.let(
  if Rails.env.production?
    ENV.fetch("GITHUB_SECRET")
  else
    ENV.fetch("GITHUB_SECRET", "037ac891e2e0b8bc91558d5ff358d2ff4fa1beb7")
  end,
  String
)

# In some configurations, the full host may need to be set to something other
# than the canonical URL.
if (omniauth_full_host = ENV.fetch("OMNIAUTH_FULL_HOST", nil).presence)
  OmniAuth.config.full_host = omniauth_full_host

  # For some reason this needs to be a no-op when using OMNIAUTH_FULL_HOST
  OmniAuth.config.request_validation_phase = nil
end

Rails.application.config.middleware.use OmniAuth::Builder do |builder|
  options = {
    # only need email for embedding in the strap.sh script
    scope:        "user:email",
    allow_signup: false,
  }
  options[:provider_ignores_state] = true if Rails.env.development?
  builder.provider :github, GITHUB_KEY, GITHUB_SECRET, options
end
