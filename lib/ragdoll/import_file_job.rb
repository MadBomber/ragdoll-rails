# frozen_string_literal: true

module Ragdoll
  class ImportFileJob < ActiveJob::Base
    queue_as :default

    def perform(document_id)
      Rails.logger.info "Starting ImportFileJob for document #{document_id}"
      
      document = Ragdoll::Document.find(document_id)
      
      if document.location.present? && File.exist?(document.location)
        process_file_document(document)
      else
        process_existing_document(document)
      end
      
      Rails.logger.info "ImportFileJob completed successfully for document #{document_id}"
    rescue => e
      Rails.logger.error "ImportFileJob failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Mark document as failed with error details
      begin
        document = Ragdoll::Document.find(document_id)
        error_metadata = document.metadata || {}
        error_metadata['last_error'] = {
          message: e.message,
          backtrace: e.backtrace&.first(5),
          timestamp: Time.current.iso8601
        }
        
        document.update!(
          status: 'failed',
          processing_finished_at: Time.current,
          metadata: error_metadata
        )
      rescue => update_error
        Rails.logger.error "Failed to update document error status: #{update_error.message}"
      end
      
      # Don't re-raise in background job to prevent job retry loops
      # raise e
    end

    private

    def process_existing_document(document)
      Rails.logger.info "Processing existing document #{document.id} with content length: #{document.content&.length || 0}"
      
      # Mark as processing
      document.update!(
        processing_started_at: Time.current,
        processing_finished_at: nil,
        status: 'processing'
      )

      # Use existing content
      content = document.content
      
      if content.blank?
        Rails.logger.error "Document #{document.id} has no content to process"
        document.update!(
          status: 'failed',
          processing_finished_at: Time.current
        )
        return
      end

      process_document_content(document, content)
    end

    def process_file_document(document)
      Rails.logger.info "Processing file document #{document.id} from: #{document.location}"
      
      # Mark as processing
      document.update!(
        processing_started_at: Time.current,
        processing_finished_at: nil,
        status: 'processing'
      )

      # Read file content
      content = File.read(document.location)
      
      # Update document with content if not already set
      if document.content.blank?
        document.update!(content: content)
      end

      process_document_content(document, content)
    end

    def process_document_content(document, content)
      Rails.logger.info "Processing content for document #{document.id}"
      
      # Generate document summary if enabled
      begin
        if Ragdoll.configuration&.enable_document_summarization
          Rails.logger.info "Generating summary for document #{document.id}"
          generate_document_summary(document, content)
        end
      rescue => e
        Rails.logger.warn "Failed to generate summary for document #{document.id}: #{e.message}"
        # Continue processing even if summary fails
      end

      # Generate chunks from content with safe defaults
      chunk_size = document.chunk_size || Ragdoll.configuration&.chunk_size || 1000
      chunk_overlap = document.chunk_overlap || Ragdoll.configuration&.chunk_overlap || 200
      
      Rails.logger.info "Chunking content with size: #{chunk_size}, overlap: #{chunk_overlap}"
      
      chunks = TextChunker.chunk(
        content,
        chunk_size: chunk_size,
        chunk_overlap: chunk_overlap
      )

      Rails.logger.info "Generated #{chunks.size} chunks for document #{document.id}"

      # Create embeddings for each chunk
      # Skip embedding service in demo mode to avoid API calls
      if Rails.env.development? || Rails.env.test?
        create_demo_embeddings(document, chunks)
      else
        embedding_service = EmbeddingService.new
        create_real_embeddings(document, chunks, embedding_service)
      end

      # Mark as completed
      document.update!(
        status: 'completed',
        processing_finished_at: Time.current
      )
      
      Rails.logger.info "Document #{document.id} processing completed successfully"
    end

    def create_demo_embeddings(document, chunks)
      Rails.logger.info "Creating demo embeddings for document #{document.id}"
      
      chunks.each_with_index do |chunk, index|
        # Generate dummy vector for demo
        dummy_vector = Array.new(1536) { rand(-1.0..1.0) }
        
        Ragdoll::Embedding.create!(
          document: document,
          content: chunk,
          chunk_index: index,
          embedding: dummy_vector.to_json,
          model_name: 'demo-embedding-model',
          usage_count: 0,
          metadata: {
            dimensions: 1536,
            provider: 'demo',
            created_at: Time.current.iso8601
          }
        )
      end
      
      Rails.logger.info "Created #{chunks.size} demo embeddings for document #{document.id}"
    end

    def create_real_embeddings(document, chunks, embedding_service)
      Rails.logger.info "Creating real embeddings for document #{document.id}"
      
      chunks.each_with_index do |chunk, index|
        begin
          # Generate embedding using the service
          embedding_response = embedding_service.generate_embedding(chunk)
          
          Ragdoll::Embedding.create!(
            document: document,
            content: chunk,
            chunk_index: index,
            embedding: embedding_response[:embedding].to_json,
            model_name: embedding_response[:model] || 'unknown',
            usage_count: 0,
            metadata: {
              dimensions: embedding_response[:embedding]&.size || 0,
              provider: embedding_response[:provider] || 'unknown',
              created_at: Time.current.iso8601
            }
          )
        rescue => e
          Rails.logger.error "Failed to create embedding for chunk #{index} of document #{document.id}: #{e.message}"
          # Continue with other chunks even if one fails
        end
      end
      
      Rails.logger.info "Created embeddings for document #{document.id}"
    end

    def generate_document_summary(document, content)
      Rails.logger.info "Generating summary for document #{document.id}"
      
      begin
        summarization_service = Ragdoll::SummarizationService.new
        summary = summarization_service.generate_summary(content)
        
        if summary.present?
          document.update!(
            summary: summary,
            summary_generated_at: Time.current,
            summary_model: Ragdoll.configuration&.summary_model || 'demo-model'
          )
          Rails.logger.info "Generated summary for document #{document.id}"
        end
      rescue => e
        Rails.logger.error "Failed to generate summary for document #{document.id}: #{e.message}"
        # Don't fail the entire job if summary generation fails
      end
    end
  end
end