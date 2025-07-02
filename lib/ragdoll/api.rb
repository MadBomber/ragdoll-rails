# frozen_string_literal: true

module Ragdoll
  class API
    class APIError < Error; end
    class SearchError < APIError; end
    class DocumentError < APIError; end

    def initialize(embedding_service: nil)
      @embedding_service = embedding_service || EmbeddingService.new
    end

    # Main method for retrieving context for AI prompts
    # Returns relevant content chunks based on semantic similarity
    def get_context(prompt, limit: nil, threshold: nil, filters: {})
      limit ||= Ragdoll.configuration.max_search_results
      threshold ||= Ragdoll.configuration.search_similarity_threshold

      begin
        # Generate embedding for the prompt
        prompt_embedding = @embedding_service.generate_embedding(prompt)
        
        # Search for similar content
        results = search_similar_content(
          prompt_embedding, 
          limit: limit, 
          threshold: threshold, 
          filters: filters
        )

        # Format results for context enhancement
        format_context_results(results, prompt)

      rescue => e
        raise SearchError, "Failed to get context: #{e.message}"
      end
    end

    # Search for similar content using semantic search
    def search(query, limit: nil, threshold: nil, filters: {})
      limit ||= Ragdoll.configuration.max_search_results
      threshold ||= Ragdoll.configuration.search_similarity_threshold

      begin
        # Generate embedding for the query
        query_embedding = @embedding_service.generate_embedding(query)
        
        # Search and return formatted results
        results = search_similar_content(
          query_embedding, 
          limit: limit, 
          threshold: threshold, 
          filters: filters
        )

        # Store search for analytics
        store_search_record(query, query_embedding, results, filters)

        format_search_results(results, query)

      rescue => e
        raise SearchError, "Search failed: #{e.message}"
      end
    end

    # Document management methods
    def add_document(location_or_content, **options)
      begin
        if File.exist?(location_or_content.to_s)
          # File path provided
          add_document_from_file(location_or_content, **options)
        else
          # Content string provided
          add_document_from_content(location_or_content, **options)
        end
      rescue => e
        raise DocumentError, "Failed to add document: #{e.message}"
      end
    end

    def update_document(document_id, **updates)
      begin
        document = find_document(document_id)
        
        # Update document attributes
        allowed_updates = %i[title content document_type metadata chunk_size chunk_overlap]
        filtered_updates = updates.select { |k, v| allowed_updates.include?(k.to_sym) }
        
        document.update!(filtered_updates) if filtered_updates.any?

        # Reprocess embeddings if content changed
        if updates[:content] || updates[:chunk_size] || updates[:chunk_overlap]
          reprocess_document(document)
        end

        format_document_response(document)
      rescue => e
        raise DocumentError, "Failed to update document: #{e.message}"
      end
    end

    def delete_document(document_id)
      begin
        document = find_document(document_id)
        embeddings_count = document.ragdoll_embeddings.count
        
        document.destroy!
        
        { 
          success: true, 
          message: "Document deleted successfully",
          embeddings_deleted: embeddings_count 
        }
      rescue => e
        raise DocumentError, "Failed to delete document: #{e.message}"
      end
    end

    def get_document(document_id)
      begin
        document = find_document(document_id)
        format_document_response(document, include_content: true)
      rescue => e
        raise DocumentError, "Failed to get document: #{e.message}"
      end
    end

    def list_documents(limit: 50, offset: 0, filters: {})
      begin
        documents = Ragdoll::Document.all
        
        # Apply filters
        documents = documents.where(status: filters[:status]) if filters[:status]
        documents = documents.where(document_type: filters[:document_type]) if filters[:document_type]
        documents = documents.where("title ILIKE ?", "%#{filters[:title]}%") if filters[:title]
        documents = documents.where("created_at >= ?", filters[:created_after]) if filters[:created_after]
        
        # Apply pagination
        total_count = documents.count
        documents = documents.limit(limit).offset(offset).order(created_at: :desc)

        {
          documents: documents.map { |doc| format_document_response(doc) },
          pagination: {
            total: total_count,
            limit: limit,
            offset: offset,
            has_more: (offset + limit) < total_count
          }
        }
      rescue => e
        raise DocumentError, "Failed to list documents: #{e.message}"
      end
    end

    # Bulk operations
    def add_documents_from_directory(directory_path, recursive: false, **options)
      begin
        pattern = recursive ? "#{directory_path}/**/*" : "#{directory_path}/*"
        files = Dir.glob(pattern).select { |f| File.file?(f) }
        
        results = []
        files.each do |file_path|
          next unless DocumentTypeDetector.embeddable?(file_path)
          
          begin
            result = add_document_from_file(file_path, **options)
            results << result.merge(file_path: file_path, status: 'success')
          rescue => e
            results << { 
              file_path: file_path, 
              status: 'error', 
              error: e.message 
            }
          end
        end

        {
          total_files: files.length,
          processed: results.count { |r| r[:status] == 'success' },
          failed: results.count { |r| r[:status] == 'error' },
          results: results
        }
      rescue => e
        raise DocumentError, "Failed to add documents from directory: #{e.message}"
      end
    end

    def reprocess_documents(status_filter: nil)
      begin
        documents = Ragdoll::Document.all
        documents = documents.where(status: status_filter) if status_filter
        
        results = []
        documents.find_each do |document|
          begin
            reprocess_document(document)
            results << { document_id: document.id, status: 'success' }
          rescue => e
            results << { 
              document_id: document.id, 
              status: 'error', 
              error: e.message 
            }
          end
        end

        {
          total_documents: documents.count,
          processed: results.count { |r| r[:status] == 'success' },
          failed: results.count { |r| r[:status] == 'error' },
          results: results
        }
      rescue => e
        raise DocumentError, "Failed to reprocess documents: #{e.message}"
      end
    end

    # Analytics and insights
    def get_search_analytics(days: 30)
      begin
        start_date = days.days.ago
        searches = Ragdoll::Search.where(created_at: start_date..)
        
        {
          total_searches: searches.count,
          unique_queries: searches.distinct.count(:query),
          average_results: searches.average(:result_count)&.round(2),
          average_search_time: searches.average(:search_time)&.round(3),
          most_common_queries: searches
            .group(:query)
            .count
            .sort_by { |_, count| -count }
            .first(10)
            .map { |query, count| { query: query, count: count } }
        }
      rescue => e
        raise APIError, "Failed to get search analytics: #{e.message}"
      end
    end

    def get_document_stats
      begin
        total_documents = Ragdoll::Document.count
        total_embeddings = Ragdoll::Embedding.count
        
        by_status = Ragdoll::Document.group(:status).count
        by_type = Ragdoll::Document.group(:document_type).count
        
        {
          total_documents: total_documents,
          total_embeddings: total_embeddings,
          average_embeddings_per_document: total_documents > 0 ? (total_embeddings.to_f / total_documents).round(2) : 0,
          documents_by_status: by_status,
          documents_by_type: by_type,
          storage_stats: {
            total_content_size: Ragdoll::Document.sum("LENGTH(content)"),
            average_document_size: Ragdoll::Document.average("LENGTH(content)")&.round(0)
          }
        }
      rescue => e
        raise APIError, "Failed to get document stats: #{e.message}"
      end
    end

    private

    def search_similar_content(embedding, limit:, threshold:, filters:)
      # Build the base query with filters
      embeddings_query = Ragdoll::Embedding.joins(:document)
      
      # Apply document filters
      if filters[:document_type]
        embeddings_query = embeddings_query.where(ragdoll_documents: { document_type: filters[:document_type] })
      end
      
      if filters[:document_status]
        embeddings_query = embeddings_query.where(ragdoll_documents: { status: filters[:document_status] })
      end
      
      if filters[:created_after]
        embeddings_query = embeddings_query.where(ragdoll_documents: { created_at: filters[:created_after].. })
      end

      # Use pgvector for similarity search
      sql = <<~SQL
        SELECT e.*, d.title, d.location, d.document_type,
               (e.embedding <=> $1::vector) AS distance,
               (1 - (e.embedding <=> $1::vector)) AS similarity
        FROM ragdoll_embeddings e
        JOIN ragdoll_documents d ON d.id = e.document_id
        WHERE (1 - (e.embedding <=> $1::vector)) >= $2
        #{build_filter_conditions(filters)}
        ORDER BY e.embedding <=> $1::vector
        LIMIT $3
      SQL

      bind_values = [embedding.to_s, threshold, limit]
      add_filter_bindings(filters, bind_values)

      results = ActiveRecord::Base.connection.exec_query(sql, 'search_similar', bind_values)
      
      results.map do |row|
        {
          embedding_id: row['id'],
          document_id: row['document_id'],
          document_title: row['title'],
          document_location: row['location'],
          document_type: row['document_type'],
          content: row['content'],
          similarity: row['similarity'].to_f,
          distance: row['distance'].to_f,
          chunk_index: row['chunk_index'],
          metadata: JSON.parse(row['metadata'] || '{}')
        }
      end
    end

    def format_context_results(results, prompt)
      {
        prompt: prompt,
        context_chunks: results.map do |result|
          {
            content: result[:content],
            source: {
              document_id: result[:document_id],
              document_title: result[:document_title],
              chunk_index: result[:chunk_index]
            },
            relevance_score: result[:similarity]
          }
        end,
        total_chunks: results.length,
        combined_context: results.map { |r| r[:content] }.join("\n\n---\n\n")
      }
    end

    def format_search_results(results, query)
      {
        query: query,
        results: results.map do |result|
          {
            id: result[:embedding_id],
            content: result[:content],
            document: {
              id: result[:document_id],
              title: result[:document_title],
              location: result[:document_location],
              type: result[:document_type]
            },
            similarity: result[:similarity],
            chunk_index: result[:chunk_index],
            metadata: result[:metadata]
          }
        end,
        total_results: results.length
      }
    end

    def format_document_response(document, include_content: false)
      response = {
        id: document.id,
        title: document.title,
        location: document.location,
        document_type: document.document_type,
        source_type: document.source_type,
        status: document.status,
        metadata: document.metadata,
        embeddings_count: document.ragdoll_embeddings.count,
        created_at: document.created_at,
        updated_at: document.updated_at,
        processing_started_at: document.processing_started_at,
        processing_finished_at: document.processing_finished_at
      }
      
      response[:content] = document.content if include_content
      response
    end

    def add_document_from_file(file_path, process_immediately: false, **options)
      # Queue the import job
      job = ImportFileJob.perform_later(file_path)
      
      if process_immediately
        job = ImportFileJob.perform_now(file_path)
        return format_document_response(job) if job.is_a?(Ragdoll::Document)
      end

      { 
        success: true, 
        message: "Document queued for processing",
        job_id: job.job_id 
      }
    end

    def add_document_from_content(content, title:, document_type: 'text', **options)
      document = Ragdoll::Document.create!(
        location: "content://#{SecureRandom.uuid}",
        content: content,
        title: title,
        document_type: document_type,
        source_type: 'api',
        metadata: options[:metadata] || {},
        chunk_size: options[:chunk_size] || Ragdoll.configuration.chunk_size,
        chunk_overlap: options[:chunk_overlap] || Ragdoll.configuration.chunk_overlap,
        status: 'pending'
      )

      if options[:process_immediately]
        ImportFileJob.perform_now(document.id)
      else
        ImportFileJob.perform_later(document.id)
      end

      format_document_response(document)
    end

    def reprocess_document(document)
      document.ragdoll_embeddings.destroy_all
      document.update!(status: 'pending', processing_started_at: nil, processing_finished_at: nil)
      ImportFileJob.perform_now(document.id)
    end

    def find_document(document_id)
      document = Ragdoll::Document.find_by(id: document_id)
      raise DocumentError, "Document not found: #{document_id}" unless document
      document
    end

    def store_search_record(query, query_embedding, results, filters)
      Ragdoll::Search.create!(
        query: query,
        query_embedding: query_embedding,
        search_type: 'semantic',
        filters: filters,
        results: { result_ids: results.map { |r| r[:embedding_id] } },
        result_count: results.length,
        model_name: Ragdoll.configuration.embedding_model
      )
    rescue => e
      Rails.logger.warn "Failed to store search record: #{e.message}"
    end

    def build_filter_conditions(filters)
      conditions = []
      
      if filters[:document_type]
        conditions << "AND d.document_type = $#{conditions.length + 4}"
      end
      
      if filters[:document_status]
        conditions << "AND d.status = $#{conditions.length + 4}"
      end
      
      if filters[:created_after]
        conditions << "AND d.created_at >= $#{conditions.length + 4}"
      end
      
      conditions.join(' ')
    end

    def add_filter_bindings(filters, bind_values)
      bind_values << filters[:document_type] if filters[:document_type]
      bind_values << filters[:document_status] if filters[:document_status]
      bind_values << filters[:created_after] if filters[:created_after]
    end
  end
end