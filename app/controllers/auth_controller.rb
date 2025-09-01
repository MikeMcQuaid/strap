# typed: strict
# frozen_string_literal: true

class AuthController < ApplicationController
  sig { void }
  def github_callback
    auth = request.env.fetch("omniauth.auth")
    session[:auth] = auth.slice("info")
    redirect_to root_path
  end
end
