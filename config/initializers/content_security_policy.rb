# typed: strict
# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
Rails.application.configure do
  config.content_security_policy do |policy|
    # Default policy: only allow content from same origin
    policy.default_src :self

    # Allow Bootstrap CSS from CDN and any inline styles (needed for GitHub ribbon positioning)
    policy.style_src :self, "https://stackpath.bootstrapcdn.com", :unsafe_inline

    # Allow images from same origin and GitHub ribbon from aral.github.io (HTTP)
    policy.img_src :self, "http://aral.github.io", "https://aral.github.io"

    # Allow connections to GitHub for OAuth and API calls
    policy.connect_src :self, "https://github.com", "https://api.github.com"

    # Allow forms to submit to GitHub OAuth
    policy.form_action :self, "https://github.com"

    policy.object_src :none
    policy.script_src :none
    policy.font_src   :none
    policy.media_src  :none
    policy.frame_src  :none
    policy.base_uri   :none
  end
end
