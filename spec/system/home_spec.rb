# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home" do
  define_method(:app) { Rails.application }

  let(:config_overrides) { {} }

  before do
    config_overrides.each do |key, value|
      Rails.application.config.public_send("#{key}=", value)
    end

    get "/"
  end

  it "returns successful response" do
    expect(last_response.status).to eq(200)
  end

  it "displays the site title" do
    expect(last_response.body).to include("👢 Strap")
  end

  it "shows the site description" do
    expect(last_response.body).to include("Strap is a script to bootstrap a minimal macOS development system")
  end

  it "shows authorization link" do
    expect(last_response.body).to include("Authorize Strap on GitHub")
  end

  it "has GitHub OAuth form action" do
    expect(last_response.body).to include('action="/auth/github"')
  end

  context "when strap_issues_url is configured" do
    let(:strap_issues_url) { "https://github.com/example/strap/issues" }
    let(:config_overrides) { { strap_issues_url: } }

    it "includes custom issues URL in debugging text" do
      expect(last_response.body).to include(strap_issues_url)
    end
  end

  context "when strap_before_install is configured" do
    let(:strap_before_install) { "Run system updates first" }
    let(:config_overrides) { { strap_before_install: } }

    it "displays custom before install instructions" do
      expect(last_response.body).to include(strap_before_install)
    end
  end
end
