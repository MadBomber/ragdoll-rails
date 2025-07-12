# frozen_string_literal: true

require 'ragdoll-core'
require_relative 'rails/version'
require_relative 'rails/configuration'
require_relative 'rails/engine'

module Ragdoll
  module Rails
    # Convenience methods for Rails integration
    def self.client(options = {})
      # Ensure ActiveRecord storage is configured
      core_config = Ragdoll::Core.configuration
      if core_config.storage_backend != :activerecord
        core_config.storage_backend = :activerecord
        core_config.storage_config = {
          document_model: Ragdoll::Document,
          embedding_model: Ragdoll::Embedding
        }
      end
      
      Ragdoll::Core.client(options)
    end

    def self.import_file_async(file_path, **options)
      if configuration.use_background_jobs
        Ragdoll::ImportFileJob.perform_later(file_path, **options)
      else
        client.add_file(file_path, **options)
      end
    end

    def self.import_directory_async(directory_path, **options)
      if configuration.use_background_jobs
        Ragdoll::ImportDirectoryJob.perform_later(directory_path, **options)
      else
        client.add_directory(directory_path, **options)
      end
    end
  end
end