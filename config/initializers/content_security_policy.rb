# typed: strict
# frozen_string_literal: true

Rails.application.configure do
  config.content_security_policy do |policy|
    # Default policy: only allow content from same origin
    policy.default_src :self

    # Allow local stylesheets with nonces for Rails asset pipeline
    policy.style_src :self

    # Only allow local images (GitHub ribbon is served locally)
    policy.img_src :self

    # Only allow forms to submit to GitHub OAuth (for authentication)
    policy.form_action :self, "https://github.com"

    # Completely disable all other sources for maximum security
    policy.object_src :none
    policy.script_src :none
    policy.font_src   :none
    policy.media_src  :none
    policy.frame_src  :none
    policy.connect_src :none
    policy.base_uri   :none
    policy.worker_src :none
    policy.child_src  :none
    policy.manifest_src :none
  end
end
