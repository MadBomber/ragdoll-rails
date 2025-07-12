# frozen_string_literal: true

module Ragdoll
  class ImportDirectoryJob < ::ActiveJob::Base
    queue_as :default

    def perform(directory_path, **options)
      Rails.logger.info "Starting ImportDirectoryJob for directory: #{directory_path}"
      
      client = Ragdoll::Rails.client
      results = client.add_directory(directory_path, **options)
      
      success_count = results.count { |r| r[:status] == 'success' }
      error_count = results.count { |r| r[:status] == 'error' }
      
      Rails.logger.info "ImportDirectoryJob completed. Success: #{success_count}, Errors: #{error_count}"
      results
    rescue => e
      Rails.logger.error "ImportDirectoryJob failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Re-raise to trigger job retry mechanisms
      raise e
    end
  end
end