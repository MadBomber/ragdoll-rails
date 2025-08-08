class Api::V1::SearchController < Api::V1::BaseController
  def search
    query = params[:query]
    
    if query.blank?
      return render_error("Query parameter is required")
    end
    
    begin
      search_options = {
        limit: params[:limit]&.to_i || 10,
        threshold: params[:threshold]&.to_f || 0.7,
        use_usage_ranking: params[:use_usage_ranking] == 'true'
      }
      
      search_response = Ragdoll.search(query: query, **search_options)
      
      # Handle both old format (array) and new format (hash with results)
      results = if search_response.is_a?(Hash) && search_response.key?(:results)
        search_response[:results]
      else
        # Fallback for old format
        search_response || []
      end
      
      # Extract statistics if available
      statistics = search_response.is_a?(Hash) ? search_response[:statistics] : nil
      execution_time_ms = search_response.is_a?(Hash) ? search_response[:execution_time_ms] : nil
      
      # Format results with additional metadata
      formatted_results = results.map do |result|
        embedding = Ragdoll::Embedding.find(result[:embedding_id])
        {
          embedding_id: result[:embedding_id],
          document_id: embedding.document_id,
          document_title: embedding.document.title,
          content: result[:content],
          similarity: result[:similarity],
          usage_count: embedding.usage_count,
          last_used_at: embedding.returned_at,
          chunk_index: embedding.chunk_index,
          document_type: embedding.document.document_type
        }
      end
      
      # Save search for analytics if results found
      if results.any?
        first_result = results.first
        embedding = Ragdoll::Embedding.find(first_result[:embedding_id])
        
        Ragdoll::Search.create!(
          query: query,
          search_type: 'semantic',
          result_count: results.count,
          model_name: Ragdoll.configuration.models[:embedding][:text]&.to_s || 'text-embedding-3-small'
        )
      end
      
      response_data = {
        query: query,
        results: formatted_results,
        total_results: results.count,
        search_options: search_options
      }
      
      # Add enhanced search statistics if available
      if statistics
        response_data[:statistics] = statistics
      end
      
      if execution_time_ms
        response_data[:execution_time_ms] = execution_time_ms
      end
      
      render json: response_data
      
    rescue => e
      render_error(e.message)
    end
  end
end