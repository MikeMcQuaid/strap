# typed: strict
# frozen_string_literal: true

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
Rails.application.config.filter_parameters += %i[
  passw email secret token _key crypt salt certificate otp ssn cvv cvc
]
