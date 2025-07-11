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
          # In development/test mode, create a dummy embedding to avoid API calls
          if Rails.env.development? || Rails.env.test?
            # Create a dummy 1536-dimension embedding
            Array.new(1536) { rand(-1.0..1.0) }
          else
            # Use ruby_llm global API
            embedding = RubyLLM.embed(cleaned_text, model: Ragdoll.configuration.embedding_model)
            # Convert RubyLLM::Embedding object to array
            if embedding.respond_to?(:vector)
              embedding.vector
            elsif embedding.respond_to?(:to_a)
              embedding.to_a
            elsif embedding.is_a?(Array)
              embedding
            else
              # Fallback: try to extract data from the object
              embedding.respond_to?(:data) ? embedding.data : embedding
            end
          end
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
            embedding = RubyLLM.embed(text, model: Ragdoll.configuration.embedding_model)
            # Convert RubyLLM::Embedding object to array
            embedding.respond_to?(:to_a) ? embedding.to_a : embedding
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

    # Search for similar embeddings using cosine similarity with usage-based ranking
    def search_similar(query_embedding, options = {}, limit: 10, threshold: nil, model_name: nil)
      threshold ||= Ragdoll.configuration&.search_similarity_threshold || 0.7
      model_name ||= Ragdoll.configuration&.embedding_model
      query_dimensions = query_embedding.length
      
      # Get all embeddings from database and calculate similarity in Ruby
      # This is less efficient than PostgreSQL vector operations but works with JSON storage
      embeddings_query = Ragdoll::Embedding.joins(:document).limit(1000)
      
      # Only filter by model_name if it's specified and not nil
      if model_name.present?
        embeddings_query = embeddings_query.where(model_name: model_name)
      end
      
      embeddings = embeddings_query
      
      results = []
      
      embeddings.each do |embedding|
        begin
          # Parse the stored JSON embedding
          stored_embedding = JSON.parse(embedding.embedding)
          next unless stored_embedding.is_a?(Array) && stored_embedding.length == query_dimensions
          
          # Calculate cosine similarity
          similarity = cosine_similarity(query_embedding, stored_embedding)
          next if similarity < threshold
          
          # Calculate usage score if needed
          usage_score = 0.0
          if options.fetch(:use_usage_ranking, true) && embedding.returned_at
            frequency_weight = options.fetch(:frequency_weight, 0.7)
            recency_weight = options.fetch(:recency_weight, 0.3)
            
            frequency_score = [Math.log(embedding.usage_count + 1) / Math.log(100), 1.0].min
            days_since_use = (Time.current - embedding.returned_at) / 1.day
            recency_score = Math.exp(-days_since_use / 30)
            
            usage_score = frequency_weight * frequency_score + recency_weight * recency_score
          end
          
          combined_score = options.fetch(:similarity_weight, 1.0) * similarity + usage_score
          
          results << {
            embedding_id: embedding.id,
            document_id: embedding.document_id,
            document_title: embedding.document.title,
            document_location: embedding.document.location,
            content: embedding.content,
            similarity: similarity,
            distance: 1.0 - similarity,
            chunk_index: embedding.chunk_index,
            metadata: JSON.parse(embedding.metadata || '{}'),
            embedding_dimensions: query_dimensions,
            model_name: embedding.model_name,
            usage_count: embedding.usage_count || 0,
            returned_at: embedding.returned_at,
            usage_score: usage_score,
            combined_score: combined_score
          }
        rescue JSON::ParserError => e
          Rails.logger.warn "Failed to parse embedding JSON for embedding #{embedding.id}: #{e.message}"
          next
        end
      end
      
      # Sort by combined score and limit results
      results = results.sort_by { |r| -r[:combined_score] }.take(limit)
      
      # Record usage for returned embeddings
      embedding_ids = results.map { |r| r[:embedding_id] }
      record_usage_for_embeddings(embedding_ids) if embedding_ids.any?
      
      results
    end

    private

    def record_usage_for_embeddings(embedding_ids)
      return if embedding_ids.empty?
      
      # Use batch update for better performance
      Ragdoll::Embedding.record_batch_usage(embedding_ids)
    rescue => e
      Rails.logger.warn "Failed to record embedding usage: #{e.message}"
      # Don't fail the search if usage recording fails
    end

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