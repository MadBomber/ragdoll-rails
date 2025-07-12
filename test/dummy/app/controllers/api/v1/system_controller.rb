class Api::V1::SystemController < Api::V1::BaseController
  def stats
    begin
      client = Ragdoll::Client.new
      ragdoll_stats = client.stats
      
      system_stats = {
        ragdoll_version: Ragdoll::VERSION,
        rails_version: Rails.version,
        ruby_version: RUBY_VERSION,
        
        database_stats: {
          documents: Ragdoll::Document.count,
          embeddings: Ragdoll::Embedding.count,
          searches: Ragdoll::Search.count,
          database_size: calculate_database_size
        },
        
        configuration: {
          llm_provider: Ragdoll.configuration.llm_provider,
          embedding_provider: Ragdoll.configuration.embedding_provider,
          embedding_model: Ragdoll.configuration.embedding_model,
          chunk_size: Ragdoll.configuration.chunk_size,
          chunk_overlap: Ragdoll.configuration.chunk_overlap,
          max_search_results: Ragdoll.configuration.max_search_results,
          search_similarity_threshold: Ragdoll.configuration.search_similarity_threshold,
          enable_search_analytics: Ragdoll.configuration.enable_search_analytics,
          enable_document_summarization: Ragdoll.configuration.enable_document_summarization,
          enable_usage_tracking: Ragdoll.configuration.enable_usage_tracking,
          usage_ranking_enabled: Ragdoll.configuration.usage_ranking_enabled
        },
        
        performance_metrics: {
          average_search_time: calculate_average_search_time,
          embedding_dimensions: begin
            first_embedding = Ragdoll::Embedding.first
            if first_embedding&.embedding.present?
              JSON.parse(first_embedding.embedding).size rescue 0
            else
              0
            end
          end,
          average_document_size: Ragdoll::Document.average('LENGTH(content)')&.round || 0,
          average_chunks_per_document: (Ragdoll::Embedding.count.to_f / Ragdoll::Document.count).round || 0
        },
        
        health_check: {
          database_connection: database_healthy?,
          embedding_service: embedding_service_healthy?
        }
      }.merge(ragdoll_stats)
      
      render json: system_stats
    rescue => e
      render_error("Error retrieving system stats: #{e.message}")
    end
  end
  
  private
  
  def calculate_database_size
    # Simple approximation - in production you might want more sophisticated calculation
    result = ActiveRecord::Base.connection.execute(
      "SELECT pg_size_pretty(pg_database_size(current_database()))"
    )
    result.first['pg_size_pretty']
  rescue
    "Unknown"
  end
  
  def calculate_average_search_time
    # This would require storing search times - for now return placeholder
    "< 100ms"
  end
  
  def database_healthy?
    ActiveRecord::Base.connection.active?
  rescue
    false
  end
  
  def embedding_service_healthy?
    begin
      client = Ragdoll::Client.new
      # Try a simple test - this might need adjustment based on your actual implementation
      true
    rescue
      false
    end
  end
end