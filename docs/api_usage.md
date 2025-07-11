# Ragdoll API Usage Guide

## Overview

Ragdoll provides multiple ways to interact with your RAG system: a simple Client interface for common tasks, a comprehensive API class for advanced operations, and module-level convenience methods. This guide covers all API patterns with practical examples.

## Quick Start

### Basic Setup

```ruby
# In your Rails application
require 'ragdoll'

# Simple client for most use cases
client = Ragdoll::Client.new

# Or use module-level convenience methods
result = Ragdoll.search("your query")
```

## Client Interface (Recommended)

The `Ragdoll::Client` class provides a simplified interface for common RAG operations.

### Initialization

```ruby
# Basic initialization
client = Ragdoll::Client.new

# With custom options (passes through to API)
client = Ragdoll::Client.new(embedding_service: custom_service)
```

### Primary RAG Method: enhance_prompt

The main method for RAG applications - enhances prompts with relevant context:

```ruby
# Basic usage
result = client.enhance_prompt("What is machine learning?")

puts result[:enhanced_prompt]
# => Enhanced prompt with context injected
puts result[:context_sources] 
# => Array of source documents that provided context
puts result[:context_count]
# => Number of context chunks found

# With options
result = client.enhance_prompt(
  "Explain neural networks",
  context_limit: 3,           # Maximum context chunks
  threshold: 0.8,             # Similarity threshold
  filters: { 
    document_type: 'academic_paper',
    topic: 'deep_learning'
  }
)
```

**Return Structure:**
```ruby
{
  enhanced_prompt: "AI prompt with context injected",
  original_prompt: "Your original question",
  context_sources: ["doc1.pdf", "doc2.txt"],
  context_count: 5
}
```

### Document Management

#### Adding Documents

```ruby
# Add a file
document = client.add_file("/path/to/document.pdf")

# Add text content
document = client.add_text(
  "Your text content here",
  title: "Document Title",
  document_type: "article",
  metadata: { author: "John Doe", topic: "AI" }
)

# Add any document (file or content)
document = client.add_document(
  "/path/to/file.docx",
  title: "Custom Title",
  chunk_size: 800,
  chunk_overlap: 150
)

# Add entire directory
results = client.add_directory(
  "/path/to/documents",
  recursive: true,
  document_type: "research_paper"
)
```

#### Managing Documents

```ruby
# Get document details
document = client.get_document(123)

# Update document
updated = client.update_document(
  123,
  title: "New Title",
  metadata: { updated_by: "Admin" }
)

# Delete document
client.delete_document(123)

# List documents with filtering
documents = client.list_documents(
  status: 'processed',
  document_type: 'pdf',
  limit: 50
)
```

### Search Operations

#### Semantic Search

```ruby
# Basic search
results = client.search("artificial intelligence")

# Advanced search with filters
results = client.search(
  "machine learning algorithms",
  limit: 20,
  threshold: 0.75,
  filters: {
    document_type: "academic_paper",
    metadata: { topic: "computer_science" }
  }
)

# Get context without prompt enhancement
context = client.get_context(
  "deep learning",
  limit: 5,
  threshold: 0.8
)
```

**Search Result Structure:**
```ruby
{
  query: "your search query",
  results: [
    {
      content: "relevant text chunk",
      similarity_score: 0.85,
      document: { id: 1, title: "Doc Title" },
      metadata: { page: 5, section: "Introduction" }
    }
  ],
  total_results: 10
}
```

### Bulk Operations

```ruby
# Reprocess all documents
client.reprocess_all

# Reprocess only failed documents
client.reprocess_failed

# Reprocess with filters
client.reprocess_all(document_type: 'pdf')
```

### Analytics and Monitoring

```ruby
# Get system statistics
stats = client.stats
puts "Total documents: #{stats[:total_documents]}"
puts "Processed: #{stats[:processed_documents]}"
puts "Failed: #{stats[:failed_documents]}"

# Search analytics
analytics = client.search_analytics(days: 30)
puts "Popular queries: #{analytics[:popular_queries]}"
puts "Average response time: #{analytics[:avg_response_time]}"

# Health check
if client.healthy?
  puts "System is operational"
else
  puts "System health check failed"
end
```

## Module-Level Convenience Methods

For simple scripts and one-off operations:

```ruby
# Document operations
document = Ragdoll.add_file("/path/to/file.pdf")
text_doc = Ragdoll.add_text("Content", title: "Title")

# Search operations
results = Ragdoll.search("query")
context = Ragdoll.get_context("prompt")

# Enhanced prompts
enhanced = Ragdoll.enhance_prompt("What is AI?")

# Analytics
stats = Ragdoll.stats
analytics = Ragdoll.search_analytics
```

## Advanced API Usage

For complex operations, use the `Ragdoll::API` class directly:

```ruby
# Initialize with custom embedding service
api = Ragdoll::API.new(embedding_service: custom_service)

# Direct context retrieval
context = api.get_context(
  "complex query",
  limit: 10,
  threshold: 0.85,
  filters: { category: "technical" }
)

# Advanced document processing
document = api.add_document_from_file(
  "/path/to/file",
  custom_parser: MyCustomParser,
  preprocessing_options: { clean_html: true }
)
```

## Error Handling

Ragdoll provides specific error classes for different failure modes:

```ruby
begin
  result = client.search("query")
rescue Ragdoll::API::SearchError => e
  puts "Search failed: #{e.message}"
rescue Ragdoll::API::DocumentError => e
  puts "Document operation failed: #{e.message}"
rescue Ragdoll::API::APIError => e
  puts "General API error: #{e.message}"
rescue Ragdoll::Error => e
  puts "Ragdoll error: #{e.message}"
end
```

### Graceful Degradation

Handle failures gracefully in production:

```ruby
def search_with_fallback(query)
  begin
    client.search(query)
  rescue Ragdoll::API::SearchError
    # Fallback to simple keyword search
    { query: query, results: [], fallback: true }
  end
end

def enhance_prompt_safely(prompt)
  begin
    client.enhance_prompt(prompt)
  rescue => e
    Rails.logger.error "RAG enhancement failed: #{e.message}"
    # Return original prompt if enhancement fails
    {
      enhanced_prompt: prompt,
      original_prompt: prompt,
      context_sources: [],
      context_count: 0,
      error: e.message
    }
  end
end
```

## Integration Patterns

### Rails Controller Integration

```ruby
class SearchController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @query = params[:q]
    @filters = search_filters
    
    if @query.present?
      @results = ragdoll_client.search(@query, **@filters)
      @analytics = ragdoll_client.search_analytics(days: 7)
    else
      @results = { results: [], total_results: 0 }
    end
  end
  
  def enhance
    prompt = params[:prompt]
    
    if prompt.present?
      @enhancement = ragdoll_client.enhance_prompt(
        prompt,
        context_limit: params[:context_limit]&.to_i || 5
      )
    else
      redirect_to search_index_path, alert: "Prompt required"
    end
  end
  
  private
  
  def ragdoll_client
    @ragdoll_client ||= Ragdoll::Client.new
  end
  
  def search_filters
    {
      limit: params[:limit]&.to_i || 10,
      threshold: params[:threshold]&.to_f || 0.7,
      filters: {
        document_type: params[:document_type],
        metadata: filtered_metadata
      }.compact
    }
  end
  
  def filtered_metadata
    metadata = {}
    metadata[:author] = params[:author] if params[:author].present?
    metadata[:topic] = params[:topic] if params[:topic].present?
    metadata
  end
end
```

### Background Job Integration

```ruby
class ProcessDocumentsJob < ApplicationJob
  def perform(document_ids)
    client = Ragdoll::Client.new
    
    document_ids.each do |id|
      begin
        # Reprocess document
        client.update_document(id, reprocess: true)
        
        # Log success
        Rails.logger.info "Processed document #{id}"
      rescue => e
        Rails.logger.error "Failed to process document #{id}: #{e.message}"
        # Could implement retry logic here
      end
    end
  end
end
```

### Service Object Pattern

```ruby
class DocumentSearchService
  attr_reader :client, :user
  
  def initialize(user)
    @user = user
    @client = Ragdoll::Client.new
  end
  
  def search(query, options = {})
    # Add user-specific filters
    options[:filters] ||= {}
    options[:filters][:accessible_by] = user.id
    
    results = client.search(query, **options)
    
    # Log search for analytics
    SearchLog.create!(
      user: user,
      query: query,
      result_count: results[:total_results],
      filters: options[:filters]
    )
    
    results
  end
  
  def enhanced_chat_prompt(message, conversation_history = [])
    # Get relevant context
    context = client.get_context(message, limit: 3)
    
    # Build enhanced prompt with conversation history
    enhanced_prompt = build_chat_prompt(
      message,
      context[:combined_context],
      conversation_history
    )
    
    {
      prompt: enhanced_prompt,
      context_sources: context[:context_chunks],
      context_count: context[:total_chunks]
    }
  end
  
  private
  
  def build_chat_prompt(message, context, history)
    prompt = "Based on the following context and conversation history:\n\n"
    prompt += "Context:\n#{context}\n\n" if context.present?
    
    if history.any?
      prompt += "Conversation History:\n"
      history.last(3).each { |msg| prompt += "#{msg}\n" }
      prompt += "\n"
    end
    
    prompt += "User: #{message}\nAssistant:"
  end
end
```

## Performance Optimization

### Caching Strategies

```ruby
class CachedRagdollClient
  def initialize
    @client = Ragdoll::Client.new
    @cache = Rails.cache
  end
  
  def search(query, **options)
    cache_key = "ragdoll:search:#{Digest::MD5.hexdigest(query + options.to_s)}"
    
    @cache.fetch(cache_key, expires_in: 1.hour) do
      @client.search(query, **options)
    end
  end
  
  def enhance_prompt(prompt, **options)
    # Don't cache enhanced prompts as they're typically unique
    @client.enhance_prompt(prompt, **options)
  end
end
```

### Batch Processing

```ruby
class BatchDocumentProcessor
  def initialize
    @client = Ragdoll::Client.new
  end
  
  def process_directory(path, batch_size: 10)
    files = Dir.glob(File.join(path, "**/*")).select { |f| File.file?(f) }
    
    files.each_slice(batch_size) do |batch|
      batch.each do |file_path|
        begin
          @client.add_file(file_path)
        rescue => e
          Rails.logger.error "Failed to process #{file_path}: #{e.message}"
        end
      end
      
      # Small delay to avoid overwhelming the system
      sleep(0.1)
    end
  end
end
```

## Testing

### RSpec Integration

```ruby
# spec/support/ragdoll_helpers.rb
module RagdollHelpers
  def mock_ragdoll_client
    instance_double(Ragdoll::Client).tap do |client|
      allow(client).to receive(:search).and_return(mock_search_results)
      allow(client).to receive(:enhance_prompt).and_return(mock_enhanced_prompt)
      allow(Ragdoll::Client).to receive(:new).and_return(client)
    end
  end
  
  def mock_search_results
    {
      query: "test query",
      results: [
        {
          content: "relevant content",
          similarity_score: 0.85,
          document: { id: 1, title: "Test Doc" }
        }
      ],
      total_results: 1
    }
  end
  
  def mock_enhanced_prompt
    {
      enhanced_prompt: "Enhanced test prompt with context",
      original_prompt: "test prompt",
      context_sources: ["test_doc.pdf"],
      context_count: 1
    }
  end
end

# In your specs
RSpec.describe SearchController do
  include RagdollHelpers
  
  before { mock_ragdoll_client }
  
  it "performs search" do
    get :index, params: { q: "test query" }
    expect(response).to be_successful
    expect(assigns(:results)[:total_results]).to eq(1)
  end
end
```

## Best Practices

1. **Use the Client interface** for most operations - it provides a cleaner API
2. **Handle errors gracefully** - RAG operations can fail due to network issues or model limits
3. **Implement caching** for frequently accessed search results
4. **Log operations** for debugging and analytics
5. **Use background jobs** for document processing to avoid blocking requests
6. **Filter results** based on user permissions and context
7. **Monitor usage** to optimize costs and performance
8. **Test thoroughly** with mocked clients to avoid external dependencies