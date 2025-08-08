class Api::V1::SystemController < Api::V1::BaseController
  def stats
    begin
      ragdoll_stats = Ragdoll.stats
      
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
          models: {
            text_generation: Ragdoll.configuration.models[:text_generation][:default]&.to_s,
            text_embedding: Ragdoll.configuration.models[:embedding][:text]&.to_s,
            image_embedding: Ragdoll.configuration.models[:embedding][:image]&.to_s,
            audio_embedding: Ragdoll.configuration.models[:embedding][:audio]&.to_s
          },
          processing: {
            text_chunking_max_tokens: Ragdoll.configuration.processing[:text][:chunking][:max_tokens],
            text_chunking_overlap: Ragdoll.configuration.processing[:text][:chunking][:overlap],
            default_chunking_max_tokens: Ragdoll.configuration.processing[:default][:chunking][:max_tokens],
            default_chunking_overlap: Ragdoll.configuration.processing[:default][:chunking][:overlap],
            similarity_threshold: Ragdoll.configuration.processing[:search][:similarity_threshold],
            max_results: Ragdoll.configuration.processing[:search][:max_results]
          },
          summarization: {
            enabled: Ragdoll.configuration.summarization[:enable],
            max_length: Ragdoll.configuration.summarization[:max_length],
            min_content_length: Ragdoll.configuration.summarization[:min_content_length]
          },
          database: {
            adapter: Ragdoll.configuration.database[:adapter],
            database: Ragdoll.configuration.database[:database],
            auto_migrate: Ragdoll.configuration.database[:auto_migrate]
          }
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
      # Try a simple test using high-level API
      Ragdoll.healthy?
    rescue
      false
    end
  end
end