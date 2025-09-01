# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/strap.sh" do
  it "sets X-Frame-Options header" do
    get "/strap.sh"
    expect(response.headers["X-Frame-Options"]).to eq("DENY")
  end
end
