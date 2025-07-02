# frozen_string_literal: true

module Ragdoll
  class Configuration
    attr_accessor :llm_provider, :llm_config, :embedding_model, :embedding_provider,
                  :chunk_size, :chunk_overlap, :search_similarity_threshold, :max_search_results,
                  :default_model, :prompt_template, :enable_search_analytics, :cache_embeddings,
                  :max_embedding_dimensions, :enable_document_summarization, :summary_model,
                  :summary_max_length, :summary_min_content_length

    def initialize
      @llm_provider = :openai
      @llm_config = default_llm_config
      @embedding_provider = :openai
      @embedding_model = 'text-embedding-3-small'
      @chunk_size = 1000
      @chunk_overlap = 200
      @search_similarity_threshold = 0.7
      @max_search_results = 10
      @default_model = 'gpt-4'
      @prompt_template = nil # Use default template if nil
      @enable_search_analytics = true
      @cache_embeddings = true
      @max_embedding_dimensions = 3072 # Support up to text-embedding-3-large
      @enable_document_summarization = true
      @summary_model = nil # Use default_model if nil
      @summary_max_length = 300
      @summary_min_content_length = 300
    end

    def openai_api_key
      llm_config[:openai]&.dig(:api_key) || ENV['OPENAI_API_KEY']
    end

    def openai_api_key=(key)
      @llm_config[:openai] ||= {}
      @llm_config[:openai][:api_key] = key
    end

    private

    def default_llm_config
      {
        openai: {
          api_key: ENV['OPENAI_API_KEY'],
          organization: ENV['OPENAI_ORGANIZATION'],
          project: ENV['OPENAI_PROJECT']
        },
        anthropic: {
          api_key: ENV['ANTHROPIC_API_KEY']
        },
        google: {
          api_key: ENV['GOOGLE_API_KEY'],
          project_id: ENV['GOOGLE_PROJECT_ID']
        },
        azure: {
          api_key: ENV['AZURE_OPENAI_API_KEY'],
          endpoint: ENV['AZURE_OPENAI_ENDPOINT'],
          api_version: ENV['AZURE_OPENAI_API_VERSION'] || '2024-02-01'
        },
        ollama: {
          endpoint: ENV['OLLAMA_ENDPOINT'] || 'http://localhost:11434'
        },
        huggingface: {
          api_key: ENV['HUGGINGFACE_API_KEY']
        }
      }
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end