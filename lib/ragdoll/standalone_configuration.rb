# frozen_string_literal: true

require 'yaml'
require 'json'
require 'fileutils'

module Ragdoll
  class StandaloneConfiguration
    DEFAULT_CONFIG_FILE = File.expand_path('~/.ragdoll/config.yml')
    SYSTEM_CONFIG_LOCATIONS = [
      '/etc/ragdoll/config.yml',
      '/usr/local/etc/ragdoll/config.yml'
    ].freeze

    def self.load_configuration(config_file_path = nil)
      config_path = find_config_file(config_file_path)
      
      if config_path && File.exist?(config_path)
        load_from_file(config_path)
      else
        # No config file found, use default configuration with environment variables
        setup_default_configuration
      end
    end

    def self.find_config_file(explicit_path = nil)
      return explicit_path if explicit_path && File.exist?(explicit_path)
      
      # Check environment variable
      env_config = ENV['RAGDOLL_CONFIG_FILE']
      return env_config if env_config && File.exist?(env_config)
      
      # Check default user config
      return DEFAULT_CONFIG_FILE if File.exist?(DEFAULT_CONFIG_FILE)
      
      # Check system config locations
      SYSTEM_CONFIG_LOCATIONS.each do |path|
        return path if File.exist?(path)
      end
      
      # Check current directory
      local_config = File.join(Dir.pwd, '.ragdoll.yml')
      return local_config if File.exist?(local_config)
      
      nil
    end

    def self.load_from_file(config_path)
      puts "Loading Ragdoll configuration from: #{config_path}"
      
      content = File.read(config_path)
      
      # Support both YAML and JSON formats
      config_data = if config_path.end_with?('.json')
                      JSON.parse(content)
                    else
                      YAML.safe_load(content, symbolize_names: true) || {}
                    end

      apply_configuration(config_data)
    rescue Psych::SyntaxError => e
      puts "Error parsing YAML configuration file #{config_path}: #{e.message}"
      setup_default_configuration
    rescue JSON::ParserError => e
      puts "Error parsing JSON configuration file #{config_path}: #{e.message}"
      setup_default_configuration
    rescue => e
      puts "Error loading configuration file #{config_path}: #{e.message}"
      setup_default_configuration
    end

    def self.apply_configuration(config_data)
      Ragdoll.configure do |config|
        # LLM and Embedding Provider Settings
        config.llm_provider = config_data[:llm_provider]&.to_sym || config.llm_provider
        config.embedding_provider = config_data[:embedding_provider]&.to_sym || config.embedding_provider
        config.embedding_model = config_data[:embedding_model] || config.embedding_model
        config.default_model = config_data[:default_model] || config.default_model

        # Document Processing Settings
        config.chunk_size = config_data[:chunk_size] || config.chunk_size
        config.chunk_overlap = config_data[:chunk_overlap] || config.chunk_overlap

        # Search Settings
        config.search_similarity_threshold = config_data[:search_similarity_threshold] || config.search_similarity_threshold
        config.max_search_results = config_data[:max_search_results] || config.max_search_results

        # Feature Flags
        config.enable_search_analytics = config_data.key?(:enable_search_analytics) ? config_data[:enable_search_analytics] : config.enable_search_analytics
        config.cache_embeddings = config_data.key?(:cache_embeddings) ? config_data[:cache_embeddings] : config.cache_embeddings
        config.enable_document_summarization = config_data.key?(:enable_document_summarization) ? config_data[:enable_document_summarization] : config.enable_document_summarization
        config.enable_usage_tracking = config_data.key?(:enable_usage_tracking) ? config_data[:enable_usage_tracking] : config.enable_usage_tracking

        # Usage Ranking Settings
        config.usage_ranking_enabled = config_data.key?(:usage_ranking_enabled) ? config_data[:usage_ranking_enabled] : config.usage_ranking_enabled
        config.usage_recency_weight = config_data[:usage_recency_weight] || config.usage_recency_weight
        config.usage_frequency_weight = config_data[:usage_frequency_weight] || config.usage_frequency_weight
        config.usage_similarity_weight = config_data[:usage_similarity_weight] || config.usage_similarity_weight

        # Summarization Settings
        config.summary_model = config_data[:summary_model] || config.summary_model
        config.summary_max_length = config_data[:summary_max_length] || config.summary_max_length
        config.summary_min_content_length = config_data[:summary_min_content_length] || config.summary_min_content_length

        # Advanced Settings
        config.max_embedding_dimensions = config_data[:max_embedding_dimensions] || config.max_embedding_dimensions
        config.prompt_template = config_data[:prompt_template] || config.prompt_template

        # API Keys and Provider Configs - merge with existing config
        if config_data[:api_keys] || config_data[:llm_config]
          api_configs = config_data[:api_keys] || config_data[:llm_config] || {}
          
          # Apply API key configurations
          api_configs.each do |provider, provider_config|
            case provider.to_sym
            when :openai
              config.llm_config[:openai] ||= {}
              config.llm_config[:openai].merge!(provider_config.transform_keys(&:to_sym))
            when :anthropic
              config.llm_config[:anthropic] ||= {}
              config.llm_config[:anthropic].merge!(provider_config.transform_keys(&:to_sym))
            when :google
              config.llm_config[:google] ||= {}
              config.llm_config[:google].merge!(provider_config.transform_keys(&:to_sym))
            when :azure
              config.llm_config[:azure] ||= {}
              config.llm_config[:azure].merge!(provider_config.transform_keys(&:to_sym))
            when :ollama
              config.llm_config[:ollama] ||= {}
              config.llm_config[:ollama].merge!(provider_config.transform_keys(&:to_sym))
            when :huggingface
              config.llm_config[:huggingface] ||= {}
              config.llm_config[:huggingface].merge!(provider_config.transform_keys(&:to_sym))
            end
          end
        end

        # Standalone-specific settings
        if config_data[:standalone]
          standalone_config = config_data[:standalone]
          
          # Storage directory
          if standalone_config[:storage_dir]
            # This would be used by StandaloneStorage if we add config support
            ENV['RAGDOLL_STORAGE_DIR'] = standalone_config[:storage_dir]
          end
          
          # Logging level
          if standalone_config[:log_level]
            ENV['RAGDOLL_LOG_LEVEL'] = standalone_config[:log_level]
          end
        end
      end
    end

    def self.setup_default_configuration
      # Just ensure the configuration object exists with defaults
      # Environment variables will be picked up automatically
      Ragdoll.configuration
    end

    def self.generate_default_config_file(output_path = nil)
      output_path ||= DEFAULT_CONFIG_FILE
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(output_path))
      
      default_config = {
        # LLM and Embedding Providers
        llm_provider: 'openai',
        embedding_provider: 'openai',
        embedding_model: 'text-embedding-3-small',
        default_model: 'gpt-4',

        # Document Processing
        chunk_size: 1000,
        chunk_overlap: 200,

        # Search Settings  
        search_similarity_threshold: 0.7,
        max_search_results: 10,

        # Feature Flags
        enable_search_analytics: true,
        cache_embeddings: true,
        enable_document_summarization: true,
        enable_usage_tracking: true,

        # Usage Ranking
        usage_ranking_enabled: true,
        usage_recency_weight: 0.3,
        usage_frequency_weight: 0.7,
        usage_similarity_weight: 1.0,

        # Summarization
        summary_max_length: 300,
        summary_min_content_length: 300,

        # Advanced
        max_embedding_dimensions: 3072,

        # API Keys - Override with your actual keys
        api_keys: {
          openai: {
            api_key: ENV['OPENAI_API_KEY'] || 'your-openai-api-key-here',
            organization: ENV['OPENAI_ORGANIZATION'] || nil,
            project: ENV['OPENAI_PROJECT'] || nil
          },
          anthropic: {
            api_key: ENV['ANTHROPIC_API_KEY'] || 'your-anthropic-api-key-here'
          },
          google: {
            api_key: ENV['GOOGLE_API_KEY'] || 'your-google-api-key-here',
            project_id: ENV['GOOGLE_PROJECT_ID'] || nil
          },
          azure: {
            api_key: ENV['AZURE_OPENAI_API_KEY'] || 'your-azure-api-key-here',
            endpoint: ENV['AZURE_OPENAI_ENDPOINT'] || 'https://your-resource.openai.azure.com',
            api_version: ENV['AZURE_OPENAI_API_VERSION'] || '2024-02-01'
          },
          ollama: {
            endpoint: ENV['OLLAMA_ENDPOINT'] || 'http://localhost:11434'
          },
          huggingface: {
            api_key: ENV['HUGGINGFACE_API_KEY'] || 'your-huggingface-api-key-here'
          }
        },

        # Standalone-specific settings
        standalone: {
          storage_dir: ENV['RAGDOLL_STORAGE_DIR'] || '~/.ragdoll',
          log_level: ENV['RAGDOLL_LOG_LEVEL'] || 'info'
        }
      }

      # Write the config file
      File.write(output_path, YAML.dump(default_config.deep_stringify_keys))
      
      puts "Generated default Ragdoll configuration at: #{output_path}"
      puts "Please edit this file to configure your API keys and preferences."
      
      output_path
    end

    def self.config_file_exists?(path = nil)
      config_path = find_config_file(path)
      config_path && File.exist?(config_path)
    end
  end
end

# Add deep_stringify_keys method if not available
class Hash
  def deep_stringify_keys
    deep_transform_keys(&:to_s)
  end

  def deep_transform_keys(&block)
    result = {}
    each do |key, value|
      result[yield(key)] = value.is_a?(Hash) ? value.deep_transform_keys(&block) : value
    end
    result
  end
end