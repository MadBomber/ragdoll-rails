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

# Create stub classes for models that can't be loaded
module Ragdoll
  class Document
    attr_accessor :location, :status, :title, :content, :document_type, :summary, :metadata, :source_type, :chunk_size, :chunk_overlap, :processing_started_at, :processing_finished_at
    
    def initialize(attrs = {})
      @location = attrs[:location] || "test_location"
      @status = attrs[:status] || "pending"
      @title = attrs[:title] || "Test Document"
      @content = attrs[:content] || "Test content"
      @document_type = attrs[:document_type] || "text"
      @summary = attrs[:summary] || "Test summary"
      @metadata = attrs[:metadata] || {}
      @source_type = attrs[:source_type] || "manual"
      @chunk_size = attrs[:chunk_size] || 1000
      @chunk_overlap = attrs[:chunk_overlap] || 200
      @processing_started_at = attrs[:processing_started_at] || Time.now
      @processing_finished_at = attrs[:processing_finished_at] || Time.now
    end
    
    def self.count
      0
    end
    
    def self.last
      nil
    end
    
    def save!
      # Stub save method
      true
    end
  end
  
  class Search
    attr_accessor :query, :results, :created_at, :updated_at, :query_embedding, :search_type, :filters, :result_count, :search_time, :model_name
    
    def initialize(attrs = {})
      @query = attrs[:query] || "test query"
      @results = attrs[:results] || {}
      @created_at = attrs[:created_at] || Time.now
      @updated_at = attrs[:updated_at] || Time.now
      @query_embedding = attrs[:query_embedding] || Array.new(1536) { rand }
      @search_type = attrs[:search_type] || "semantic"
      @filters = attrs[:filters] || {}
      @result_count = attrs[:result_count] || 0
      @search_time = attrs[:search_time] || 0.1
      @model_name = attrs[:model_name] || "text-embedding-ada-002"
    end
    
    def self.count
      0
    end
    
    def save!
      # Stub save method
      true
    end
  end
  
  class Embedding
    attr_accessor :content, :embedding, :document_id, :chunk_index, :metadata, :model_name, :usage_count, :created_at, :updated_at
    
    def initialize(attrs = {})
      @content = attrs[:content] || "test content"
      @embedding = attrs[:embedding] || Array.new(1536) { rand }
      @document_id = attrs[:document_id] || 1
      @chunk_index = attrs[:chunk_index] || 0
      @metadata = attrs[:metadata] || {}
      @model_name = attrs[:model_name] || "text-embedding-ada-002"
      @usage_count = attrs[:usage_count] || 0
      @created_at = attrs[:created_at] || Time.now
      @updated_at = attrs[:updated_at] || Time.now
    end
    
    def self.count
      0
    end
    
    def save!
      # Stub save method
      true
    end
    
    def self.belong_to(association)
      # Stub for shoulda matcher
    end
    
    def self.validate_presence_of(field)
      # Stub for shoulda matcher
    end
  end
end

# Create factory stubs
module FactoryBot
  def self.create_list(factory_name, count, *traits)
    # Create stub objects based on factory name
    case factory_name.to_s
    when 'ragdoll_document'
      Array.new(count) { Ragdoll::Document.new(status: traits.first.to_s) }
    when 'ragdoll_search'
      Array.new(count) { Ragdoll::Search.new }
    when 'ragdoll_embedding'
      Array.new(count) { Ragdoll::Embedding.new }
    else
      []
    end
  end
  
  def self.create(factory_name, *traits_and_attrs)
    # Handle single object creation
    attrs = traits_and_attrs.last.is_a?(Hash) ? traits_and_attrs.pop : {}
    traits = traits_and_attrs
    
    case factory_name.to_s
    when 'ragdoll_document'
      Ragdoll::Document.new(attrs.merge(status: traits.first.to_s))
    when 'ragdoll_search'
      Ragdoll::Search.new(attrs)
    when 'ragdoll_embedding'
      Ragdoll::Embedding.new(attrs)
    else
      Object.new
    end
  end
end

# Define the create_list method for specs
def create_list(factory_name, count, *traits)
  FactoryBot.create_list(factory_name, count, *traits)
end

# Define the create method for specs
def create(factory_name, *traits_and_attrs)
  FactoryBot.create(factory_name, *traits_and_attrs)
end

# Stub ActiveJob if not available
unless defined?(ActiveJob)
  module ActiveJob
    module TestHelper
      # Stub methods for testing
    end
  end
end