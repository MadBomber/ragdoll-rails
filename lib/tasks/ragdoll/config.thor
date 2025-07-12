# frozen_string_literal: true

require 'thor'

module Ragdoll
  class ConfigCLI < Thor
    namespace 'ragdoll:config'

    desc "init [PATH]", "Initialize a new Ragdoll configuration file"
    method_option :force, type: :boolean, default: false, aliases: ["-f"], desc: "Overwrite existing config file"
    method_option :global, type: :boolean, default: false, aliases: ["-g"], desc: "Create global config in ~/.ragdoll/config.yml"
    method_option :local, type: :boolean, default: false, aliases: ["-l"], desc: "Create local config in ./.ragdoll.yml"
    def init(path = nil)
      begin
        require_relative '../../ragdoll/standalone_configuration'
        
        # Determine output path
        if path
          output_path = File.expand_path(path)
        elsif options[:local]
          output_path = File.join(Dir.pwd, '.ragdoll.yml')
        elsif options[:global]
          output_path = File.expand_path('~/.ragdoll/config.yml')
        else
          # Default to global config
          output_path = File.expand_path('~/.ragdoll/config.yml')
        end
        
        # Check if file exists
        if File.exist?(output_path) && !options[:force]
          say "Configuration file already exists at #{output_path}", :yellow
          say "Use --force to overwrite, or specify a different path", :yellow
          return
        end
        
        # Generate the config file
        actual_path = ::Ragdoll::StandaloneConfiguration.generate_default_config_file(output_path)
        
        say "✓ Created Ragdoll configuration file at: #{actual_path}", :green
        say "", :white
        say "Next steps:", :cyan
        say "1. Edit the configuration file to add your API keys", :white
        say "2. Customize settings as needed", :white
        say "3. Test with: ragdoll --config-file #{actual_path} --help", :white
        
      rescue LoadError => e
        say "Error: Could not load configuration components: #{e.message}", :red
        exit 1
      rescue => e
        say "Error creating configuration file: #{e.message}", :red
        exit 1
      end
    end

    desc "show [CONFIG_FILE]", "Show current configuration"
    method_option :format, type: :string, default: "table", enum: ["table", "yaml", "json"], desc: "Output format"
    def show(config_file = nil)
      begin
        require_relative '../../ragdoll/standalone_configuration'
        
        # Load configuration
        ::Ragdoll::StandaloneConfiguration.load_configuration(config_file)
        config = ::Ragdoll.configuration
        
        case options[:format]
        when "yaml"
          require 'yaml'
          puts YAML.dump(extract_config_hash(config))
        when "json"
          require 'json'
          puts JSON.pretty_generate(extract_config_hash(config))
        else
          show_config_table(config, config_file)
        end
        
      rescue LoadError => e
        say "Error: Could not load configuration components: #{e.message}", :red
        exit 1
      rescue => e
        say "Error showing configuration: #{e.message}", :red
        exit 1
      end
    end

    desc "validate [CONFIG_FILE]", "Validate configuration file"
    def validate(config_file = nil)
      begin
        require_relative '../../ragdoll/standalone_configuration'
        
        config_path = ::Ragdoll::StandaloneConfiguration.find_config_file(config_file)
        
        if config_path.nil?
          say "No configuration file found", :yellow
          say "Use 'ragdoll config init' to create one", :blue
          return
        end
        
        say "Validating configuration file: #{config_path}", :blue
        
        # Try to load the configuration
        ::Ragdoll::StandaloneConfiguration.load_from_file(config_path)
        
        say "✓ Configuration file is valid", :green
        
        # Check for API keys
        config = ::Ragdoll.configuration
        has_keys = false
        
        if config.openai_api_key && config.openai_api_key != 'your-openai-api-key-here'
          say "✓ OpenAI API key configured", :green
          has_keys = true
        end
        
        if config.anthropic_api_key && config.anthropic_api_key != 'your-anthropic-api-key-here'
          say "✓ Anthropic API key configured", :green
          has_keys = true
        end
        
        unless has_keys
          say "⚠ No API keys configured - only text-based search will be available", :yellow
        end
        
      rescue => e
        say "✗ Configuration validation failed: #{e.message}", :red
        exit 1
      end
    end

    default_task :init

    private

    def extract_config_hash(config)
      {
        llm_provider: config.llm_provider,
        embedding_provider: config.embedding_provider,
        embedding_model: config.embedding_model,
        default_model: config.default_model,
        chunk_size: config.chunk_size,
        chunk_overlap: config.chunk_overlap,
        search_similarity_threshold: config.search_similarity_threshold,
        max_search_results: config.max_search_results,
        enable_search_analytics: config.enable_search_analytics,
        cache_embeddings: config.cache_embeddings,
        enable_document_summarization: config.enable_document_summarization,
        enable_usage_tracking: config.enable_usage_tracking,
        usage_ranking_enabled: config.usage_ranking_enabled,
        usage_recency_weight: config.usage_recency_weight,
        usage_frequency_weight: config.usage_frequency_weight,
        usage_similarity_weight: config.usage_similarity_weight,
        summary_max_length: config.summary_max_length,
        summary_min_content_length: config.summary_min_content_length,
        max_embedding_dimensions: config.max_embedding_dimensions
      }
    end

    def show_config_table(config, config_file = nil)
      config_path = ::Ragdoll::StandaloneConfiguration.find_config_file(config_file)
      
      say "Ragdoll Configuration", :cyan
      say "=" * 50, :cyan
      say "Config file: #{config_path || 'Using defaults + environment variables'}", :white
      say ""
      
      # Core settings
      say "Core Settings:", :yellow
      puts "  LLM Provider: #{config.llm_provider}"
      puts "  Embedding Provider: #{config.embedding_provider}"
      puts "  Embedding Model: #{config.embedding_model}"
      puts "  Default Model: #{config.default_model}"
      say ""
      
      # Processing settings
      say "Document Processing:", :yellow
      puts "  Chunk Size: #{config.chunk_size}"
      puts "  Chunk Overlap: #{config.chunk_overlap}"
      say ""
      
      # Search settings
      say "Search Settings:", :yellow
      puts "  Similarity Threshold: #{config.search_similarity_threshold}"
      puts "  Max Results: #{config.max_search_results}"
      puts "  Search Analytics: #{config.enable_search_analytics}"
      puts "  Cache Embeddings: #{config.cache_embeddings}"
      say ""
      
      # API Key status
      say "API Key Status:", :yellow
      puts "  OpenAI: #{config.openai_api_key ? '✓ Configured' : '✗ Not configured'}"
      puts "  Anthropic: #{config.anthropic_api_key ? '✓ Configured' : '✗ Not configured'}"
      puts "  Google: #{config.google_api_key ? '✓ Configured' : '✗ Not configured'}"
      puts "  Azure: #{config.azure_api_key ? '✓ Configured' : '✗ Not configured'}"
      puts "  Hugging Face: #{config.huggingface_api_key ? '✓ Configured' : '✗ Not configured'}"
    end
  end
end