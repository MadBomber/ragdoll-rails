# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'digest'

module Ragdoll
  class StandaloneStorage
    DEFAULT_STORAGE_DIR = File.expand_path('~/.ragdoll')
    DOCUMENTS_FILE = 'documents.json'
    EMBEDDINGS_FILE = 'embeddings.json'
    CHUNKS_FILE = 'chunks.json'
    
    attr_reader :storage_dir
    
    def initialize(storage_dir: nil)
      @storage_dir = storage_dir || DEFAULT_STORAGE_DIR
      ensure_storage_directory
    end
    
    def add_document(location, content, title: nil, document_type: nil, metadata: {})
      doc_id = generate_document_id(location, content)
      
      document = {
        id: doc_id,
        location: location,
        title: title || File.basename(location),
        content: content,
        document_type: document_type || detect_document_type(location),
        metadata: metadata,
        created_at: Time.now.iso8601,
        updated_at: Time.now.iso8601,
        status: 'completed'
      }
      
      documents = load_documents
      documents[doc_id] = document
      save_documents(documents)
      
      document
    end
    
    def get_document(doc_id)
      documents = load_documents
      documents[doc_id]
    end
    
    def list_documents
      load_documents.values
    end
    
    def add_chunk(doc_id, chunk_text, chunk_index, embedding = nil)
      chunk_id = "#{doc_id}_chunk_#{chunk_index}"
      
      chunk = {
        id: chunk_id,
        document_id: doc_id,
        content: chunk_text,
        chunk_index: chunk_index,
        created_at: Time.now.iso8601
      }
      
      chunks = load_chunks
      chunks[chunk_id] = chunk
      save_chunks(chunks)
      
      # Store embedding separately if provided
      if embedding
        add_embedding(chunk_id, embedding)
      end
      
      chunk
    end
    
    def add_embedding(chunk_id, embedding)
      embeddings = load_embeddings
      embeddings[chunk_id] = {
        chunk_id: chunk_id,
        embedding: embedding,
        created_at: Time.now.iso8601
      }
      save_embeddings(embeddings)
    end
    
    def get_embeddings
      load_embeddings
    end
    
    def search_similar(query_embedding, limit: 10, threshold: 0.7)
      embeddings = load_embeddings
      chunks = load_chunks
      documents = load_documents
      
      similarities = []
      
      embeddings.each do |chunk_id, embedding_data|
        similarity = cosine_similarity(query_embedding, embedding_data[:embedding])
        
        if similarity >= threshold
          chunk = chunks[chunk_id]
          document = documents[chunk[:document_id]] if chunk
          
          similarities << {
            chunk_id: chunk_id,
            similarity: similarity,
            chunk: chunk,
            document: document
          }
        end
      end
      
      # Sort by similarity and limit results
      similarities.sort_by { |s| -s[:similarity] }.first(limit)
    end
    
    def stats
      documents = load_documents
      chunks = load_chunks
      embeddings = load_embeddings
      
      {
        total_documents: documents.size,
        total_chunks: chunks.size,
        total_embeddings: embeddings.size,
        storage_dir: @storage_dir
      }
    end
    
    private
    
    def ensure_storage_directory
      FileUtils.mkdir_p(@storage_dir) unless Dir.exist?(@storage_dir)
    end
    
    def documents_file_path
      File.join(@storage_dir, DOCUMENTS_FILE)
    end
    
    def embeddings_file_path
      File.join(@storage_dir, EMBEDDINGS_FILE)
    end
    
    def chunks_file_path
      File.join(@storage_dir, CHUNKS_FILE)
    end
    
    def load_documents
      return {} unless File.exist?(documents_file_path)
      JSON.parse(File.read(documents_file_path), symbolize_names: true)
    rescue JSON::ParserError
      {}
    end
    
    def save_documents(documents)
      File.write(documents_file_path, JSON.pretty_generate(documents))
    end
    
    def load_embeddings
      return {} unless File.exist?(embeddings_file_path)
      JSON.parse(File.read(embeddings_file_path), symbolize_names: true)
    rescue JSON::ParserError
      {}
    end
    
    def save_embeddings(embeddings)
      File.write(embeddings_file_path, JSON.pretty_generate(embeddings))
    end
    
    def load_chunks
      return {} unless File.exist?(chunks_file_path)
      JSON.parse(File.read(chunks_file_path), symbolize_names: true)
    rescue JSON::ParserError
      {}
    end
    
    def save_chunks(chunks)
      File.write(chunks_file_path, JSON.pretty_generate(chunks))
    end
    
    def generate_document_id(location, content)
      # Create a hash based on location and content
      Digest::SHA256.hexdigest("#{location}:#{content}")[0..15]
    end
    
    def detect_document_type(location)
      case File.extname(location).downcase
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
    
    def cosine_similarity(vec1, vec2)
      # Ensure both vectors are the same length
      return 0.0 if vec1.length != vec2.length
      
      dot_product = vec1.zip(vec2).map { |a, b| a * b }.sum
      magnitude1 = Math.sqrt(vec1.map { |x| x * x }.sum)
      magnitude2 = Math.sqrt(vec2.map { |x| x * x }.sum)
      
      return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0
      
      dot_product / (magnitude1 * magnitude2)
    end
  end
end