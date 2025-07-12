# frozen_string_literal: true

require 'thor'
require 'json'

module Ragdoll
  class Document < Thor
    desc "add LOCATION", "Add a document to the Ragdoll database"
    method_option :content, aliases: "-c", type: :string, desc: "Document content (if not reading from file)"
    method_option :title, aliases: "-t", type: :string, desc: "Document title"
    method_option :document_type, aliases: "--type", type: :string, desc: "Document type (text, pdf, markdown, etc.)"
    method_option :source_type, aliases: "-s", type: :string, desc: "Source type (file, url, api, etc.)"
    method_option :metadata, aliases: "-m", type: :string, desc: "JSON metadata for the document"
    method_option :chunk_size, type: :numeric, default: 1000, desc: "Chunk size for text splitting"
    method_option :chunk_overlap, type: :numeric, default: 200, desc: "Chunk overlap for text splitting"
    method_option :process_now, aliases: "-p", type: :boolean, default: false, desc: "Process embeddings immediately"
    def add(location)
      require_environment!
      
      content = options[:content]
      if content.nil? && File.exist?(location)
        content = File.read(location)
      elsif content.nil?
        say "Error: Content not provided and file doesn't exist at #{location}", :red
        exit 1
      end

      metadata = {}
      if options[:metadata]
        begin
          metadata = JSON.parse(options[:metadata])
        rescue JSON::ParserError => e
          say "Error parsing metadata JSON: #{e.message}", :red
          exit 1
        end
      end

      document = Ragdoll::Document.create!(
        location: location,
        content: content,
        title: options[:title] || File.basename(location),
        document_type: options[:document_type] || detect_document_type(location),
        source_type: options[:source_type] || 'file',
        metadata: metadata,
        chunk_size: options[:chunk_size],
        chunk_overlap: options[:chunk_overlap],
        status: 'pending'
      )

      say "Document created with ID: #{document.id}", :green
      
      if options[:process_now]
        say "Processing embeddings...", :yellow
        Ragdoll::ImportFileJob.perform_now(document.id)
        say "Embeddings processed successfully!", :green
      else
        say "Document queued for processing. Use 'ragdoll document:process #{document.id}' to process now.", :blue
      end
    end

    desc "update ID", "Update an existing document in the Ragdoll database"
    method_option :content, aliases: "-c", type: :string, desc: "New document content"
    method_option :title, aliases: "-t", type: :string, desc: "New document title"
    method_option :document_type, aliases: "--type", type: :string, desc: "New document type"
    method_option :metadata, aliases: "-m", type: :string, desc: "JSON metadata (will be merged with existing)"
    method_option :reprocess, aliases: "-r", type: :boolean, default: false, desc: "Reprocess embeddings after update"
    def update(id)
      require_environment!
      
      document = find_document(id)
      updates = {}
      
      updates[:content] = options[:content] if options[:content]
      updates[:title] = options[:title] if options[:title]
      updates[:document_type] = options[:document_type] if options[:document_type]
      
      if options[:metadata]
        begin
          new_metadata = JSON.parse(options[:metadata])
          updates[:metadata] = document.metadata.merge(new_metadata)
        rescue JSON::ParserError => e
          say "Error parsing metadata JSON: #{e.message}", :red
          exit 1
        end
      end

      if updates.any?
        document.update!(updates)
        say "Document #{id} updated successfully", :green
        
        if options[:reprocess] && (options[:content] || options[:metadata])
          say "Reprocessing embeddings...", :yellow
          document.ragdoll_embeddings.destroy_all
          document.update!(status: 'pending', processing_started_at: nil, processing_finished_at: nil)
          Ragdoll::ImportFileJob.perform_now(document.id)
          say "Embeddings reprocessed successfully!", :green
        end
      else
        say "No updates provided", :yellow
      end
    end

    desc "delete ID", "Delete a document and its embeddings from the Ragdoll database"
    method_option :confirm, aliases: "-y", type: :boolean, default: false, desc: "Skip confirmation prompt"
    def delete(id)
      require_environment!
      
      document = find_document(id)
      
      unless options[:confirm]
        response = ask("Are you sure you want to delete document '#{document.title}' (ID: #{id})? This will also delete all associated embeddings. [y/N]")
        unless response.downcase.start_with?('y')
          say "Deletion cancelled", :yellow
          return
        end
      end

      embeddings_count = document.ragdoll_embeddings.count
      document.destroy!
      
      say "Document #{id} and #{embeddings_count} associated embeddings deleted successfully", :green
    end

    desc "list", "List all documents in the Ragdoll database"
    method_option :limit, aliases: "-l", type: :numeric, default: 20, desc: "Number of documents to show"
    method_option :status, aliases: "-s", type: :string, desc: "Filter by status (pending, processing, completed, failed)"
    method_option :type, aliases: "-t", type: :string, desc: "Filter by document type"
    method_option :format, aliases: "-f", type: :string, default: "table", desc: "Output format (table, json, csv)"
    def list
      require_environment!
      
      documents = Ragdoll::Document.all
      documents = documents.where(status: options[:status]) if options[:status]
      documents = documents.where(document_type: options[:document_type]) if options[:document_type]
      documents = documents.limit(options[:limit])

      case options[:format]
      when 'json'
        puts documents.to_json
      when 'csv'
        require 'csv'
        puts CSV.generate do |csv|
          csv << ['ID', 'Title', 'Type', 'Status', 'Location', 'Created At']
          documents.each do |doc|
            csv << [doc.id, doc.title, doc.document_type, doc.status, doc.location, doc.created_at]
          end
        end
      else
        print_table([['ID', 'Title', 'Type', 'Status', 'Embeddings', 'Created At']] +
                    documents.map do |doc|
                      [
                        doc.id,
                        truncate(doc.title, 30),
                        doc.document_type || 'unknown',
                        doc.status,
                        doc.ragdoll_embeddings.count,
                        doc.created_at.strftime('%Y-%m-%d %H:%M')
                      ]
                    end)
      end
    end

    desc "show ID", "Show detailed information about a document"
    def show(id)
      require_environment!
      
      document = find_document(id)
      
      say "\n=== Document Details ===", :cyan
      say "ID: #{document.id}"
      say "Title: #{document.title}"
      say "Location: #{document.location}"
      say "Type: #{document.document_type || 'unknown'}"
      say "Source: #{document.source_type || 'unknown'}"
      say "Status: #{document.status}"
      say "Chunk Size: #{document.chunk_size}"
      say "Chunk Overlap: #{document.chunk_overlap}"
      say "Created: #{document.created_at}"
      say "Updated: #{document.updated_at}"
      
      if document.processing_started_at
        say "Processing Started: #{document.processing_started_at}"
      end
      
      if document.processing_finished_at
        say "Processing Finished: #{document.processing_finished_at}"
      end
      
      embeddings_count = document.ragdoll_embeddings.count
      say "Embeddings: #{embeddings_count}"
      
      if document.metadata.any?
        say "\n=== Metadata ===", :cyan
        document.metadata.each do |key, value|
          say "#{key}: #{value}"
        end
      end
      
      if document.content && document.content.length > 0
        say "\n=== Content Preview ===", :cyan
        say truncate(document.content, 500)
      end
    end

    desc "process ID", "Process embeddings for a document"
    def process(id)
      require_environment!
      
      document = find_document(id)
      
      if document.status == 'processing'
        say "Document is already being processed", :yellow
        return
      end
      
      say "Processing embeddings for document #{id}...", :yellow
      Ragdoll::ImportFileJob.perform_now(document.id)
      say "Embeddings processed successfully!", :green
    end

    desc "reprocess ID", "Reprocess embeddings for a document (removes existing embeddings first)"
    method_option :confirm, aliases: "-y", type: :boolean, default: false, desc: "Skip confirmation prompt"
    def reprocess(id)
      require_environment!
      
      document = find_document(id)
      embeddings_count = document.ragdoll_embeddings.count
      
      unless options[:confirm]
        response = ask("This will delete #{embeddings_count} existing embeddings and recreate them. Continue? [y/N]")
        unless response.downcase.start_with?('y')
          say "Reprocessing cancelled", :yellow
          return
        end
      end
      
      say "Removing existing embeddings...", :yellow
      document.ragdoll_embeddings.destroy_all
      document.update!(status: 'pending', processing_started_at: nil, processing_finished_at: nil)
      
      say "Processing new embeddings...", :yellow
      Ragdoll::ImportFileJob.perform_now(document.id)
      say "Embeddings reprocessed successfully!", :green
    end

    private

    def require_environment!
      unless defined?(Rails) && Rails.application
        begin
          require File.expand_path('config/environment', Dir.pwd)
        rescue LoadError
          say "Error: Rails environment not found. Run this command from a Rails application root.", :red
          exit 1
        end
      end
    end

    def find_document(id)
      document = Ragdoll::Document.find_by(id: id)
      unless document
        say "Document with ID #{id} not found", :red
        exit 1
      end
      document
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
      when '.doc' then 'doc'
      when '.rtf' then 'rtf'
      when '.odt' then 'odt'
      else 'unknown'
      end
    end

    def truncate(text, length)
      return text unless text
      text.length > length ? "#{text[0, length-3]}..." : text
    end
  end
end