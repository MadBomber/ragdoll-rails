# frozen_string_literal: true

module Ragdoll
  module Api
    module V1
      class SearchController < BaseController
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
            
            # Add document type filter if specified
            if params[:document_type].present?
              search_options[:document_type] = params[:document_type]
            end
            
            # Add status filter if specified
            if params[:status].present?
              search_options[:status] = params[:status]
            end
            
            search_response = ::Ragdoll.search(search_options.merge(query: query))
            results = search_response.is_a?(Hash) ? search_response[:results] || [] : []
            
            # Format results with additional metadata
            formatted_results = results.map do |result|
              if result[:embedding_id] && result[:document_id]
                embedding = ::Ragdoll::Embedding.find(result[:embedding_id])
                document = ::Ragdoll::Document.find(result[:document_id])
                {
                  embedding_id: result[:embedding_id],
                  document_id: result[:document_id],
                  document_title: document.title,
                  content: result[:content],
                  similarity: result[:similarity],
                  usage_count: embedding.usage_count,
                  last_used_at: embedding.returned_at,
                  chunk_index: embedding.chunk_index,
                  document_type: document.document_type
                }
              end
            end.compact
            
            # Save search for analytics
            begin
              similarities = formatted_results.map { |r| r[:similarity] }.compact
              ::Ragdoll::Search.create!(
                query: query,
                search_type: 'api_semantic',
                results_count: formatted_results.count,
                max_similarity_score: similarities.any? ? similarities.max : nil,
                min_similarity_score: similarities.any? ? similarities.min : nil,
                avg_similarity_score: similarities.any? ? (similarities.sum / similarities.size.to_f) : nil,
                search_filters: search_options.to_json,
                search_options: {
                  api_request: true,
                  threshold_used: search_options[:threshold]
                }.to_json
              )
            rescue => e
              Rails.logger.error "Failed to save API search: #{e.message}"
            end
            
            render json: {
              query: query,
              results: formatted_results,
              total_results: formatted_results.count,
              search_options: search_options
            }
            
          rescue => e
            render_error(e.message)
          end
        end
      end
    end
  end
end