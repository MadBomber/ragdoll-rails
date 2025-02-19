# This file defines the ImportJob class for handling document import tasks in the background.

# frozen_string_literal: true

module Ragdoll
  class ImportJob < SolidJob::Base
    def perform(file)
      document = File.read(file)
      ingestion = Ragdoll::Ingestion.new(document)
      vectorized_chunks = ingestion.chunk_and_vectorize
      ingestion.store_in_database
      puts "Imported #{file} successfully."
    end
  end
end
