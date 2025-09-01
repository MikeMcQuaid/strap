# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GitHub OAuth" do
  define_method(:app) { Rails.application }

  let(:omniauth_auth) do
    {
      "info"        => {
        "name"     => "Test User",
        "email"    => "test@example.com",
        "nickname" => "testuser",
      },
      "credentials" => {
        "token" => "test_github_token",
      },
    }
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(omniauth_auth)
    get "/auth/github/callback", env: { "omniauth.auth" => omniauth_auth }
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  it "redirects after successful OAuth callback" do
    expect(last_response.status).to eq(302)
  end

  context "when redirected to homepage after successful OAuth callback" do
    before { follow_redirect! }

    it "returns successful response" do
      expect(last_response.status).to eq(200)
    end

    it "shows authenticated state" do
      expect(last_response.body).to include("You authorized Strap on GitHub ✅")
    end

    it "shows script download option" do
      expect(last_response.body).to include("Download the <code>strap.sh</code> script")
    end
  end
end
