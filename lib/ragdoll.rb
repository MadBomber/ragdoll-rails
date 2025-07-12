# frozen_string_literal: true

require "ragdoll/rails"

module Ragdoll
  # For backward compatibility, delegate main methods to Rails module
  def self.client(options = {})
    Ragdoll::Rails.client(options)
  end

  def self.configuration
    Ragdoll::Core.configuration
  end

  def self.configure(&block)
    Ragdoll::Core.configure(&block)
  end

  # Rails-specific convenience methods
  def self.import_file_async(file_path, **options)
    Ragdoll::Rails.import_file_async(file_path, **options)
  end

  def self.import_directory_async(directory_path, **options)
    Ragdoll::Rails.import_directory_async(directory_path, **options)
  end

  # Delegate search methods to client
  def self.search(query, **options)
    client.search(query, **options)
  end

  def self.enhance_prompt(prompt, **options)
    client.enhance_prompt(prompt, **options)
  end

  def self.add_document(location_or_content, **options)
    client.add_document(location_or_content, **options)
  end

  def self.add_file(file_path, **options)
    client.add_file(file_path, **options)
  end

  def self.add_text(content, title:, **options)
    client.add_text(content, title: title, **options)
  end

  def self.stats
    client.stats
  end

  def self.get_context(query, **options)
    client.get_context(query, **options)
  end

  def self.search_analytics(days: 30)
    client.search_analytics(days: days)
  end

  def self.search_similar_content(query, **options)
    client.search_similar_content(query, **options)
  end
end

# Load models if we're in a Rails context
if defined?(Rails) && defined?(ActiveRecord)
  # Ensure ApplicationRecord is available for our models
  unless defined?(ApplicationRecord)
    # Create a minimal ApplicationRecord for engine testing
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
  
  # Require the models so they're available for testing
  begin
    require File.expand_path('../app/models/ragdoll/document', __dir__)
    require File.expand_path('../app/models/ragdoll/embedding', __dir__)
    require File.expand_path('../app/models/ragdoll/search', __dir__)
  rescue LoadError => e
    # Models couldn't be loaded, continue without them
    puts "Warning: Could not load Ragdoll models: #{e.message}"
  end
end

# Only load Rails-dependent components when in a Rails environment
if defined?(Rails) && defined?(ActiveJob)
  require "ragdoll/import_file_job"
  require "ragdoll/import_directory_job"
else
  # Stub ActiveJob::Base when not in a Rails environment
  unless defined?(ActiveJob)
    module ActiveJob
      class Base; end
    end
  end
end
