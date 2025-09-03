# typed: strict
# frozen_string_literal: true

better_html_config_file = Rails.root / ".better-html.yml"
better_html_config_yml = YAML.load_file(better_html_config_file, permitted_classes: [Regexp])
BetterHtml.config = BetterHtml::Config.new(better_html_config_yml)
