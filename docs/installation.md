# Ragdoll Installation Guide

## Overview

Ragdoll is a Rails engine that provides Retrieval Augmented Generation (RAG) capabilities for Rails applications. It integrates semantic search, document processing, and AI-enhanced context retrieval using PostgreSQL with vector extensions.

## Prerequisites

### System Requirements

- **Ruby**: 3.2+ (Rails 8.0 compatible)
- **Rails**: 8.0+
- **PostgreSQL**: 14+ with pgvector extension
- **Redis**: For background job processing (optional but recommended for production)

### Required PostgreSQL Extensions

Ragdoll requires the following PostgreSQL extensions:

```sql
-- Vector operations for semantic search
CREATE EXTENSION IF NOT EXISTS vector;

-- Text search extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
```

## Installation Steps

### 1. Add to Gemfile

Add ragdoll to your Rails application's Gemfile:

```ruby
# For released version (when available)
gem 'ragdoll'

# For development version from git
gem 'ragdoll', git: 'https://github.com/madbomber/ragdoll.git'

# For local development
gem 'ragdoll', path: '/path/to/local/ragdoll'
```

### 2. Install Dependencies

Run bundle install to install ragdoll and its dependencies:

```bash
bundle install
```

### 3. Database Setup

#### Install Migrations

Generate and run the ragdoll migrations:

```bash
# Generate ragdoll configuration and migrations
rails generate ragdoll:install

# Run the migrations
rails db:migrate
```

This will create the following tables:
- `ragdoll_documents` - Stores document metadata and content
- `ragdoll_embeddings` - Stores vector embeddings for semantic search
- `ragdoll_searches` - Tracks search analytics and performance

#### Verify PostgreSQL Extensions

Ensure the required PostgreSQL extensions are installed:

```bash
# Connect to your PostgreSQL database
psql your_database_name

# Check for extensions
\dx

# If not present, install them
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
```

### 4. Configuration

#### Basic Configuration

Create or update your ragdoll configuration:

```ruby
# config/initializers/ragdoll.rb
Ragdoll.configure do |config|
  # LLM Provider Configuration
  config.embedding_provider = :openai
  config.embedding_model = "text-embedding-3-small"
  config.api_key = ENV['OPENAI_API_KEY']
  
  # Document Processing
  config.default_chunk_size = 1000
  config.default_chunk_overlap = 200
  
  # Search Configuration
  config.similarity_threshold = 0.7
  config.max_results = 10
  
  # Analytics (optional)
  config.usage_ranking_enabled = true
end
```

#### Environment Variables

Set up your environment variables:

```bash
# .env or environment configuration
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here  # if using Anthropic
GOOGLE_API_KEY=your_google_api_key_here        # if using Google

# Database (if not in database.yml)
DATABASE_URL=postgresql://user:password@localhost/your_app_development

# Redis (for background jobs)
REDIS_URL=redis://localhost:6379/0
```

### 5. Background Job Processing (Recommended)

#### Configure Sidekiq

Add Sidekiq to your Gemfile if not already present:

```ruby
gem 'sidekiq'
```

Configure Sidekiq in your application:

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

Start Sidekiq for background processing:

```bash
bundle exec sidekiq
```

#### Alternative: Async Adapter

For development or simple deployments, you can use the async adapter:

```ruby
# config/environments/development.rb
config.active_job.queue_adapter = :async
```

### 6. Verify Installation

#### Run Basic Tests

Test your installation with a simple document:

```ruby
# In rails console
rails console

# Test basic functionality
client = Ragdoll::Client.new

# Add a test document
document = client.add_document("This is a test document about machine learning and AI.", {
  title: "Test Document",
  document_type: "text"
})

# Wait for processing (or run background jobs)
# Then search
results = client.search("machine learning")
puts results.inspect
```

#### Check Database Tables

Verify the tables were created correctly:

```bash
rails console

# Check tables exist
ActiveRecord::Base.connection.tables.select { |t| t.include?('ragdoll') }

# Check sample data
Ragdoll::Document.count
Ragdoll::Embedding.count
```

## Production Deployment Considerations

### Security

1. **API Keys**: Store API keys securely using Rails credentials or environment variables
2. **Authentication**: Implement authentication for ragdoll endpoints
3. **Authorization**: Add access control for document management

### Performance

1. **Database**: Use PostgreSQL with appropriate memory allocation for vector operations
2. **Background Jobs**: Use Redis and Sidekiq for document processing
3. **Indexing**: Ensure vector indexes are properly created (handled by migrations)

### Monitoring

1. **Performance**: Monitor search response times and document processing duration
2. **Usage**: Track API usage if using paid LLM providers
3. **Storage**: Monitor database growth, especially for embeddings table

## Troubleshooting

### Common Issues

#### PostgreSQL Extension Errors

If you see errors about missing extensions:

```bash
# Install extensions manually
sudo -u postgres psql your_database
CREATE EXTENSION IF NOT EXISTS vector;
```

#### Vector Dimension Mismatches

If you see dimension mismatch errors:

```ruby
# Clear existing embeddings and reprocess
Ragdoll::Embedding.delete_all
# Reprocess documents
Ragdoll::Document.find_each(&:reprocess!)
```

#### Background Job Issues

If documents aren't processing:

```bash
# Check Sidekiq is running
ps aux | grep sidekiq

# Check job queue
bundle exec rails console
Sidekiq::Queue.new.size
```

#### API Key Issues

If you get authentication errors:

```bash
# Verify API keys are set
echo $OPENAI_API_KEY

# Test API access
curl -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models
```

### Debug Mode

Enable debug logging for troubleshooting:

```ruby
# config/environments/development.rb
config.log_level = :debug

# In your ragdoll configuration
Ragdoll.configure do |config|
  config.debug = true
end
```

## Next Steps

After successful installation:

1. Read the [Configuration Guide](configuration.md) for detailed setup options
2. See [API Usage](api_usage.md) for integration examples
3. Check [UI Integration](ui_integration.md) for web interface setup
4. Review [Troubleshooting](troubleshooting.md) for common issues

## Support

For issues and questions:

1. Check the troubleshooting guide
2. Review the GitHub issues
3. Consult the API documentation
4. Check the test/dummy application for working examples