# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/strap.sh" do
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
  let(:env) { { "omniauth.auth" => omniauth_auth } }

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(omniauth_auth)
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  describe "downloading customized script when authenticated" do
    before do
      get "/auth/github/callback", env: env
      follow_redirect!
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
