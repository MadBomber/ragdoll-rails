# frozen_string_literal: true

module Ragdoll
  module Rails
    class Configuration
      # Rails-specific configuration options
      attr_accessor :use_background_jobs, :job_queue, :job_adapter
      
      def initialize
        @use_background_jobs = true
        @job_queue = :default
        @job_adapter = :sidekiq
      end

      # Configure Ragdoll Core with Rails-specific defaults
      def configure_core
        Ragdoll::Core.configure do |config|
          config.storage_backend = :activerecord
          config.storage_config = {
            document_model: Ragdoll::Document,
            embedding_model: Ragdoll::Embedding
          }
          
          # Use Rails cache for embeddings if available
          if defined?(::Rails) && ::Rails.cache
            config.cache_embeddings = true
          end
          
          # Enable search analytics for Rails apps
          config.enable_search_analytics = true
          config.enable_usage_tracking = true
        end
      end
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
      configuration.configure_core
    end
  end
end