# frozen_string_literal: true

module Ragdoll
  class ImportFileJob < ::ActiveJob::Base
    queue_as :default

    def perform(file_path, **options)
      Rails.logger.info "Starting ImportFileJob for file: #{file_path}"
      
      client = Ragdoll::Rails.client
      document_id = client.add_file(file_path, **options)
      
      Rails.logger.info "ImportFileJob completed successfully. Document ID: #{document_id}"
      document_id
    rescue => e
      Rails.logger.error "ImportFileJob failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Re-raise to trigger job retry mechanisms
      raise e
    end

  end
end