class Api::V1::SearchController < Api::V1::BaseController
  def search
    query = params[:query]
    
    if query.blank?
      return render_error("Query parameter is required")
    end
    
    begin
      client = Ragdoll::Client.new
      
      search_options = {
        limit: params[:limit]&.to_i || 10,
        threshold: params[:threshold]&.to_f || 0.7,
        use_usage_ranking: params[:use_usage_ranking] == 'true'
      }
      
      results = client.search(query, **search_options)
      
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
          model_name: Ragdoll.configuration.embedding_model
        )
      end
      
      render json: {
        query: query,
        results: formatted_results,
        total_results: results.count,
        search_options: search_options
      }
      
    rescue => e
      render_error(e.message)
    end
  end
end