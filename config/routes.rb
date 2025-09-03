# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#show"

  get "/auth/github/callback", to: "auth#github_callback"
  get "/strap.sh", to: "script#show"

  get :up, to: "rails/health#show", as: :rails_health_check
end
