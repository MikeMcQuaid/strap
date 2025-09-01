# typed: strict
# frozen_string_literal: true

class ScriptController < ApplicationController
  ESCAPED_SINGLE_QUOTE = "\\\\\\\\'"

  sig { void }
  def show
    script_path = Rails.root / "bin/strap.sh"
    content = script_path.read

    set_variables = { STRAP_ISSUES_URL: Rails.application.config.strap_issues_url }
    unset_variables = {}

    if (custom_homebrew_tap = Rails.application.config.custom_homebrew_tap.presence)
      unset_variables[:CUSTOM_HOMEBREW_TAP] = custom_homebrew_tap
    end

    if (custom_brew_command = Rails.application.config.custom_brew_command.presence)
      unset_variables[:CUSTOM_BREW_COMMAND] = custom_brew_command
    end

    if (auth = session[:auth].presence)
      unset_variables.merge! STRAP_GIT_NAME:    auth.dig("info", "name"),
                             STRAP_GIT_EMAIL:   auth.dig("info", "email"),
                             STRAP_GITHUB_USER: auth.dig("info", "nickname")
    end

    env_sub(content, set_variables, set: true)
    env_sub(content, unset_variables, set: false)

    # Manually set X-Frame-Options because Rails won't set it on non-HTML files
    response.headers["X-Frame-Options"] = "DENY"

    content_type = if params[:text] == "1"
      "text/plain"
    else
      "application/octet-stream"
    end

    render plain: content, content_type: content_type
  end

  private

  sig { params(content: String, variables: T::Hash[Symbol, String], set: T::Boolean).void }
  def env_sub(content, variables, set:)
    variables.each do |key, value|
      next if value.blank?

      regex = if set
        /^#{key}='.*'$/
      else
        /^# #{key}=$/
      end
      escaped_value = value.gsub("'", ESCAPED_SINGLE_QUOTE)
      content.gsub!(regex, "#{key}='#{escaped_value}'")
    end
  end
end
