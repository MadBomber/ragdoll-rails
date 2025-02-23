# This file contains the Ingestion class responsible for processing documents by chunking and vectorizing them.

# frozen_string_literal: true

module Ragdoll
  class Ingestion
    def initialize(document)
      @document = document
    end

    def chunk_and_vectorize
      # Example logic for chunking and vectorization
      chunks = @document.split("\n\n") # Split document into paragraphs
      vectorized_chunks = chunks.map { |chunk| vectorize(chunk) }
      vectorized_chunks
    end

    def store_in_database(document)
      # Store the document in the ragdoll_documents table
      doc_record = Ragdoll::Document.create!(metadata: { name: "Document Name", summary: "Document Summary" }, file: document, updated_at: File.mtime(document))

      # Store each vectorized chunk in the ragdoll_embeddings table
      vectorized_chunks.each do |vector|
        Ragdoll::Embedding.create!(document: doc_record, vector: vector, metadata: { content: "Chunk Content", propositions: "Chunk Propositions" })
      end
    end

    private

    def vectorize(chunk)
      # Placeholder for vectorization logic
      # Convert chunk to a vector representation
      chunk.split.map(&:downcase) # Simple example: split words and downcase
    end
  end
end
