# frozen_string_literal: true

require "ragdoll/version"
require "ragdoll/configuration"
require "ragdoll/engine"

module Ragdoll
  class Error < StandardError; end
  class EmbeddingError < Error; end
  class SearchError < Error; end
  class DocumentError < Error; end
end

require "ragdoll/document_parser"
require "ragdoll/text_chunker"
require "ragdoll/embedding_service"
require "ragdoll/document_type_detector"
require "ragdoll/api"
require "ragdoll/client"
require "ragdoll/ingestion"
require "ragdoll/summarization_service"
# Only load Rails-dependent components when in a Rails environment
if defined?(Rails) && defined?(ActiveJob)
  require "ragdoll/import_file_job"
else
  # Stub ActiveJob::Base when not in a Rails environment
  unless defined?(ActiveJob)
    module ActiveJob
      class Base; end
    end
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
