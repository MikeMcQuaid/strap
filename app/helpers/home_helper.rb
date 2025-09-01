# typed: strict
# frozen_string_literal: true

# Helper methods for the home page
# html_safe usage is safe in this file because none of the strings are user-provided
module HomeHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  sig { returns(T.nilable(ActiveSupport::SafeBuffer)) }
  def before_install_list_item
    if (strap_before_install = Rails.application.config.strap_before_install.presence)
      content_tag(:li, sanitize(strap_before_install))
    end
  end

  sig { returns(T.any(String, ActiveSupport::SafeBuffer)) }
  def debugging_text
    if (strap_issues_url = Rails.application.config.strap_issues_url.presence)
      strap_issues_link = link_to(strap_issues_url, strap_issues_url)
      sanitize("file an issue at #{strap_issues_link}")
    else
      "try to debug it yourself"
    end
  end

  sig { returns(ActiveSupport::SafeBuffer) }
  def strap_sh_code = content_tag(:code, "strap.sh")

  # None of the below methods return user-provided strings,
  # so we can safely use html_safe.
  # rubocop:disable Rails/OutputSafety
  sig { returns(ActiveSupport::SafeBuffer) }
  def download_button_text = "Download the #{strap_sh_code} script".html_safe

  sig { params(authenticated: T::Boolean).returns(ActiveSupport::SafeBuffer) }
  def login_step(authenticated:)
    return "You authorized Strap on GitHub ✅".html_safe if authenticated

    form_tag("/auth/github", method: :post) do
      authorize_button = submit_tag("Authorize Strap on GitHub", class: "btn btn-outline-primary btn-sm")
      git_clone_code = content_tag(:code, "git clone")

      <<~HTML.html_safe
        #{authorize_button}
        which will prompt for access to your email, public and private repositories;
        you'll need to provide access to any organizations whose repositories you need to be able to
        #{git_clone_code}.
        This is used to add a GitHub access token to the #{strap_sh_code}
        script and is not otherwise used by this web application or stored anywhere.
      HTML
    end
  end

  sig { params(authenticated: T::Boolean).returns(ActiveSupport::SafeBuffer) }
  def download_step(authenticated:)
    if authenticated
      download_button = link_to(download_button_text, "/strap.sh", class: "btn btn-outline-primary btn-sm")
      view_link = link_to("view it in your browser", "/strap.sh?text=1")

      "#{download_button} that's been customised for your GitHub user (or #{view_link} first)."
    else
      view_link = link_to("view the uncustomised version in your browser", "/strap.sh?text=1")
      "#{download_button_text} that's been customised for your GitHub user (or #{view_link} first)."
    end.html_safe
  end
  # rubocop:enable Rails/OutputSafety
end
