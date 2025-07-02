# frozen_string_literal: true

require_relative 'document_parser'
require_relative 'text_chunker'
require_relative 'embedding_service'

module Ragdoll
  class ImportFileJob < ActiveJob::Base
    def perform(document_id_or_path)
      if document_id_or_path.is_a?(Integer) || document_id_or_path.to_s.match?(/^\d+$/)
        process_existing_document(document_id_or_path.to_i)
      else
        process_file_path(document_id_or_path)
      end
    rescue => e
      Rails.logger.error "ImportFileJob failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      if document_id_or_path.is_a?(Integer) || document_id_or_path.to_s.match?(/^\d+$/)
        document = Ragdoll::Document.find_by(id: document_id_or_path.to_i)
        document&.update!(status: 'failed', processing_finished_at: Time.current)
      end
      
      raise e
    end

    private

    def process_existing_document(document_id)
      document = Ragdoll::Document.find(document_id)
      
      document.update!(
        status: 'processing',
        processing_started_at: Time.current,
        processing_finished_at: nil
      )

      if document.content.present?
        # Document already has content, just process embeddings
        process_document_content(document, document.content, document.metadata || {})
      elsif File.exist?(document.location)
        # Parse content from file
        parsed_data = DocumentParser.parse(document.location)
        
        # Update document with parsed content and metadata
        document.update!(
          content: parsed_data[:content],
          document_type: parsed_data[:document_type],
          metadata: (document.metadata || {}).merge(parsed_data[:metadata])
        )
        
        process_document_content(document, parsed_data[:content], parsed_data[:metadata])
      else
        raise DocumentError, "File not found: #{document.location} and no content available"
      end

      document.update!(
        status: 'completed',
        processing_finished_at: Time.current
      )
    end

    def process_file_path(file_path)
      return unless File.file?(file_path)
      return unless supported_file?(file_path)

      modification_time = File.mtime(file_path)
      existing_document = Ragdoll::Document.find_by(location: file_path)

      if existing_document && existing_document.updated_at >= modification_time
        Rails.logger.info "File #{file_path} is already up-to-date. Skipping import."
        return existing_document
      end

      # Parse the document
      parsed_data = DocumentParser.parse(file_path)
      
      # Create or update document record
      document = existing_document || Ragdoll::Document.new(location: file_path)
      
      document.assign_attributes(
        content: parsed_data[:content],
        title: parsed_data[:metadata][:title] || File.basename(file_path),
        document_type: parsed_data[:document_type],
        source_type: 'file',
        metadata: (document.metadata || {}).merge(parsed_data[:metadata]),
        status: 'processing',
        processing_started_at: Time.current,
        chunk_size: document.chunk_size || Ragdoll.configuration.chunk_size,
        chunk_overlap: document.chunk_overlap || Ragdoll.configuration.chunk_overlap
      )
      
      document.save!

      # Remove existing embeddings if updating
      document.ragdoll_embeddings.destroy_all if existing_document

      # Process the content
      process_document_content(document, parsed_data[:content], parsed_data[:metadata])

      document.update!(
        status: 'completed',
        processing_finished_at: Time.current
      )

      Rails.logger.info "Imported #{file_path} successfully. Document ID: #{document.id}"
      document
    end

    def process_document_content(document, content, metadata = {})
      return if content.blank?

      # Chunk the content
      chunks = TextChunker.chunk(
        content,
        chunk_size: document.chunk_size,
        chunk_overlap: document.chunk_overlap
      )

      # Create embeddings for each chunk
      embedding_service = EmbeddingService.new
      
      chunks.each_with_index do |chunk_content, index|
        next if chunk_content.strip.empty?

        # Generate embedding
        embedding_vector = embedding_service.generate_embedding(chunk_content)
        
        # Calculate token count (rough approximation)
        token_count = (chunk_content.split.length * 1.3).round

        # Store embedding
        document.ragdoll_embeddings.create!(
          content: chunk_content,
          embedding: embedding_vector,
          model_name: Ragdoll.configuration.embedding_model,
          token_count: token_count,
          chunk_index: index,
          metadata: {
            chunk_length: chunk_content.length,
            word_count: chunk_content.split.length
          }.merge(metadata)
        )
      end

      Rails.logger.info "Created #{chunks.length} embeddings for document #{document.id}"
    end

    def supported_file?(file_path)
      extension = File.extname(file_path).downcase
      supported_extensions = %w[.txt .md .markdown .pdf .docx .html .htm .json .xml .csv]
      
      if supported_extensions.include?(extension)
        true
      else
        Rails.logger.warn "Unsupported file type: #{extension} for file #{file_path}"
        false
      end
    end
  end
end
