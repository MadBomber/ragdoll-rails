# Minimal test configuration that works without dependencies
ENV['RAILS_ENV'] ||= 'test'

# Load basic requirements
require 'rspec/core'
require 'rspec/expectations'
require 'rspec/mocks'

# Load individual components without the full engine
begin
  require File.expand_path('../lib/ragdoll/rails/version', __dir__)
  require File.expand_path('../lib/ragdoll/rails/configuration', __dir__)
  require File.expand_path('../lib/ragdoll/rails', __dir__)
rescue LoadError => e
  puts "Warning: Could not load ragdoll-rails components: #{e.message}"
end

# Load support files
Dir[File.expand_path('../spec/support/**/*.rb', __dir__)].each do |f| 
  begin
    require f
  rescue LoadError => e
    puts "Warning: Could not load support file #{f}: #{e.message}"
  end
end

RSpec.configure do |config|
  # Expectation configuration
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Mock configuration
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Shared context behavior
  config.shared_context_metadata_behavior = :apply_to_host_groups
  
  # Basic test setup
end
