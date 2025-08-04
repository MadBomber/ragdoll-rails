# frozen_string_literal: true

require 'spec_helper'

begin
  require 'factory_bot_rails'
rescue LoadError
  puts "Warning: factory_bot_rails not available"
end

# Load factories
if defined?(FactoryBot)
  FactoryBot.find_definitions
end

# Configure RSpec for Rails-specific features
RSpec.configure do |config|
  # Include FactoryBot methods if available
  if defined?(FactoryBot)
    config.include FactoryBot::Syntax::Methods
  end

  # Include custom helpers
  config.include RagdollTestHelpers

  # Ensure pgvector extension is available
  config.before(:suite) do
    begin
      if defined?(ActiveRecord::Base) && ActiveRecord::Base.connection_pool.connected?
        ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector")
      end
    rescue => e
      puts "Warning: Could not create vector extension: #{e.message}"
    end
  end
end

# Suppress deprecation warnings in tests
if defined?(ActiveSupport::Deprecation) && ActiveSupport::Deprecation.respond_to?(:behavior=)
  ActiveSupport::Deprecation.behavior = :silence
end

# The models are now provided by the core ragdoll gem
# No need for stub classes anymore

# FactoryBot factories are now properly defined in spec/factories/
# No need for stub implementations

# Stub ActiveJob if not available
unless defined?(ActiveJob)
  module ActiveJob
    module TestHelper
      # Stub methods for testing
    end
  end
end