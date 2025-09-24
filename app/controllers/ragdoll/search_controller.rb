# frozen_string_literal: true

module Ragdoll
  class SearchController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:search]
    
    def index
      # Load popular queries for sidebar
      @popular_queries = ::Ragdoll::Search.group(:query).count.sort_by { |query, count| -count }.first(10).to_h
      
      # Check if we're reconstructing a previous search
      if params[:search_id].present?
        begin
          previous_search = ::Ragdoll::Search.find(params[:search_id])
          @reconstructed_search = previous_search
          
          # Extract stored form parameters
          search_options = previous_search.search_options.is_a?(Hash) ? previous_search.search_options : 
                          (previous_search.search_options.present? ? JSON.parse(previous_search.search_options) : {})
          search_filters = previous_search.search_filters.is_a?(Hash) ? previous_search.search_filters : 
                          (previous_search.search_filters.present? ? JSON.parse(previous_search.search_filters) : {})
          
          form_params = search_options.dig('form_params') || {}
          
          # Reconstruct query and filters from stored search
          @query = previous_search.query
          @filters = {
            document_type: form_params['document_type'] || search_filters['document_type'],
            status: form_params['status'] || search_filters['status'],
            limit: form_params['limit'] || search_filters['limit'] || 10,
            threshold: form_params['threshold'] || search_filters['threshold'] || 0.001
          }
          
          # Reconstruct boolean search options
          @use_similarity_search = form_params['use_similarity_search'] || search_options['use_similarity'] || 'true'
          @use_fulltext_search = form_params['use_fulltext_search'] || search_options['use_fulltext'] || 'true'
          
          ::Rails.logger.debug "🔍 Reconstructed search from ID #{params[:search_id]}: #{@query}"
          
        rescue ActiveRecord::RecordNotFound
          ::Rails.logger.warn "🔍 Search ID #{params[:search_id]} not found"
          # Fall back to default behavior
        rescue => e
          ::Rails.logger.error "🔍 Error reconstructing search: #{e.message}"
          # Fall back to default behavior
        end
      end
      
      # Default values if not reconstructing a search
      unless @reconstructed_search
        @filters = {
          document_type: params[:document_type],
          status: params[:status],
          limit: params[:limit]&.to_i || 10,
          threshold: params[:threshold]&.to_f || (::Rails.env.development? ? 0.001 : 0.7)
        }
        @query = params[:query]
        @use_similarity_search = params[:use_similarity_search] || 'true'
        @use_fulltext_search = params[:use_fulltext_search] || 'true'
      end
      
      @search_performed = false
    end
    
    def search
      ::Rails.logger.debug "🔍 Search called with params: #{params.inspect}"
      ::Rails.logger.debug "🔍 Use similarity search: #{params[:use_similarity_search]}"
      ::Rails.logger.debug "🔍 Use fulltext search: #{params[:use_fulltext_search]}"
      @query = params[:query]
      @filters = {
        document_type: params[:document_type],
        status: params[:status],
        limit: params[:limit]&.to_i || 10,
        threshold: params[:threshold]&.to_f || (::Rails.env.development? ? 0.001 : 0.7)  # Much lower threshold for development
      }
      ::Rails.logger.debug "🔍 Query: #{@query.inspect}, Filters: #{@filters.inspect}"
      
      # Initialize data needed for the view sidebar - load popular queries
      @popular_queries = ::Ragdoll::Search.group(:query).count.sort_by { |query, count| -count }.first(10).to_h
      
      if @query.present?
        begin
          # Check which search types are enabled (default to both if neither param is set)
          use_similarity = params[:use_similarity_search] != 'false'
          use_fulltext = params[:use_fulltext_search] != 'false'
          
          @detailed_results = []
          @below_threshold_results = []
          @similarity_search_attempted = false
          @similarity_threshold_used = @filters[:threshold]
          
          # Perform similarity search if enabled
          if use_similarity
            begin
              search_params = {
                query: @query,
                limit: @filters[:limit],
                threshold: @filters[:threshold]
              }
              
              # Add document type filter if specified
              # NOTE: Document type filtering is deprecated in unified text-based architecture
              # All media types are now converted to text for unified cross-modal search
              if @filters[:document_type].present?
                search_params[:document_type] = @filters[:document_type]
                ::Rails.logger.warn "⚠️ Document type filtering is deprecated in unified text-based RAG architecture"
              end
              
              # Add status filter if specified
              if @filters[:status].present?
                search_params[:status] = @filters[:status]
              end
              
              search_response = ::Ragdoll.search(**search_params.merge(track_search: false))
              
              # The search returns a hash with :results and :statistics
              @results = search_response.is_a?(Hash) ? search_response[:results] || [] : []
              @similarity_stats = search_response.is_a?(Hash) ? search_response[:statistics] || {} : {}
              
              # Add similarity search results
              @results.each do |result|
                if result[:embedding_id] && result[:document_id]
                  embedding = ::Ragdoll::Embedding.find(result[:embedding_id])
                  document = ::Ragdoll::Document.find(result[:document_id])
                  @detailed_results << {
                    embedding: embedding,
                    document: document,
                    similarity: result[:similarity],
                    content: result[:content],
                    usage_count: embedding.usage_count,
                    last_used: embedding.returned_at,
                    search_type: 'similarity'
                  }
                end
              end
              
              # Mark that similarity search was attempted
              @similarity_search_attempted = true
              
              # Always gather statistics about all possible matches when similarity search returns limited results
              similarity_results_count = @detailed_results.select { |r| r[:search_type] == 'similarity' }.count
              ::Rails.logger.debug "🔍 Similarity results found: #{similarity_results_count}"
              
              # Gather statistics if we have no results OR if the threshold is relatively high (> 0.1)
              # This ensures we provide helpful feedback even when the search succeeds with a lower threshold
              should_gather_stats = similarity_results_count == 0 || @filters[:threshold] > 0.1
              ::Rails.logger.debug "🔍 Should gather stats: #{should_gather_stats} (results: #{similarity_results_count}, threshold: #{@filters[:threshold]})"
              
              if should_gather_stats
                ::Rails.logger.debug "🔍 Gathering below-threshold statistics..."
                begin
                  # Search again with minimal threshold to get all potential matches
                  stats_params = search_params.merge(threshold: 0.0, limit: 100)
                  stats_response = ::Ragdoll.search(**stats_params)
                  
                  ::Rails.logger.debug "🔍 Stats response: #{stats_response.inspect}"
                  
                  if stats_response.is_a?(Hash) && stats_response[:results]
                    all_similarities = []
                    stats_response[:results].each do |result|
                      if result[:similarity]
                        all_similarities << result[:similarity]
                        # Store below-threshold results
                        if result[:similarity] < @filters[:threshold] && result[:similarity] > 0
                          @below_threshold_results << {
                            document_id: result[:document_id],
                            similarity: result[:similarity],
                            content: result[:content]
                          }
                        end
                      end
                    end
                    
                    ::Rails.logger.debug "🔍 All similarities collected: #{all_similarities.inspect}"
                    ::Rails.logger.debug "🔍 Threshold: #{@filters[:threshold]}"
                    
                    # Calculate statistics for display
                    if all_similarities.any?
                      below_threshold_count = all_similarities.count { |s| s < @filters[:threshold] && s > 0 }
                      @below_threshold_stats = {
                        count: below_threshold_count,
                        highest: all_similarities.max,
                        lowest: all_similarities.select { |s| s > 0 }.min,
                        average: all_similarities.sum / all_similarities.size.to_f,
                        suggested_threshold: all_similarities.select { |s| s > 0 }.min.round(3)
                      }
                      ::Rails.logger.debug "🔍 Below threshold stats: #{@below_threshold_stats.inspect}"
                    else
                      ::Rails.logger.debug "🔍 No similarities found in stats response"
                    end
                  else
                    ::Rails.logger.debug "🔍 Stats response was not in expected format or had no results"
                  end
                rescue => stats_error
                  ::Rails.logger.error "Stats gathering error: #{stats_error.message}"
                end
              end
              
            rescue => e
              ::Rails.logger.error "Similarity search error: #{e.message}"
              # Continue with fulltext search even if similarity search fails
            end
          end
          
          # Perform full-text search if enabled
          if use_fulltext
            fulltext_params = {
              limit: @filters[:limit], 
              threshold: @filters[:threshold]
            }
            
            # Add document type filter if specified
            # NOTE: Document type filtering is deprecated in unified text-based architecture
            # All media types are now converted to text for unified cross-modal search
            if @filters[:document_type].present?
              fulltext_params[:document_type] = @filters[:document_type]
              ::Rails.logger.warn "⚠️ Document type filtering is deprecated in unified text-based RAG architecture"
            end
            
            # Add status filter if specified
            if @filters[:status].present?
              fulltext_params[:status] = @filters[:status]
            end
            
            fulltext_results = ::Ragdoll::Document.search_content(@query, **fulltext_params)
            
            # Collect fulltext similarities for statistics
            fulltext_similarities = []
            fulltext_results.each do |document|
              # Avoid duplicates if document was already found in similarity search
              unless @detailed_results.any? { |r| r[:document].id == document.id }
                # Use the fulltext_similarity score from the enhanced search
                fulltext_similarity = document.respond_to?(:fulltext_similarity) ? document.fulltext_similarity.to_f : 0.0
                fulltext_similarities << fulltext_similarity if fulltext_similarity > 0
                
                @detailed_results << {
                  document: document,
                  content: document.summary || document.metadata&.dig('summary') || document.title || "No summary available",
                  search_type: 'fulltext',
                  similarity: fulltext_similarity
                }
              end
            end
            
            # Gather fulltext statistics if we have few results OR if threshold is high (> 0.1)
            # This ensures consistent feedback regardless of which search types are enabled
            fulltext_results_count = @detailed_results.select { |r| r[:search_type] == 'fulltext' }.count
            should_gather_fulltext_stats = fulltext_results_count == 0 || @filters[:threshold] > 0.1
            
            if should_gather_fulltext_stats && !@below_threshold_stats
              ::Rails.logger.debug "🔍 Gathering fulltext below-threshold statistics..."
              begin
                # Search again with lower threshold to get all potential matches
                stats_params = fulltext_params.merge(threshold: 0.0, limit: 100)
                all_fulltext_results = ::Ragdoll::Document.search_content(@query, **stats_params)
                
                all_fulltext_similarities = []
                all_fulltext_results.each do |document|
                  similarity = document.respond_to?(:fulltext_similarity) ? document.fulltext_similarity.to_f : 0.0
                  if similarity > 0
                    all_fulltext_similarities << similarity
                    # Store below-threshold results
                    if similarity < @filters[:threshold]
                      @below_threshold_results << {
                        document_id: document.id,
                        similarity: similarity,
                        content: document.summary || document.metadata&.dig('summary') || document.title || "No summary available"
                      }
                    end
                  end
                end
                
                ::Rails.logger.debug "🔍 Fulltext similarities collected: #{all_fulltext_similarities.inspect}"
                ::Rails.logger.debug "🔍 Threshold: #{@filters[:threshold]}"
                
                # Calculate statistics for display
                if all_fulltext_similarities.any?
                  below_threshold_count = all_fulltext_similarities.count { |s| s < @filters[:threshold] && s > 0 }
                  @below_threshold_stats = {
                    count: below_threshold_count,
                    highest: all_fulltext_similarities.max,
                    lowest: all_fulltext_similarities.select { |s| s > 0 }.min,
                    average: all_fulltext_similarities.sum / all_fulltext_similarities.size.to_f,
                    suggested_threshold: all_fulltext_similarities.select { |s| s > 0 }.min.round(3)
                  }
                  ::Rails.logger.debug "🔍 Fulltext below threshold stats: #{@below_threshold_stats.inspect}"
                else
                  ::Rails.logger.debug "🔍 No fulltext similarities found in stats response"
                end
              rescue => stats_error
                ::Rails.logger.error "Fulltext stats gathering error: #{stats_error.message}"
              end
            end
          end
          
          # Sort results by similarity score if available, otherwise by relevance
          @detailed_results.sort_by! { |r| r[:similarity] ? -r[:similarity] : 0 }
          
          # Save search for analytics
          search_type = case
                       when use_similarity && use_fulltext then 'hybrid'
                       when use_similarity then 'similarity'
                       when use_fulltext then 'fulltext'
                       else 'unknown'
                       end
          
          similarity_results = @detailed_results.select { |r| r[:search_type] == 'similarity' }
          similarities = similarity_results.map { |r| r[:similarity] }.compact
          
          # Save search for analytics without query embedding (which is optional)
          begin
            ::Ragdoll::Search.create!(
              query: @query,
              search_type: search_type,
              results_count: @detailed_results.count,
              max_similarity_score: similarities.any? ? similarities.max : nil,
              min_similarity_score: similarities.any? ? similarities.min : nil,
              avg_similarity_score: similarities.any? ? (similarities.sum / similarities.size.to_f) : nil,
              search_filters: @filters.to_json,
              search_options: {
                threshold_used: @filters[:threshold],
                similarity_results: similarity_results.count,
                fulltext_results: @detailed_results.select { |r| r[:search_type] == 'fulltext' }.count,
                use_similarity: use_similarity,
                use_fulltext: use_fulltext,
                # Store original form parameters for reconstruction
                form_params: {
                  use_similarity_search: params[:use_similarity_search],
                  use_fulltext_search: params[:use_fulltext_search],
                  limit: @filters[:limit],
                  threshold: @filters[:threshold],
                  document_type: @filters[:document_type],
                  status: @filters[:status]
                }
              }.to_json
            )
            ::Rails.logger.debug "🔍 Search saved successfully"
          rescue => e
            ::Rails.logger.error "🔍 Failed to save search: #{e.message}"
            # Continue without failing the search
          end
          
          ::Rails.logger.debug "🔍 Search completed successfully. Results count: #{@detailed_results.count}"
          ::Rails.logger.debug "🔍 Similarity search attempted: #{@similarity_search_attempted}"
          ::Rails.logger.debug "🔍 Below threshold stats: #{@below_threshold_stats.inspect}"
          ::Rails.logger.debug "🔍 Threshold used: #{@similarity_threshold_used}"
          @search_performed = true
          
        rescue => e
          ::Rails.logger.error "🔍 Search error: #{e.message}"
          ::Rails.logger.error e.backtrace.join("\n")
          @error = e.message
          @search_performed = false
        end
      else
        @search_performed = false
      end
      
      respond_to do |format|
        format.html { render :index }
        format.json { 
          json_response = { results: @detailed_results, error: @error }
          if @similarity_search_attempted && @similarity_stats
            json_response[:similarity_statistics] = {
              threshold_used: @similarity_threshold_used,
              stats: @similarity_stats
            }
          end
          render json: json_response
        }
      end
    end
  end
end