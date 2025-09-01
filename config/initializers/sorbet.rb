# typed: strict
# frozen_string_literal: true

# Avoids the need to add `include T::Sig` to every module.
class Module
  include T::Sig
end
