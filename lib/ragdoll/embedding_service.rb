# frozen_string_literal: true

require 'openai'

module Ragdoll
  class EmbeddingService
    class EmbeddingError < Error; end

    def initialize(client: nil)
      @client = client || OpenAI::Client.new(access_token: Ragdoll.configuration.openai_api_key)
    end

    def generate_embedding(text)
      return nil if text.blank?

      # Clean and prepare text
      cleaned_text = clean_text(text)
      
      begin
        response = @client.embeddings(
          parameters: {
            model: Ragdoll.configuration.embedding_model,
            input: cleaned_text
          }
        )

        if response['data'] && response['data'].first && response['data'].first['embedding']
          response['data'].first['embedding']
        else
          raise EmbeddingError, "Invalid response format from OpenAI API"
        end

      rescue Faraday::Error => e
        raise EmbeddingError, "Network error generating embedding: #{e.message}"
      rescue JSON::ParserError => e
        raise EmbeddingError, "Invalid JSON response from OpenAI API: #{e.message}"
      rescue => e
        raise EmbeddingError, "Failed to generate embedding: #{e.message}"
      end
    end

    def generate_embeddings_batch(texts)
      return [] if texts.empty?

      # Clean all texts
      cleaned_texts = texts.map { |text| clean_text(text) }.reject(&:blank?)
      return [] if cleaned_texts.empty?

      begin
        response = @client.embeddings(
          parameters: {
            model: Ragdoll.configuration.embedding_model,
            input: cleaned_texts
          }
        )

        if response['data']
          response['data'].map { |item| item['embedding'] }
        else
          raise EmbeddingError, "Invalid response format from OpenAI API"
        end

      rescue Faraday::Error => e
        raise EmbeddingError, "Network error generating embeddings: #{e.message}"
      rescue JSON::ParserError => e
        raise EmbeddingError, "Invalid JSON response from OpenAI API: #{e.message}"
      rescue => e
        raise EmbeddingError, "Failed to generate embeddings: #{e.message}"
      end
    end

    def cosine_similarity(embedding1, embedding2)
      return 0.0 if embedding1.nil? || embedding2.nil?
      return 0.0 if embedding1.length != embedding2.length

      dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
      magnitude1 = Math.sqrt(embedding1.sum { |a| a * a })
      magnitude2 = Math.sqrt(embedding2.sum { |a| a * a })

      return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0

      dot_product / (magnitude1 * magnitude2)
    end

    # Search for similar embeddings using cosine similarity
    def search_similar(query_embedding, limit: 10, threshold: nil)
      threshold ||= Ragdoll.configuration.search_similarity_threshold

      # Use raw SQL for vector similarity search with pgvector
      sql = <<~SQL
        SELECT e.*, d.title, d.location,
               (e.embedding <=> $1::vector) AS distance,
               (1 - (e.embedding <=> $1::vector)) AS similarity
        FROM ragdoll_embeddings e
        JOIN ragdoll_documents d ON d.id = e.document_id
        WHERE (1 - (e.embedding <=> $1::vector)) >= $2
        ORDER BY e.embedding <=> $1::vector
        LIMIT $3
      SQL

      results = ActiveRecord::Base.connection.exec_query(
        sql,
        'search_similar_embeddings',
        [query_embedding.to_s, threshold, limit]
      )

      results.map do |row|
        {
          embedding_id: row['id'],
          document_id: row['document_id'],
          document_title: row['title'],
          document_location: row['location'],
          content: row['content'],
          similarity: row['similarity'].to_f,
          distance: row['distance'].to_f,
          chunk_index: row['chunk_index'],
          metadata: JSON.parse(row['metadata'] || '{}')
        }
      end
    end

    private

    def clean_text(text)
      return '' if text.nil?
      
      # Remove excessive whitespace and normalize
      cleaned = text.strip
        .gsub(/\s+/, ' ')              # Multiple spaces to single space
        .gsub(/\n+/, "\n")             # Multiple newlines to single newline
        .gsub(/\t+/, ' ')              # Tabs to spaces
      
      # Truncate if too long (OpenAI has token limits)
      max_chars = 8000 # Conservative limit for most embedding models
      cleaned.length > max_chars ? cleaned[0, max_chars] : cleaned
    end
  end
end