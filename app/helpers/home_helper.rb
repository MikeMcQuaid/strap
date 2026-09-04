# typed: strict
# frozen_string_literal: true

# Helper methods for the home page
module HomeHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  # Custom link helper that always applies the correct Strap primary link styling
  sig { params(text: String, url: String, classes: String).returns(ActiveSupport::SafeBuffer) }
  def strap_link_to(text, url, classes: "")
    classes = "text-blue-600 hover:text-blue-700 hover:underline #{classes}".strip
    link_to(text, url, class: classes)
  end

  # Helper method for primary button styling used across the application
  sig { returns(String) }
  def primary_button_classes
    "inline-block px-2 py-1 text-sm border border-blue-600 text-blue-600 " \
      "hover:bg-blue-600 hover:text-white rounded transition-colors duration-200"
  end

  sig { returns(T.nilable(ActiveSupport::SafeBuffer)) }
  def before_install_list_item
    if (strap_before_install = Rails.application.config.strap_before_install.presence)
      content_tag(:li, sanitize(strap_before_install))
    end
  end

  sig { returns(T.any(String, ActiveSupport::SafeBuffer)) }
  def debugging_text
    if (strap_issues_url = Rails.application.config.strap_issues_url.presence)
      strap_issues_link = strap_link_to(strap_issues_url, strap_issues_url)
      sanitize("file an issue at #{strap_issues_link}")
    else
      "try to debug it yourself"
    end
  end

  sig { params(text: String).returns(ActiveSupport::SafeBuffer) }
  def strap_code_tag(text)
    content_tag(:code, text, class: "font-mono text-sm px-1 text-pink-600")
  end

  sig { returns(ActiveSupport::SafeBuffer) }
  def download_button_text
    safe_join(["Download the ", strap_code_tag("strap.sh"), " script"], "")
  end

  sig { params(authenticated: T::Boolean).returns(T.any(String, ActiveSupport::SafeBuffer)) }
  def login_step(authenticated:)
    return "You authorized Strap on GitHub ✅" if authenticated

    explanation = [
      submit_tag("Authorize Strap on GitHub", class: primary_button_classes),
      " which will prompt for access to your email, public and private repositories; " \
      "you'll need to provide access to any organizations whose repositories you need to be able to ",
      strap_code_tag("git clone"),
      ". This is used to add a GitHub access token to the ",
      strap_code_tag("strap.sh"),
      " script and is not otherwise used by this web application or stored anywhere.",
    ]

    form_tag("/auth/github", method: :post) { safe_join(explanation, "") }
  end

  sig { params(authenticated: T::Boolean).returns(ActiveSupport::SafeBuffer) }
  def download_step(authenticated:)
    download = if authenticated
      link_to(download_button_text, "/strap.sh", class: primary_button_classes)
    else
      download_button_text
    end
    view_link_text = if authenticated
      "view it in your browser"
    else
      "view the uncustomised version in your browser"
    end
    view_link = strap_link_to(view_link_text, "/strap.sh?text=1")

    safe_join([download, " that's been customised for your GitHub user (or ", view_link, " first)."], "")
  end
end
