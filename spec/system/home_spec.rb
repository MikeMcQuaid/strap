# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home" do
  define_method(:app) { Rails.application }

  before { get "/" }

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
end
