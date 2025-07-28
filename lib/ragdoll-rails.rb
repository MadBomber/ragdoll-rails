# frozen_string_literal: true

require_relative "ragdoll/rails"

# This Rails engine requires the ragdoll gem to be available
# The ragdoll gem provides the core business logic functionality
begin
  require 'ragdoll'
rescue LoadError
  raise LoadError, "The ragdoll gem is required for ragdoll-rails to function. Please add 'gem \"ragdoll\"' to your Gemfile."
end