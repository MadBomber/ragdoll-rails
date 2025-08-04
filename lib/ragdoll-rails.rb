# frozen_string_literal: true

require_relative "ragdoll/rails"

# This Rails engine requires the ragdoll gem to be available
# The ragdoll gem provides the core business logic functionality
begin
  require 'ragdoll'
rescue LoadError => e
  puts "Warning: Could not load ragdoll gem: #{e.message}"
  puts "Please ensure 'gem \"ragdoll\"' is in your Gemfile"
end