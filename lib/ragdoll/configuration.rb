# frozen_string_literal: true

module Ragdoll
  class Configuration
    attr_accessor :openai_api_key, :embedding_model, :chunk_size, :chunk_overlap,
                  :search_similarity_threshold, :max_search_results, :default_model,
                  :prompt_template, :enable_search_analytics, :cache_embeddings

    def initialize
      @openai_api_key = ENV['OPENAI_API_KEY']
      @embedding_model = 'text-embedding-3-small'
      @chunk_size = 1000
      @chunk_overlap = 200
      @search_similarity_threshold = 0.7
      @max_search_results = 10
      @default_model = 'gpt-4'
      @prompt_template = nil # Use default template if nil
      @enable_search_analytics = true
      @cache_embeddings = true
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end