# frozen_string_literal: true

require 'thor'
require 'ragdoll/client'

module Ragdoll
  class SearchCLI < Thor
    namespace 'ragdoll:search'
    desc "PROMPT", "Search the database with a prompt"
    method_option :prompt, aliases: ["-p", "--prompt"], type: :string, desc: "File path containing the prompt text"
    method_option :max_count, type: :numeric, default: 10, desc: "Maximum number of results to return"
    method_option :rerank, type: :boolean, default: false, desc: "Rerank results using keyword search"
    def search_prompt(prompt = nil)
      begin
        # Use standalone implementation
        require_relative '../../ragdoll/standalone_client'
        
        if options[:prompt]
          prompt = File.read(options[:prompt])
        end

        unless prompt
          say "Please provide a prompt as a string or with the -p option.", :yellow
          return
        end

        client = ::Ragdoll::StandaloneClient.new
        search_options = { 
          limit: options[:max_count],
          threshold: 0.7
        }
        
        say "Searching for: \"#{prompt}\"", :blue
        
        result = client.search(prompt, **search_options)
        
        if result && result[:results].any?
          say "\nSearch completed!", :green
          say "=" * 50, :green
          say "Query: #{result[:query]}"
          say "Search type: #{result[:search_type]}"
          say "Results found: #{result[:total_results]}"
          say ""
          
          result[:results].each_with_index do |res, idx|
            say "#{idx + 1}. #{res[:title]}", :cyan
            say "   Document ID: #{res[:document_id]}"
            say "   Location: #{res[:location]}"
            if res[:similarity]
              say "   Similarity: #{(res[:similarity] * 100).round(1)}%"
            end
            if res[:score]
              say "   Score: #{res[:score]}"
            end
            say "   Preview: #{res[:content_preview]}"
            say ""
          end
        else
          say "No results found for your search.", :yellow
          say "Try different keywords or import more documents first.", :blue
        end
        
        # Show storage stats
        stats = client.stats
        say "Storage Stats:", :cyan
        say "Documents: #{stats[:total_documents]}, Chunks: #{stats[:total_chunks]}, Embeddings: #{stats[:total_embeddings]}"
        
      rescue LoadError => e
        say "Error: Could not load required components: #{e.message}", :red
        exit 1
      rescue => e
        say "Error during search: #{e.message}", :red
        exit 1
      end
    end
    
    default_task :search_prompt

    private

    def rerank_results(results, keywords)
      results.sort_by do |result|
        content = result[:source].downcase
        keywords.count { |keyword| content.include?(keyword) }
      end.reverse
    end

    def extract_keywords(prompt)
      prompt.split.map(&:downcase).uniq
    end

    def vectorize_prompt(prompt)
      prompt.split.map(&:downcase)
    end
  end
end
