# typed: strict
# frozen_string_literal: true

class ScriptController < ApplicationController
  ESCAPED_SINGLE_QUOTE = "\\\\\\\\'"

  sig { void }
  def show
    content = content_with_variables

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

  sig { returns(String) }
  def content_with_variables
    script_path = Rails.root / "bin/strap.sh"
    content = script_path.read

    variables = { STRAP_ISSUES_URL: Rails.application.config.strap_issues_url }

    if (custom_homebrew_tap = Rails.application.config.custom_homebrew_tap.presence)
      variables[:CUSTOM_HOMEBREW_TAP] = custom_homebrew_tap
    end

    if (custom_brew_command = Rails.application.config.custom_brew_command.presence)
      variables[:CUSTOM_BREW_COMMAND] = custom_brew_command
    end

    if (auth = session[:auth].presence)
      variables.merge! STRAP_GIT_NAME:    auth.dig("info", "name"),
                       STRAP_GIT_EMAIL:   auth.dig("info", "email"),
                       STRAP_GITHUB_USER: auth.dig("info", "nickname")
    end

    variables.each do |key, value|
      next if value.blank?

      escaped_value = value.gsub("'", ESCAPED_SINGLE_QUOTE)
      content.gsub!(/^# #{key}=$/, "#{key}='#{escaped_value}'")
    end

    content
  end
end
