# This file is copied to spec/ when you run 'rails generate rspec:install'
# Configure RSpec environment
ENV['RAILS_ENV'] ||= 'test'

# Load the engine first
require File.expand_path('../lib/ragdoll', __dir__)

# Load Rails test environment
begin
  require File.expand_path('../test/dummy/config/environment', __dir__)
  # Ensure we're in test environment
  Rails.env = 'test'
rescue LoadError => e
  puts "Warning: Could not load dummy app environment: #{e.message}"
end

# Load RSpec without rspec-rails to avoid Rails 8 compatibility issues
require 'rspec/core'
require 'rspec/expectations'
require 'rspec/mocks'
require 'database_cleaner/active_record'

# Load support files
Dir[File.expand_path('../spec/support/**/*.rb', __dir__)].each { |f| require f }

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

  # Database Cleaner configuration
  config.before(:suite) do
    if defined?(ActiveRecord::Base)
      begin
        # Try to establish connection to test database
        ActiveRecord::Base.establish_connection(Rails.application.config.database_configuration['test'])
        DatabaseCleaner.strategy = :transaction
        DatabaseCleaner.clean_with(:truncation)
      rescue => e
        puts "Warning: Could not set up database cleaner: #{e.message}"
      end
    end
  end

  config.around(:each) do |example|
    if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
      DatabaseCleaner.cleaning do
        example.run
      end
    else
      example.run
    end
  rescue => e
    puts "Warning: Database cleaner error: #{e.message}"
    example.run
  end
  
  # Configure test environment
  config.before(:each) do
    # Reset Ragdoll configuration
    Ragdoll.instance_variable_set(:@configuration, nil)
    
    # Set test configuration
    Ragdoll.configure do |ragdoll_config|
      ragdoll_config.llm_provider = :openai
      ragdoll_config.embedding_provider = nil
      ragdoll_config.llm_config = {
        openai: { api_key: 'test-key' }
      }
      ragdoll_config.embedding_model = 'text-embedding-3-small'
      ragdoll_config.chunk_size = 500
      ragdoll_config.chunk_overlap = 100
      ragdoll_config.search_similarity_threshold = 0.7
      ragdoll_config.max_search_results = 10
      ragdoll_config.enable_search_analytics = false
    end
  end
end
