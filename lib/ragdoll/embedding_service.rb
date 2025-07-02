# frozen_string_literal: true

require 'ruby_llm'

module Ragdoll
  class EmbeddingService
    class EmbeddingError < Error; end

    def initialize(client: nil)
      # ruby_llm uses global configuration, so we don't need a client instance
      @client = client
      configure_ruby_llm unless @client
    end

    def generate_embedding(text)
      return nil if text.blank?

      # Clean and prepare text
      cleaned_text = clean_text(text)
      
      begin
        if @client
          # Use custom client for testing
          response = @client.embed(
            input: cleaned_text,
            model: Ragdoll.configuration.embedding_model
          )
          
          if response && response['embeddings'] && response['embeddings'].first
            response['embeddings'].first
          elsif response && response['data'] && response['data'].first && response['data'].first['embedding']
            response['data'].first['embedding']
          else
            raise EmbeddingError, "Invalid response format from embedding API"
          end
        else
          # Use ruby_llm global API
          embedding = RubyLLM.embed(cleaned_text, model: Ragdoll.configuration.embedding_model)
          embedding
        end

      rescue RubyLLM::Error => e
        raise EmbeddingError, "LLM provider error generating embedding: #{e.message}"
      rescue Faraday::Error => e
        raise EmbeddingError, "Network error generating embedding: #{e.message}"
      rescue JSON::ParserError => e
        raise EmbeddingError, "Invalid JSON response from embedding API: #{e.message}"
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
        if @client
          # Use custom client for testing
          response = @client.embed(
            input: cleaned_texts,
            model: Ragdoll.configuration.embedding_model
          )

          if response && response['embeddings']
            response['embeddings']
          elsif response && response['data']
            response['data'].map { |item| item['embedding'] }
          else
            raise EmbeddingError, "Invalid response format from embedding API"
          end
        else
          # Use ruby_llm for batch processing - process individually
          cleaned_texts.map do |text|
            RubyLLM.embed(text, model: Ragdoll.configuration.embedding_model)
          end
        end

      rescue RubyLLM::Error => e
        raise EmbeddingError, "LLM provider error generating embeddings: #{e.message}"
      rescue Faraday::Error => e
        raise EmbeddingError, "Network error generating embeddings: #{e.message}"
      rescue JSON::ParserError => e
        raise EmbeddingError, "Invalid JSON response from embedding API: #{e.message}"
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
    def search_similar(query_embedding, limit: 10, threshold: nil, model_name: nil)
      threshold ||= Ragdoll.configuration.search_similarity_threshold
      model_name ||= Ragdoll.configuration.embedding_model
      query_dimensions = query_embedding.length

      # Use raw SQL for vector similarity search with pgvector
      # Filter by embedding dimensions to ensure compatibility
      sql = <<~SQL
        SELECT e.*, d.title, d.location,
               (e.embedding <=> $1::vector) AS distance,
               (1 - (e.embedding <=> $1::vector)) AS similarity
        FROM ragdoll_embeddings e
        JOIN ragdoll_documents d ON d.id = e.document_id
        WHERE (1 - (e.embedding <=> $1::vector)) >= $2
          AND e.embedding_dimensions = $4
          AND ($5::text IS NULL OR e.model_name = $5)
        ORDER BY e.embedding <=> $1::vector
        LIMIT $3
      SQL

      results = ActiveRecord::Base.connection.exec_query(
        sql,
        'search_similar_embeddings',
        [query_embedding.to_s, threshold, limit, query_dimensions, model_name]
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
          metadata: JSON.parse(row['metadata'] || '{}'),
          embedding_dimensions: row['embedding_dimensions'],
          model_name: row['model_name']
        }
      end
    end

    private

    def configure_ruby_llm
      # Configure ruby_llm based on Ragdoll configuration
      provider = Ragdoll.configuration.embedding_provider || Ragdoll.configuration.llm_provider
      config = Ragdoll.configuration.llm_config[provider] || {}

      RubyLLM.configure do |ruby_llm_config|
        case provider
        when :openai
          ruby_llm_config.openai_api_key = config[:api_key]
          ruby_llm_config.openai_organization = config[:organization] if config[:organization]
          ruby_llm_config.openai_project = config[:project] if config[:project]
        when :anthropic
          ruby_llm_config.anthropic_api_key = config[:api_key]
        when :google
          ruby_llm_config.google_api_key = config[:api_key]
          ruby_llm_config.google_project_id = config[:project_id] if config[:project_id]
        when :azure
          ruby_llm_config.azure_api_key = config[:api_key]
          ruby_llm_config.azure_endpoint = config[:endpoint] if config[:endpoint]
          ruby_llm_config.azure_api_version = config[:api_version] if config[:api_version]
        when :ollama
          ruby_llm_config.ollama_endpoint = config[:endpoint] if config[:endpoint]
        when :huggingface
          ruby_llm_config.huggingface_api_key = config[:api_key]
        else
          raise EmbeddingError, "Unsupported embedding provider: #{provider}"
        end
      end
    end

    def clean_text(text)
      return '' if text.nil?
      
      # Remove excessive whitespace and normalize
      cleaned = text.strip
        .gsub(/\s+/, ' ')              # Multiple spaces to single space
        .gsub(/\n+/, "\n")             # Multiple newlines to single newline
        .gsub(/\t+/, ' ')              # Tabs to spaces
      
      # Truncate if too long (most embedding models have token limits)
      max_chars = 8000 # Conservative limit for most embedding models
      cleaned.length > max_chars ? cleaned[0, max_chars] : cleaned
    end
  end
end