# This file defines the ImportFileJob class for handling individual file import tasks in the background.

# frozen_string_literal: true

module Ragdoll
  class ImportFileJob < ActiveJob::Base
    def perform(file)
      return unless File.file?(file)

      modification_time = File.mtime(file)
      existing_document = Ragdoll::Document.find_by(file: file)

      if existing_document && existing_document.updated_at >= modification_time
        puts "File #{file} is already up-to-date. Skipping import."
        return
      elsif existing_document
        existing_document.destroy
      end

      document = File.read(file)
      ingestion = Ragdoll::Ingestion.new(document)
      vectorized_chunks = ingestion.chunk_and_vectorize
      ingestion.store_in_database(document)
      puts "Imported #{file} successfully."
    end
  end
end
