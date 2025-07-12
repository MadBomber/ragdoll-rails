# frozen_string_literal: true

require_relative '../ragdoll'
require_relative 'configuration'
require_relative 'standalone_configuration'
require_relative 'standalone_storage'
require_relative 'document_parser'
require_relative 'text_chunker'

module Ragdoll
  class StandaloneClient
    attr_reader :storage, :embedding_service
    
    def initialize(storage_dir: nil, config_file: nil)
      # Load configuration first
      load_configuration(config_file)
      
      @storage = StandaloneStorage.new(storage_dir: storage_dir)
      @embedding_service = create_embedding_service
    end
    
    def add_file(file_path, **options)
      unless File.exist?(file_path)
        raise Ragdoll::DocumentError, "File not found: #{file_path}"
      end
      
      parsed_result = DocumentParser.parse(file_path)
      content = parsed_result[:content]
      title = options[:title] || parsed_result[:metadata][:title] || File.basename(file_path)
      document_type = options[:document_type] || parsed_result[:document_type] || detect_document_type(file_path)
      metadata = (parsed_result[:metadata] || {}).merge(options[:metadata] || {})
      
      add_document(file_path, content, title: title, document_type: document_type, metadata: metadata)
    end
    
    def add_directory(directory_path, recursive: false, **options)
      unless Dir.exist?(directory_path)
        raise Ragdoll::DocumentError, "Directory not found: #{directory_path}"
      end
      
      pattern = recursive ? "#{directory_path}/**/*" : "#{directory_path}/*"
      files = Dir.glob(pattern).select { |f| File.file?(f) }
      
      results = []
      files.each do |file_path|
        begin
          result = add_file(file_path, **options)
          results << result
        rescue => e
          puts "Warning: Failed to process #{file_path}: #{e.message}"
        end
      end
      
      {
        total_files: files.length,
        processed_files: results.length,
        failed_files: files.length - results.length,
        results: results
      }
    end
    
    def add_document(location, content, title: nil, document_type: nil, metadata: {})
      # Store the document
      document = @storage.add_document(location, content, 
                                     title: title, 
                                     document_type: document_type, 
                                     metadata: metadata)
      
      # Process the content into chunks and generate embeddings
      process_document_content(document[:id], content)
      
      document
    end
    
    def search(query, limit: 10, threshold: 0.7, **options)
      if @embedding_service.nil?
        return simple_text_search(query, limit: limit)
      end
      
      begin
        query_embedding = @embedding_service.generate_embedding(query)
        if query_embedding.nil?
          return simple_text_search(query, limit: limit)
        end
        
        results = @storage.search_similar(query_embedding, limit: limit, threshold: threshold)
        
        format_search_results(query, results)
      rescue => e
        puts "Warning: Embedding search failed: #{e.message}"
        simple_text_search(query, limit: limit)
      end
    end
    
    def list_documents
      @storage.list_documents
    end
    
    def get_document(doc_id)
      @storage.get_document(doc_id)
    end
    
    def stats
      @storage.stats
    end
    
    def healthy?
      @storage.stats[:total_documents] >= 0
    rescue
      false
    end
    
    private
    
    def load_configuration(config_file = nil)
      StandaloneConfiguration.load_configuration(config_file)
    end
    
    def create_embedding_service
      # Try to create an embedding service, but don't fail if API keys aren't available
      return nil unless ENV['OPENAI_API_KEY']
      
      begin
        require_relative 'embedding_service'
        EmbeddingService.new
      rescue LoadError, StandardError => e
        puts "Warning: Embedding service not available: #{e.message}"
        puts "Falling back to text-based search"
        nil
      end
    end
    
    def process_document_content(doc_id, content)
      # Chunk the content
      chunks = TextChunker.chunk(content, chunk_size: 1000, chunk_overlap: 200)
      
      chunks.each_with_index do |chunk_text, index|
        chunk = @storage.add_chunk(doc_id, chunk_text, index)
        
        # Generate embedding if service is available
        if @embedding_service
          begin
            embedding = @embedding_service.generate_embedding(chunk_text)
            @storage.add_embedding(chunk[:id], embedding) if embedding
          rescue => e
            puts "Warning: Failed to generate embedding for chunk #{index}: #{e.message}"
          end
        end
      end
    end
    
    def simple_text_search(query, limit: 10)
      # Fallback to simple text search when embeddings aren't available
      documents = @storage.list_documents
      results = []
      
      query_words = query.downcase.split(/\s+/)
      
      documents.each do |doc|
        content_lower = doc[:content].downcase
        score = query_words.count { |word| content_lower.include?(word) }
        
        if score > 0
          results << {
            document: doc,
            score: score,
            similarity: score.to_f / query_words.length
          }
        end
      end
      
      # Sort by score and limit results
      sorted_results = results.sort_by { |r| -r[:score] }.first(limit)
      
      format_search_results(query, sorted_results, is_text_search: true)
    end
    
    def format_search_results(query, results, is_text_search: false)
      {
        query: query,
        search_type: is_text_search ? 'text_based' : 'embedding_based',
        results: results.map do |result|
          if is_text_search
            {
              document_id: result[:document][:id],
              title: result[:document][:title],
              location: result[:document][:location],
              score: result[:score],
              similarity: result[:similarity],
              content_preview: result[:document][:content][0..200] + "..."
            }
          else
            {
              document_id: result[:document][:id],
              title: result[:document][:title],
              location: result[:document][:location],
              chunk_id: result[:chunk_id],
              similarity: result[:similarity],
              content_preview: result[:chunk][:content][0..200] + "..."
            }
          end
        end,
        total_results: results.length
      }
    end
    
    def detect_document_type(file_path)
      case File.extname(file_path).downcase
      when '.txt' then 'text'
      when '.md', '.markdown' then 'markdown'
      when '.pdf' then 'pdf'
      when '.docx' then 'docx'
      when '.html', '.htm' then 'html'
      when '.json' then 'json'
      when '.xml' then 'xml'
      when '.csv' then 'csv'
      else 'unknown'
      end
    end
  end
end