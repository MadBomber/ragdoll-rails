# Ragdoll Configuration Guide

## Overview

Ragdoll provides extensive configuration options to customize LLM providers, document processing, search behavior, and analytics. This guide covers all configuration options and best practices.

## Basic Configuration

### Initial Setup

Create a ragdoll configuration file in your Rails application:

```ruby
# config/initializers/ragdoll.rb
Ragdoll.configure do |config|
  # LLM Provider
  config.llm_provider = :openai
  config.embedding_provider = :openai
  config.embedding_model = "text-embedding-3-small"
  
  # Document Processing
  config.chunk_size = 1000
  config.chunk_overlap = 200
  
  # Search Configuration
  config.search_similarity_threshold = 0.7
  config.max_search_results = 10
end
```

## LLM Provider Configuration

### Supported Providers

Ragdoll supports multiple LLM providers through the ruby_llm gem:

- **OpenAI** (GPT-4, GPT-3.5-turbo, text-embedding models)
- **Anthropic** (Claude models)
- **Google** (Gemini models, Vertex AI)
- **Azure OpenAI** (GPT models via Azure)
- **Ollama** (Local models)
- **HuggingFace** (Various open-source models)

### OpenAI Configuration

```ruby
Ragdoll.configure do |config|
  config.llm_provider = :openai
  config.embedding_provider = :openai
  config.embedding_model = "text-embedding-3-small"
  config.default_model = "gpt-4"
  
  # API credentials (prefer environment variables)
  config.openai_api_key = ENV['OPENAI_API_KEY']
end
```

**Environment Variables:**
```bash
OPENAI_API_KEY=sk-your-openai-api-key
OPENAI_ORGANIZATION=org-your-organization-id  # Optional
OPENAI_PROJECT=proj_your-project-id           # Optional
```

**Available Embedding Models:**
- `text-embedding-3-small` (1536 dimensions, cost-effective)
- `text-embedding-3-large` (3072 dimensions, highest quality)
- `text-embedding-ada-002` (1536 dimensions, legacy)

### Anthropic Configuration

```ruby
Ragdoll.configure do |config|
  config.llm_provider = :anthropic
  config.default_model = "claude-3-haiku-20240307"
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  
  # Note: Anthropic doesn't provide embedding models
  # Use OpenAI or another provider for embeddings
  config.embedding_provider = :openai
  config.embedding_model = "text-embedding-3-small"
end
```

**Environment Variables:**
```bash
ANTHROPIC_API_KEY=sk-ant-your-anthropic-api-key
```

### Google Configuration

```ruby
Ragdoll.configure do |config|
  config.llm_provider = :google
  config.default_model = "gemini-pro"
  config.google_api_key = ENV['GOOGLE_API_KEY']
end
```

**Environment Variables:**
```bash
GOOGLE_API_KEY=your-google-api-key
GOOGLE_PROJECT_ID=your-google-project-id  # For Vertex AI
```

### Azure OpenAI Configuration

```ruby
Ragdoll.configure do |config|
  config.llm_provider = :azure
  config.azure_api_key = ENV['AZURE_OPENAI_API_KEY']
  config.default_model = "gpt-4"
end
```

**Environment Variables:**
```bash
AZURE_OPENAI_API_KEY=your-azure-api-key
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_VERSION=2024-02-01
```

### Ollama Configuration (Local Models)

```ruby
Ragdoll.configure do |config|
  config.llm_provider = :ollama
  config.ollama_url = "http://localhost:11434"
  config.default_model = "llama2"
  
  # Use OpenAI for embeddings (Ollama embedding support varies)
  config.embedding_provider = :openai
end
```

**Environment Variables:**
```bash
OLLAMA_ENDPOINT=http://localhost:11434
```

### HuggingFace Configuration

```ruby
Ragdoll.configure do |config|
  config.llm_provider = :huggingface
  config.huggingface_api_key = ENV['HUGGINGFACE_API_KEY']
  config.default_model = "microsoft/DialoGPT-medium"
end
```

**Environment Variables:**
```bash
HUGGINGFACE_API_KEY=hf_your-huggingface-token
```

## Document Processing Configuration

### Chunking Strategy

Control how documents are split into chunks for embedding:

```ruby
Ragdoll.configure do |config|
  # Chunk size in characters (recommended: 500-2000)
  config.chunk_size = 1000
  
  # Overlap between chunks to maintain context (recommended: 10-20% of chunk_size)
  config.chunk_overlap = 200
end
```

**Chunking Guidelines:**
- **Small chunks (500-800)**: Better precision, more granular results
- **Medium chunks (800-1500)**: Balanced approach, good for most use cases
- **Large chunks (1500-2000)**: More context, better for complex documents

### Document Summarization

Configure automatic document summarization:

```ruby
Ragdoll.configure do |config|
  # Enable/disable summarization
  config.enable_document_summarization = true
  
  # Model for summarization (defaults to default_model if nil)
  config.summary_model = "gpt-3.5-turbo"
  
  # Summary length limits
  config.summary_max_length = 300
  config.summary_min_content_length = 300  # Minimum content length to summarize
end
```

### Embedding Configuration

Control vector embedding behavior:

```ruby
Ragdoll.configure do |config|
  # Maximum supported embedding dimensions
  config.max_embedding_dimensions = 3072
  
  # Cache embeddings to avoid regeneration
  config.cache_embeddings = true
end
```

## Search Configuration

### Similarity Search Settings

```ruby
Ragdoll.configure do |config|
  # Minimum similarity score for results (0.0-1.0)
  # Higher values = more strict matching
  config.search_similarity_threshold = 0.7
  
  # Maximum number of results to return
  config.max_search_results = 10
end
```

**Threshold Guidelines:**
- **0.9-1.0**: Very strict, only highly similar content
- **0.7-0.9**: Strict, good for specific queries
- **0.5-0.7**: Moderate, good for exploratory search
- **0.3-0.5**: Loose, good for broad topic discovery
- **0.0-0.3**: Very loose, may return unrelated content

### Usage Analytics and Ranking

Enable intelligent ranking based on usage patterns:

```ruby
Ragdoll.configure do |config|
  # Enable usage tracking
  config.enable_usage_tracking = true
  config.usage_ranking_enabled = true
  
  # Ranking weights (how much each factor influences results)
  config.usage_similarity_weight = 1.0    # Semantic similarity
  config.usage_frequency_weight = 0.7     # How often content is accessed
  config.usage_recency_weight = 0.3       # How recently content was accessed
end
```

### Search Analytics

Track search performance and patterns:

```ruby
Ragdoll.configure do |config|
  # Enable search analytics
  config.enable_search_analytics = true
end
```

## Advanced Configuration

### Custom Prompt Templates

Define custom prompt templates for RAG context injection:

```ruby
Ragdoll.configure do |config|
  config.prompt_template = <<~TEMPLATE
    Use the following context to answer the user's question. If you cannot answer based on the provided context, say so clearly.

    Context:
    %{context}

    Question: %{question}

    Answer:
  TEMPLATE
end
```

**Template Variables:**
- `%{context}` - Retrieved document chunks
- `%{question}` - User's original question
- `%{metadata}` - Document metadata (if needed)

### Environment-Specific Configuration

Configure different settings per environment:

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.after_initialize do
    Ragdoll.configure do |ragdoll_config|
      ragdoll_config.search_similarity_threshold = 0.5  # More lenient for testing
      ragdoll_config.chunk_size = 500                   # Smaller chunks for faster processing
      ragdoll_config.enable_search_analytics = false    # Disable analytics in development
    end
  end
end

# config/environments/production.rb
Rails.application.configure do
  config.after_initialize do
    Ragdoll.configure do |ragdoll_config|
      ragdoll_config.search_similarity_threshold = 0.8  # Stricter for production
      ragdoll_config.enable_usage_tracking = true       # Enable analytics
      ragdoll_config.cache_embeddings = true           # Enable caching
    end
  end
end
```

### Configuration from YAML File

For complex configurations, use a YAML file:

```yaml
# config/ragdoll.yml
default: &default
  llm_provider: openai
  embedding_provider: openai
  embedding_model: "text-embedding-3-small"
  default_model: "gpt-4"
  chunk_size: 1000
  chunk_overlap: 200
  search_similarity_threshold: 0.7
  max_search_results: 10
  enable_search_analytics: true
  usage_ranking_enabled: true

development:
  <<: *default
  search_similarity_threshold: 0.5
  enable_search_analytics: false

test:
  <<: *default
  llm_provider: mock
  embedding_provider: mock

production:
  <<: *default
  search_similarity_threshold: 0.8
  cache_embeddings: true
```

Load from YAML:

```ruby
# config/initializers/ragdoll.rb
config_path = Rails.root.join('config', 'ragdoll.yml')
if File.exist?(config_path)
  ragdoll_config = YAML.load_file(config_path)[Rails.env]
  
  Ragdoll.configure do |config|
    ragdoll_config.each do |key, value|
      config.send("#{key}=", value) if config.respond_to?("#{key}=")
    end
  end
end
```

## Configuration Validation

### Runtime Validation

Validate your configuration at startup:

```ruby
# config/initializers/ragdoll.rb
Ragdoll.configure do |config|
  # Your configuration here
end

# Validate configuration
begin
  client = Ragdoll::Client.new
  client.health_check
  Rails.logger.info "Ragdoll configuration valid"
rescue => e
  Rails.logger.error "Ragdoll configuration error: #{e.message}"
  raise e if Rails.env.production?
end
```

### Configuration Testing

Test your configuration with a simple document:

```ruby
# In rails console or test
client = Ragdoll::Client.new

# Test document processing
test_doc = client.add_document("Test content", { title: "Test" })
puts "Document processing: #{test_doc.status}"

# Test search
results = client.search("test")
puts "Search results: #{results.length}"
```

## Security Considerations

### API Key Management

1. **Never commit API keys** to version control
2. **Use environment variables** or Rails credentials
3. **Rotate keys regularly** for production systems
4. **Use least-privilege access** when possible

### Secure Storage

```ruby
# Use Rails credentials (recommended)
# Run: rails credentials:edit
# Add to credentials.yml.enc:
# ragdoll:
#   openai_api_key: your-api-key

# Access in configuration:
Ragdoll.configure do |config|
  config.openai_api_key = Rails.application.credentials.ragdoll[:openai_api_key]
end
```

### Access Control

Implement access control for ragdoll operations:

```ruby
# In your controllers
class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_ragdoll_access!
  
  private
  
  def authorize_ragdoll_access!
    redirect_to root_path unless current_user.can_access_ragdoll?
  end
end
```

## Performance Tuning

### Database Optimization

```ruby
# Optimize for your workload
Ragdoll.configure do |config|
  # Smaller chunks = more rows but faster search
  config.chunk_size = 800
  
  # Enable caching to reduce API calls
  config.cache_embeddings = true
  
  # Limit results to improve response time
  config.max_search_results = 5
end
```

### Memory Management

For large document collections:

```ruby
# Process documents in batches
documents.find_in_batches(batch_size: 100) do |batch|
  batch.each do |document|
    Ragdoll::ImportFileJob.perform_later(document.id)
  end
end
```

## Troubleshooting Configuration

### Common Issues

1. **API Key Errors**: Verify environment variables are set correctly
2. **Model Not Found**: Check model names are correct for your provider
3. **Dimension Mismatches**: Ensure embedding_model matches existing embeddings
4. **Performance Issues**: Adjust chunk_size and similarity_threshold

### Debug Configuration

Enable debug mode to troubleshoot:

```ruby
Ragdoll.configure do |config|
  config.debug = true  # If available
end

# Check current configuration
puts Ragdoll.configuration.inspect
```

### Monitoring

Monitor key metrics in production:

```ruby
# Track API usage
Rails.application.config.after_initialize do
  ActiveSupport::Notifications.subscribe('ragdoll.api_call') do |name, start, finish, id, payload|
    duration = finish - start
    Rails.logger.info "Ragdoll API call: #{payload[:provider]} #{payload[:model]} #{duration}ms"
  end
end
```

## Best Practices

1. **Start with defaults** and tune based on your specific use case
2. **Test thoroughly** in development before deploying
3. **Monitor costs** especially for commercial LLM providers
4. **Use appropriate chunk sizes** for your document types
5. **Enable analytics** to understand usage patterns
6. **Regular backups** of your embeddings and search data
7. **Version control** your configuration files
8. **Document** any custom configurations for your team