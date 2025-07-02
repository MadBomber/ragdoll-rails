# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

# Require Rails and the engine
require File.expand_path('../lib/ragdoll', __dir__)
require 'rspec/rails'
require 'factory_bot_rails'
require 'database_cleaner/active_record'

# Load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Configure RSpec
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # Use transactional fixtures
  config.use_transactional_fixtures = true

  # Infer spec type from file location
  config.infer_spec_type_from_file_location!

  # Filter Rails gems from backtraces
  config.filter_rails_from_backtrace!

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include custom helpers
  config.include RagdollTestHelpers

  # Database Cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
    
    # Ensure pgvector extension is available
    begin
      ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector")
    rescue => e
      puts "Warning: Could not create vector extension: #{e.message}"
    end
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Configure test environment
  config.before(:each) do
    # Reset Ragdoll configuration
    Ragdoll.instance_variable_set(:@configuration, nil)
    
    # Set test configuration
    Ragdoll.configure do |ragdoll_config|
      ragdoll_config.openai_api_key = 'test-key'
      ragdoll_config.embedding_model = 'text-embedding-3-small'
      ragdoll_config.chunk_size = 500
      ragdoll_config.chunk_overlap = 100
      ragdoll_config.search_similarity_threshold = 0.7
      ragdoll_config.max_search_results = 10
      ragdoll_config.enable_search_analytics = false
    end
  end

  # Shared examples and helpers
  config.shared_context_metadata_behavior = :apply_to_host_groups
end

# Suppress deprecation warnings in tests
ActiveSupport::Deprecation.silenced = true