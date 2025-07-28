# frozen_string_literal: true

# Ragdoll RAG (Retrieval-Augmented Generation) Configuration
# This initializer configures the Ragdoll Rails engine for your application.

Ragdoll.configure do |config|
  # LLM Provider Configuration
  # Supported providers: :openai, :anthropic, :google, :azure, :ollama, :huggingface
  config.llm_provider = :openai
  
  # Optional: Use a different provider for embeddings (defaults to llm_provider)
  # config.embedding_provider = :openai

  # Provider-specific API configurations
  # Add your API keys and configuration here
  config.llm_config = {
    openai: { 
      api_key: ENV['OPENAI_API_KEY']
      # organization: ENV['OPENAI_ORGANIZATION'],  # optional
      # project: ENV['OPENAI_PROJECT']              # optional
    },
    anthropic: { 
      api_key: ENV['ANTHROPIC_API_KEY'] 
    },
    google: { 
      api_key: ENV['GOOGLE_API_KEY'],
      project_id: ENV['GOOGLE_PROJECT_ID']
    },
    azure: {
      api_key: ENV['AZURE_API_KEY'],
      endpoint: ENV['AZURE_ENDPOINT'],
      api_version: ENV['AZURE_API_VERSION']
    },
    ollama: {
      endpoint: ENV['OLLAMA_ENDPOINT'] || 'http://localhost:11434'
    },
    huggingface: {
      api_key: ENV['HUGGINGFACE_API_KEY']
    }
  }

  # Embedding Model Configuration
  # Examples: 'text-embedding-3-small', 'text-embedding-3-large', 'text-embedding-ada-002'
  config.embedding_model = 'text-embedding-3-small'
  
  # Default model for chat/completion
  config.default_model = 'gpt-4o-mini'

  # Text Processing Configuration
  config.chunk_size = 1000
  config.chunk_overlap = 200

  # Search Configuration
  config.search_similarity_threshold = 0.7
  config.max_search_results = 10

  # Vector Configuration
  # Maximum dimensions supported (supports variable-length vectors)
  config.max_embedding_dimensions = 3072

  # Background Jobs Configuration
  # Set to false if you don't want to use background jobs for document processing
  config.use_background_jobs = true

  # Analytics Configuration
  config.enable_search_analytics = true
  config.cache_embeddings = true

  # Custom Prompt Template (optional)
  # Use {{context}} and {{prompt}} placeholders
  # config.prompt_template = <<~TEMPLATE
  #   Based on the following context, please answer the question.
  #   
  #   Context:
  #   {{context}}
  #   
  #   Question: {{prompt}}
  #   
  #   Answer:
  # TEMPLATE
end

# Optional: Configure Rails-specific settings
Ragdoll::Rails.configure do |config|
  # Enable/disable background job processing
  config.use_background_jobs = true
  
  # Background job queue name
  config.queue_name = :ragdoll
  
  # Maximum file size for uploads (in bytes)
  config.max_file_size = 10.megabytes
  
  # Allowed file types for document upload
  config.allowed_file_types = %w[pdf docx txt md html htm json xml csv]
end