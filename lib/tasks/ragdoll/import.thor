# frozen_string_literal: true

require 'thor'

module Ragdoll
  class Import < Thor
    desc "PATH", "Import documents from a file, glob, or directory"
    method_option :recursive, aliases: "-r", type: :boolean, default: false, desc: "Recursively import files from directories"
    method_option :jobs, aliases: ["-j", "--jobs"], type: :numeric, default: 1, desc: "Number of concurrent import jobs"
    def path_import(path)
      # Check if path exists first
      unless File.exist?(path)
        say "Error: Path '#{path}' does not exist.", :red
        exit 1
      end
      
      begin
        # Use standalone implementation
        require_relative '../../ragdoll/standalone_client'
        client = ::Ragdoll::StandaloneClient.new
        
        say "Starting import using standalone Ragdoll...", :cyan
        
        if File.directory?(path)
          say "Importing directory: #{path}", :blue
          say "Recursive: #{options[:recursive] ? 'Yes' : 'No'}", :blue
          
          result = client.add_directory(path, recursive: options[:recursive])
          
          say "\nImport completed!", :green
          say "=" * 40, :green
          say "Total files found: #{result[:total_files]}"
          say "Successfully processed: #{result[:processed_files]}", :green
          say "Failed: #{result[:failed_files]}", :red if result[:failed_files] > 0
          
          if result[:results].any?
            say "\nProcessed documents:", :blue
            result[:results].first(5).each do |doc|
              say "  ✓ #{doc[:title]} (#{doc[:document_type]})"
            end
            say "  ... and #{result[:results].length - 5} more" if result[:results].length > 5
          end
          
        elsif File.file?(path)
          say "Importing file: #{path}", :blue
          
          result = client.add_file(path)
          
          say "\nFile imported successfully!", :green
          say "=" * 40, :green
          say "Document ID: #{result[:id]}"
          say "Title: #{result[:title]}"
          say "Type: #{result[:document_type]}"
          say "Content length: #{result[:content].length} characters"
        end
        
        # Show storage stats
        stats = client.stats
        say "\nRagdoll Storage Stats:", :cyan
        say "Documents: #{stats[:total_documents]}"
        say "Chunks: #{stats[:total_chunks]}"
        say "Embeddings: #{stats[:total_embeddings]}"
        say "Storage location: #{stats[:storage_dir]}"
        
        if ENV['OPENAI_API_KEY']
          say "\nNote: Embedding-based search is available", :green
        else
          say "\nNote: Using text-based search (set OPENAI_API_KEY for embeddings)", :yellow
        end
        
      rescue LoadError => e
        say "Error: Could not load required components: #{e.message}", :red
        exit 1
      rescue => e
        say "Error during import: #{e.message}", :red
        say "Stack trace: #{e.backtrace.first(3).join("\n")}", :red if options[:verbose]
        exit 1
      end
    end
    
    default_task :path_import
  end
end
