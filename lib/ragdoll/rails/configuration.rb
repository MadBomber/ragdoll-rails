# frozen_string_literal: true

module Ragdoll
  module Rails
    class Configuration
      # Rails-specific configuration options
      attr_accessor :use_background_jobs, :job_queue, :job_adapter, :queue_name, :max_file_size, :allowed_file_types
      
      def initialize
        @use_background_jobs = true
        @job_queue = :default
        @job_adapter = :sidekiq
        @queue_name = :ragdoll
        @max_file_size = 10 * 1024 * 1024 # 10MB
        @allowed_file_types = %w[pdf docx txt md html htm json xml csv]
      end

      def configure_core
        # Delegate to core ragdoll gem configuration
        # This would configure the core ragdoll gem based on Rails-specific settings
      end
    end

  end
end