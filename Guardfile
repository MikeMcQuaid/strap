# frozen_string_literal: true

guard "process", name: "foreman", command: "foreman start" do
  watch "config.ru"
  watch "Gemfile.lock"
  watch "web/app.rb"
  watch "web/unicorn.rb"
end
