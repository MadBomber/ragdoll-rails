# frozen_string_literal: true

namespace :ragdoll do
  namespace :document do
    desc "Add a document to the Ragdoll database"
    task :add, [:location] => :environment do |t, args|
      location = args[:location] || ENV['LOCATION']
      content = ENV['CONTENT']
      title = ENV['TITLE']
      document_type = ENV['TYPE']
      source_type = ENV['SOURCE_TYPE'] || 'file'
      metadata_json = ENV['METADATA'] || '{}'
      chunk_size = (ENV['CHUNK_SIZE'] || 1000).to_i
      chunk_overlap = (ENV['CHUNK_OVERLAP'] || 200).to_i
      process_now = ENV['PROCESS_NOW'] == 'true'

      if location.nil?
        puts "Error: LOCATION is required"
        puts "Usage: rake ragdoll:document:add[/path/to/file] or LOCATION=/path/to/file rake ragdoll:document:add"
        exit 1
      end

      if content.nil? && File.exist?(location)
        content = File.read(location)
      elsif content.nil?
        puts "Error: Content not provided and file doesn't exist at #{location}"
        exit 1
      end

      begin
        metadata = JSON.parse(metadata_json)
      rescue JSON::ParserError => e
        puts "Error parsing metadata JSON: #{e.message}"
        exit 1
      end

      document = Ragdoll::Document.create!(
        location: location,
        content: content,
        title: title || File.basename(location),
        document_type: document_type || detect_document_type(location),
        source_type: source_type,
        metadata: metadata,
        chunk_size: chunk_size,
        chunk_overlap: chunk_overlap,
        status: 'pending'
      )

      puts "Document created with ID: #{document.id}"
      
      if process_now
        puts "Processing embeddings..."
        Ragdoll::ImportFileJob.perform_now(document.id)
        puts "Embeddings processed successfully!"
      else
        puts "Document queued for processing. Use 'rake ragdoll:document:process[#{document.id}]' to process now."
      end
    end

    desc "Update an existing document"
    task :update, [:id] => :environment do |t, args|
      id = args[:id] || ENV['ID']
      content = ENV['CONTENT']
      title = ENV['TITLE']
      document_type = ENV['TYPE']
      metadata_json = ENV['METADATA']
      reprocess = ENV['REPROCESS'] == 'true'

      if id.nil?
        puts "Error: Document ID is required"
        puts "Usage: rake ragdoll:document:update[123] or ID=123 rake ragdoll:document:update"
        exit 1
      end

      document = Ragdoll::Document.find_by(id: id)
      unless document
        puts "Document with ID #{id} not found"
        exit 1
      end

      updates = {}
      updates[:content] = content if content
      updates[:title] = title if title
      updates[:document_type] = document_type if document_type
      
      if metadata_json
        begin
          new_metadata = JSON.parse(metadata_json)
          updates[:metadata] = document.metadata.merge(new_metadata)
        rescue JSON::ParserError => e
          puts "Error parsing metadata JSON: #{e.message}"
          exit 1
        end
      end

      if updates.any?
        document.update!(updates)
        puts "Document #{id} updated successfully"
        
        if reprocess && (content || metadata_json)
          puts "Reprocessing embeddings..."
          document.ragdoll_embeddings.destroy_all
          document.update!(status: 'pending', processing_started_at: nil, processing_finished_at: nil)
          Ragdoll::ImportFileJob.perform_now(document.id)
          puts "Embeddings reprocessed successfully!"
        end
      else
        puts "No updates provided"
      end
    end

    desc "Delete a document and its embeddings"
    task :delete, [:id] => :environment do |t, args|
      id = args[:id] || ENV['ID']
      confirm = ENV['CONFIRM'] == 'true'

      if id.nil?
        puts "Error: Document ID is required"
        puts "Usage: rake ragdoll:document:delete[123] or ID=123 rake ragdoll:document:delete"
        exit 1
      end

      document = Ragdoll::Document.find_by(id: id)
      unless document
        puts "Document with ID #{id} not found"
        exit 1
      end

      unless confirm
        print "Are you sure you want to delete document '#{document.title}' (ID: #{id})? This will also delete all associated embeddings. [y/N] "
        response = STDIN.gets.chomp
        unless response.downcase.start_with?('y')
          puts "Deletion cancelled"
          exit 0
        end
      end

      embeddings_count = document.ragdoll_embeddings.count
      document.destroy!
      
      puts "Document #{id} and #{embeddings_count} associated embeddings deleted successfully"
    end

    desc "List all documents"
    task :list => :environment do
      limit = (ENV['LIMIT'] || 20).to_i
      status = ENV['STATUS']
      document_type = ENV['TYPE']
      format = ENV['FORMAT'] || 'table'

      documents = Ragdoll::Document.all
      documents = documents.where(status: status) if status
      documents = documents.where(document_type: document_type) if document_type
      documents = documents.limit(limit)

      case format
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
        printf "%-5s %-30s %-12s %-10s %-5s %-16s\n", 'ID', 'Title', 'Type', 'Status', 'Emb', 'Created At'
        puts "-" * 80
        documents.each do |doc|
          printf "%-5s %-30s %-12s %-10s %-5s %-16s\n",
                 doc.id,
                 truncate_text(doc.title, 30),
                 doc.document_type || 'unknown',
                 doc.status,
                 doc.ragdoll_embeddings.count,
                 doc.created_at.strftime('%Y-%m-%d %H:%M')
        end
      end
    end

    desc "Show detailed information about a document"
    task :show, [:id] => :environment do |t, args|
      id = args[:id] || ENV['ID']

      if id.nil?
        puts "Error: Document ID is required"
        puts "Usage: rake ragdoll:document:show[123] or ID=123 rake ragdoll:document:show"
        exit 1
      end

      document = Ragdoll::Document.find_by(id: id)
      unless document
        puts "Document with ID #{id} not found"
        exit 1
      end

      puts "\n=== Document Details ==="
      puts "ID: #{document.id}"
      puts "Title: #{document.title}"
      puts "Location: #{document.location}"
      puts "Type: #{document.document_type || 'unknown'}"
      puts "Source: #{document.source_type || 'unknown'}"
      puts "Status: #{document.status}"
      puts "Chunk Size: #{document.chunk_size}"
      puts "Chunk Overlap: #{document.chunk_overlap}"
      puts "Created: #{document.created_at}"
      puts "Updated: #{document.updated_at}"
      
      if document.processing_started_at
        puts "Processing Started: #{document.processing_started_at}"
      end
      
      if document.processing_finished_at
        puts "Processing Finished: #{document.processing_finished_at}"
      end
      
      embeddings_count = document.ragdoll_embeddings.count
      puts "Embeddings: #{embeddings_count}"
      
      if document.metadata.any?
        puts "\n=== Metadata ==="
        document.metadata.each do |key, value|
          puts "#{key}: #{value}"
        end
      end
      
      if document.content && document.content.length > 0
        puts "\n=== Content Preview ==="
        puts truncate_text(document.content, 500)
      end
    end

    desc "Process embeddings for a document"
    task :process, [:id] => :environment do |t, args|
      id = args[:id] || ENV['ID']

      if id.nil?
        puts "Error: Document ID is required"
        puts "Usage: rake ragdoll:document:process[123] or ID=123 rake ragdoll:document:process"
        exit 1
      end

      document = Ragdoll::Document.find_by(id: id)
      unless document
        puts "Document with ID #{id} not found"
        exit 1
      end

      if document.status == 'processing'
        puts "Document is already being processed"
        exit 0
      end
      
      puts "Processing embeddings for document #{id}..."
      Ragdoll::ImportFileJob.perform_now(document.id)
      puts "Embeddings processed successfully!"
    end

    desc "Reprocess embeddings for a document (removes existing embeddings first)"
    task :reprocess, [:id] => :environment do |t, args|
      id = args[:id] || ENV['ID']
      confirm = ENV['CONFIRM'] == 'true'

      if id.nil?
        puts "Error: Document ID is required"
        puts "Usage: rake ragdoll:document:reprocess[123] or ID=123 rake ragdoll:document:reprocess"
        exit 1
      end

      document = Ragdoll::Document.find_by(id: id)
      unless document
        puts "Document with ID #{id} not found"
        exit 1
      end

      embeddings_count = document.ragdoll_embeddings.count
      
      unless confirm
        print "This will delete #{embeddings_count} existing embeddings and recreate them. Continue? [y/N] "
        response = STDIN.gets.chomp
        unless response.downcase.start_with?('y')
          puts "Reprocessing cancelled"
          exit 0
        end
      end
      
      puts "Removing existing embeddings..."
      document.ragdoll_embeddings.destroy_all
      document.update!(status: 'pending', processing_started_at: nil, processing_finished_at: nil)
      
      puts "Processing new embeddings..."
      Ragdoll::ImportFileJob.perform_now(document.id)
      puts "Embeddings reprocessed successfully!"
    end

    namespace :bulk do
      desc "Delete all documents with a specific status"
      task :delete_by_status, [:status] => :environment do |t, args|
        status = args[:status] || ENV['STATUS']
        confirm = ENV['CONFIRM'] == 'true'

        if status.nil?
          puts "Error: Status is required"
          puts "Usage: rake ragdoll:document:bulk:delete_by_status[failed] or STATUS=failed rake ragdoll:document:bulk:delete_by_status"
          exit 1
        end

        documents = Ragdoll::Document.where(status: status)
        count = documents.count

        unless confirm
          print "This will delete #{count} documents with status '#{status}' and all their embeddings. Continue? [y/N] "
          response = STDIN.gets.chomp
          unless response.downcase.start_with?('y')
            puts "Bulk deletion cancelled"
            exit 0
          end
        end

        embeddings_count = Ragdoll::Embedding.joins(:document).where(ragdoll_documents: { status: status }).count
        documents.destroy_all
        
        puts "Deleted #{count} documents and #{embeddings_count} embeddings with status '#{status}'"
      end

      desc "Reprocess all failed documents"
      task :reprocess_failed => :environment do
        failed_documents = Ragdoll::Document.where(status: 'failed')
        count = failed_documents.count
        
        puts "Found #{count} failed documents to reprocess"
        
        failed_documents.find_each do |document|
          puts "Reprocessing document #{document.id}: #{document.title}"
          document.ragdoll_embeddings.destroy_all
          document.update!(status: 'pending', processing_started_at: nil, processing_finished_at: nil)
          
          begin
            Ragdoll::ImportFileJob.perform_now(document.id)
            puts "  ✓ Success"
          rescue => e
            puts "  ✗ Failed: #{e.message}"
          end
        end
        
        puts "Bulk reprocessing completed"
      end

      desc "Clean up orphaned embeddings (embeddings without documents)"
      task :cleanup_orphaned => :environment do
        orphaned_count = Ragdoll::Embedding.left_joins(:document).where(ragdoll_documents: { id: nil }).count
        
        if orphaned_count > 0
          puts "Found #{orphaned_count} orphaned embeddings"
          Ragdoll::Embedding.left_joins(:document).where(ragdoll_documents: { id: nil }).delete_all
          puts "Cleaned up #{orphaned_count} orphaned embeddings"
        else
          puts "No orphaned embeddings found"
        end
      end
    end
  end

  # Helper methods
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

  def truncate_text(text, length)
    return text unless text
    text.length > length ? "#{text[0, length-3]}..." : text
  end
end