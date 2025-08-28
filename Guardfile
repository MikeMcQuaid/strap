# frozen_string_literal: true

guard "process", name: "server", command: "script/server" do
  watch "config.ru"
  watch "Gemfile.lock"
  watch "web/app.rb"
  watch "web/puma.rb"
end
