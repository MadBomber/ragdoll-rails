class ConfigurationController < ApplicationController
  def index
    @configuration = Ragdoll.configuration
    @available_providers = %w[openai anthropic google azure ollama huggingface]
    @available_models = {
      openai: ['text-embedding-3-small', 'text-embedding-3-large', 'text-embedding-ada-002'],
      anthropic: ['claude-3-haiku-20240307', 'claude-3-sonnet-20240229', 'claude-3-opus-20240229'],
      google: ['gemini-pro', 'gemini-1.5-flash', 'gemini-1.5-pro'],
      azure: ['text-embedding-3-small', 'text-embedding-3-large'],
      ollama: ['llama2', 'mistral', 'codellama'],
      huggingface: ['sentence-transformers/all-MiniLM-L6-v2', 'sentence-transformers/all-mpnet-base-v2']
    }
    
    @current_stats = {
      total_documents: Ragdoll::Document.count,
      total_embeddings: Ragdoll::Embedding.count,
      embedding_dimensions: begin
        first_embedding = Ragdoll::Embedding.first
        if first_embedding&.embedding.present?
          JSON.parse(first_embedding.embedding).size rescue 0
        else
          0
        end
      end,
      average_chunk_size: Ragdoll::Document.average('LENGTH(content)')&.round || 0
    }
  end
  
  def update
    config_params = params.require(:configuration).permit(
      :llm_provider,
      :embedding_provider,
      :embedding_model,
      :chunk_size,
      :chunk_overlap,
      :max_search_results,
      :search_similarity_threshold,
      :enable_search_analytics,
      :enable_document_summarization,
      :enable_usage_tracking,
      :usage_ranking_enabled,
      :openai_api_key,
      :anthropic_api_key,
      :google_api_key,
      :azure_api_key,
      :ollama_url,
      :huggingface_api_key
    )
    
    begin
      # Update configuration
      config = Ragdoll.configuration
      
      config_params.each do |key, value|
        # Convert string values to appropriate types
        case key
        when 'chunk_size', 'chunk_overlap', 'max_search_results'
          config.send("#{key}=", value.to_i)
        when 'search_similarity_threshold'
          config.send("#{key}=", value.to_f)
        when 'enable_search_analytics', 'enable_document_summarization', 'enable_usage_tracking', 'usage_ranking_enabled'
          config.send("#{key}=", value == '1' || value == 'true')
        else
          config.send("#{key}=", value) if value.present?
        end
      end
      
      flash[:notice] = 'Configuration updated successfully.'
      
      # Test the configuration
      begin
        client = Ragdoll::Client.new
        test_result = client.stats
        flash[:notice] += " Configuration test successful."
      rescue => e
        flash[:warning] = "Configuration saved but test failed: #{e.message}"
      end
      
    rescue => e
      flash[:alert] = "Error updating configuration: #{e.message}"
    end
    
    redirect_to configuration_path
  end
end