# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/strap.sh" do
  define_method(:app) { Rails.application }

  # Needs to be strings for OmniAuth
  # rubocop:disable Style/StringHashKeys
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
  let(:env) { { "omniauth.auth" => omniauth_auth } }
  # rubocop:enable Style/StringHashKeys

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(omniauth_auth)
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  describe "downloading customized script when authenticated" do
    let(:config_overrides) { {} }

    before do
      get "/auth/github/callback", env: env
      follow_redirect!

      config_overrides.each do |key, value|
        Rails.application.config.public_send("#{key}=", value)
      end

      get "/strap.sh"
    end

    it "returns successful response" do
      expect(last_response.status).to eq(200)
    end

    it "has octet-stream content type" do
      expect(last_response.content_type).to eq("application/octet-stream; charset=utf-8")
    end

    it "includes Bash shebang" do
      expect(last_response.body).to include("#!/bin/bash")
    end

    it "includes Git name variable" do
      expect(last_response.body).to include("STRAP_GIT_NAME='Test User'")
    end

    context "when strap_issues_url is configured" do
      let(:strap_issues_url) { "https://github.com/example/strap/issues" }
      let(:config_overrides) { { strap_issues_url: }                     }

      it "includes custom issues URL" do
        expect(last_response.body).to include(strap_issues_url)
      end
    end

    context "when custom_homebrew_tap is configured" do
      let(:custom_homebrew_tap) { "custom/tap" }
      let(:config_overrides) { { custom_homebrew_tap: } }

      it "includes custom homebrew tap" do
        expect(last_response.body).to include(custom_homebrew_tap)
      end
    end

    context "when custom_brew_command is configured" do
      let(:custom_brew_command) { "install custom-package" }
      let(:config_overrides) { { custom_brew_command: } }

      it "includes custom brew command" do
        expect(last_response.body).to include(custom_brew_command)
      end
    end

    context "when strap_issues_url, custom_homebrew_tap and custom_brew_command are configured" do
      let(:strap_issues_url) { "https://github.com/example/strap/issues" }
      let(:custom_homebrew_tap) { "custom/tap"                                                      }
      let(:custom_brew_command) { "install custom-package"                                          }
      let(:config_overrides)    { { strap_issues_url:, custom_homebrew_tap:, custom_brew_command: } }

      # Want to check all three configurations are present
      # rubocop:disable RSpec/MultipleExpectations
      it "includes all custom configurations" do
        expect(last_response.body).to include(strap_issues_url)
        expect(last_response.body).to include(custom_homebrew_tap)
        expect(last_response.body).to include(custom_brew_command)
      end
      # rubocop:enable RSpec/MultipleExpectations
    end
  end

  describe "viewing script as text when authenticated" do
    before do
      get "/auth/github/callback", env: env
      follow_redirect!
      get "/strap.sh?text=1"
    end

    it "returns successful response" do
      expect(last_response.status).to eq(200)
    end

    it "has text content type" do
      expect(last_response.content_type).to eq("text/plain; charset=utf-8")
    end

    it "includes Bash shebang" do
      expect(last_response.body).to include("#!/bin/bash")
    end

    it "includes customized Git name" do
      expect(last_response.body).to include("STRAP_GIT_NAME='Test User'")
    end
  end

  describe "downloading uncustomized script when not authenticated" do
    before { get "/strap.sh" }

    it "returns successful response" do
      expect(last_response.status).to eq(200)
    end

    it "has octet-stream content type" do
      expect(last_response.content_type).to eq("application/octet-stream; charset=utf-8")
    end

    it "includes Bash shebang" do
      expect(last_response.body).to include("#!/bin/bash")
    end

    it "has commented out Git name" do
      expect(last_response.body).to include("# STRAP_GIT_NAME=")
    end
  end
end
