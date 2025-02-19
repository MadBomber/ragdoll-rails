# frozen_string_literal: true

require 'thor'
require_relative '../ragdoll/search'

module Ragdoll
  class SearchTask < Thor
    desc "search PROMPT", "Search the database with a prompt"
    method_option :prompt, aliases: ["-p", "--prompt"], type: :string, desc: "File path containing the prompt text"
    method_option :max_count, type: :numeric, default: 10, desc: "Maximum number of results to return"
    method_option :rerank, type: :boolean, default: false, desc: "Rerank results using keyword search"
    def search(prompt = nil)
      if options[:prompt]
        prompt = File.read(options[:prompt])
      end

      unless prompt
        puts "Please provide a prompt as a string or with the -p option."
        return
      end

      keywords = extract_keywords(prompt)
      vectorized_prompt = vectorize_prompt(prompt)
      search_instance = Ragdoll::Search.new(vectorized_prompt)
      results = search_instance.search_database(options[:max_count])

      if options[:rerank]
        results = rerank_results(results, keywords)
      end

      results.each do |result|
        puts "Source: #{result[:source]}"
        puts "Metadata: #{result[:metadata]}"
        puts "--------------------------------"
      end
    end

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
