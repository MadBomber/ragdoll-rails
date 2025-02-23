# This file defines the ImportFileJob class for handling individual file import tasks in the background.

# frozen_string_literal: true

module Ragdoll
  class ImportFileJob < ActiveJob::Base
    def perform(file)
      return unless File.file?(file)

      # Check if the file is a text file
      if text_file?(file)
        process_text_file(file)
      else
        puts "File #{file} is not a readable text file. Skipping import."
      end
    end

    private

    def text_file?(file)
      # Simple check for text files based on file extension
      %w[.txt .md .csv].include?(File.extname(file).downcase)
    end

    def process_text_file(file)
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
      ingestion.store_in_database(document)
      doc_record = Ragdoll::Document.find_by(file: file)
      doc_record.update(metadata: doc_record.metadata.merge(import_completed_at: Time.current))
      puts "Imported #{file} successfully."
    end
  end
end
