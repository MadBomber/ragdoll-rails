# Ragdoll Troubleshooting Guide

## Overview

This guide covers common issues, error messages, and solutions when working with the Ragdoll engine. Issues are organized by category with step-by-step resolution instructions.

## Installation Issues

### PostgreSQL Extension Errors

**Error:** `PG::UndefinedFile: ERROR: could not open extension control file`

**Solution:**
```bash
# Install pgvector extension
# Ubuntu/Debian
sudo apt-get install postgresql-14-pgvector

# macOS with Homebrew
brew install pgvector

# Then connect to your database and enable extensions
sudo -u postgres psql your_database_name
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
```

**Error:** `PG::InsufficientPrivilege: ERROR: permission denied to create extension`

**Solution:**
```bash
# Grant extension creation privileges
sudo -u postgres psql
ALTER USER your_username CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE your_database TO your_username;

# Or run as superuser
sudo -u postgres psql your_database_name
CREATE EXTENSION vector;
```

### Gem Installation Issues

**Error:** `Could not find gem 'ragdoll'`

**Solution:**
```ruby
# For development version, use git source
gem 'ragdoll', git: 'https://github.com/madbomber/ragdoll.git'

# Or local path
gem 'ragdoll', path: '/path/to/ragdoll'

# Then bundle
bundle install
```

**Error:** `Bundler could not find compatible versions for gem "rails"`

**Solution:**
```ruby
# Ensure Rails 8.0+ compatibility
gem 'rails', '~> 8.0'
gem 'ragdoll'

# Update Gemfile.lock
bundle update rails
```

### Migration Issues

**Error:** `ActiveRecord::PendingMigrationError`

**Solution:**
```bash
# Generate and run ragdoll migrations
rails generate ragdoll:install
rails db:migrate

# If migrations already exist but not run
rails db:migrate:status
rails db:migrate
```

**Error:** `PG::DuplicateTable: ERROR: relation "ragdoll_documents" already exists`

**Solution:**
```bash
# Check migration status
rails db:migrate:status

# If needed, reset migrations
rails db:drop db:create db:migrate

# Or rollback specific migration
rails db:rollback STEP=1
```

## Configuration Issues

### API Key Problems

**Error:** `OpenAI::AuthenticationError: Incorrect API key provided`

**Solution:**
```bash
# Verify API key is set
echo $OPENAI_API_KEY

# Check key format (should start with sk-)
# Set in environment or Rails credentials
export OPENAI_API_KEY=sk-your-actual-key

# Or use Rails credentials
rails credentials:edit
# Add: openai_api_key: sk-your-key
```

**Error:** `Anthropic::AuthenticationError: Invalid API key`

**Solution:**
```bash
# Anthropic keys start with sk-ant-
export ANTHROPIC_API_KEY=sk-ant-your-key

# Verify in configuration
Ragdoll.configure do |config|
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
end
```

### Model Configuration Issues

**Error:** `OpenAI::BadRequestError: The model 'gpt-5' does not exist`

**Solution:**
```ruby
# Use correct model names
Ragdoll.configure do |config|
  config.default_model = 'gpt-4'  # Not 'gpt-5'
  config.embedding_model = 'text-embedding-3-small'  # Correct embedding model
end

# Check available models
client = OpenAI::Client.new
client.models.list
```

### Embedding Dimension Mismatches

**Error:** `PG::InvalidParameterValue: ERROR: vector dimension 1536 does not match column dimension 3072`

**Solution:**
```ruby
# Clear existing embeddings and recreate
Ragdoll::Embedding.delete_all

# Update configuration to match existing data
Ragdoll.configure do |config|
  config.embedding_model = 'text-embedding-3-large'  # 3072 dimensions
  # Or use text-embedding-3-small for 1536 dimensions
end

# Reprocess documents
Ragdoll::Document.find_each(&:reprocess!)
```

## Document Processing Issues

### File Upload Errors

**Error:** `Errno::ENOENT: No such file or directory @ rb_sysopen`

**Solution:**
```ruby
# Verify file exists and path is correct
file_path = "/absolute/path/to/document.pdf"
raise "File not found: #{file_path}" unless File.exist?(file_path)

client = Ragdoll::Client.new
document = client.add_file(file_path)
```

**Error:** `PDF::Reader::MalformedPDFError: PDF is malformed`

**Solution:**
```ruby
# Check file integrity
begin
  document = client.add_file(pdf_path)
rescue PDF::Reader::MalformedPDFError => e
  # Try alternative processing or skip file
  Rails.logger.error "Skipping malformed PDF: #{pdf_path}"
end

# Or use alternative parser
document = client.add_file(
  pdf_path,
  parser_options: { strict_mode: false }
)
```

### Background Job Issues

**Error:** Jobs not processing documents

**Solution:**
```bash
# Check Sidekiq is running
ps aux | grep sidekiq

# Start Sidekiq
bundle exec sidekiq

# Check job queue
bundle exec rails console
Sidekiq::Queue.new.size
Sidekiq::Queue.new.each { |job| puts job.inspect }

# Clear failed jobs
Sidekiq::RetrySet.new.clear
Sidekiq::DeadSet.new.clear
```

**Error:** `Sidekiq::Shutdown: Sidekiq shutting down`

**Solution:**
```ruby
# Increase shutdown timeout in config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.options[:timeout] = 30  # Increase from default 8 seconds
end

# Or use synchronous processing for development
Rails.application.configure do
  config.active_job.queue_adapter = :inline
end
```

### Document Status Issues

**Error:** Documents stuck in "processing" status

**Solution:**
```ruby
# Check for failed background jobs
failed_jobs = Sidekiq::RetrySet.new.select { |job| job['class'] == 'Ragdoll::ImportFileJob' }

# Reset stuck documents
stuck_docs = Ragdoll::Document.where(status: 'processing')
                              .where('processing_started_at < ?', 1.hour.ago)

stuck_docs.update_all(status: 'pending')

# Reprocess
stuck_docs.find_each do |doc|
  Ragdoll::ImportFileJob.perform_later(doc.id)
end
```

## Search and Retrieval Issues

### No Search Results

**Problem:** Search returns empty results even with relevant documents

**Solution:**
```ruby
# Check documents are processed
processed_docs = Ragdoll::Document.where(status: 'processed').count
puts "Processed documents: #{processed_docs}"

# Check embeddings exist
embeddings_count = Ragdoll::Embedding.count
puts "Total embeddings: #{embeddings_count}"

# Lower similarity threshold for testing
results = client.search("query", threshold: 0.3)

# Check if embeddings have proper dimensions
Ragdoll::Embedding.group(:embedding_dimensions).count
```

**Problem:** Search results have very low similarity scores

**Solution:**
```ruby
# Verify embedding model consistency
current_model = Ragdoll.configuration.embedding_model
embedding_models_used = Ragdoll::Embedding.distinct.pluck(:model_name)

puts "Current model: #{current_model}"
puts "Models in database: #{embedding_models_used}"

# If models differ, reprocess with consistent model
if embedding_models_used.any? { |m| m != current_model }
  Ragdoll::Embedding.delete_all
  Ragdoll::Document.update_all(status: 'pending')
  # Reprocess all documents
end
```

### Vector Search Errors

**Error:** `PG::UndefinedFunction: ERROR: operator does not exist: vector <=> vector`

**Solution:**
```sql
-- Ensure pgvector extension is properly installed
SELECT * FROM pg_extension WHERE extname = 'vector';

-- If not found, install it
CREATE EXTENSION vector;

-- Check vector operators are available
SELECT oprname FROM pg_operator WHERE oprname LIKE '%<%' AND oprleft = 'vector'::regtype;
```

**Error:** `ActiveRecord::StatementInvalid: PG::InvalidParameterValue: ERROR: vector must have same dimensions for comparison`

**Solution:**
```ruby
# Find embeddings with different dimensions
dimension_counts = Ragdoll::Embedding.group(:embedding_dimensions).count
puts "Dimension distribution: #{dimension_counts}"

# Remove embeddings with wrong dimensions
correct_dimension = Ragdoll.configuration.embedding_model == 'text-embedding-3-large' ? 3072 : 1536
Ragdoll::Embedding.where.not(embedding_dimensions: correct_dimension).delete_all

# Reprocess affected documents
affected_docs = Ragdoll::Document.joins(:ragdoll_embeddings)
                                 .where(ragdoll_embeddings: { embedding_dimensions: nil })
                                 .distinct

affected_docs.update_all(status: 'pending')
```

## Performance Issues

### Slow Search Performance

**Problem:** Search queries taking too long

**Solution:**
```sql
-- Check if HNSW index exists
SELECT indexname FROM pg_indexes WHERE tablename = 'ragdoll_embeddings';

-- If index is missing, create it
CREATE INDEX CONCURRENTLY idx_ragdoll_embeddings_hnsw_cosine 
ON ragdoll_embeddings USING hnsw (embedding vector_cosine_ops);

-- Monitor index usage
EXPLAIN ANALYZE SELECT * FROM ragdoll_embeddings 
ORDER BY embedding <=> '[0.1,0.2,...]' LIMIT 10;
```

**Solution for application-level optimization:**
```ruby
# Implement caching for frequent queries
class CachedRagdollClient
  def search(query, **options)
    cache_key = "ragdoll:search:#{Digest::MD5.hexdigest(query + options.to_s)}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      super
    end
  end
end

# Reduce search result limit
Ragdoll.configure do |config|
  config.max_search_results = 5  # Instead of 10+
end
```

### Memory Usage Issues

**Problem:** High memory consumption during document processing

**Solution:**
```ruby
# Process documents in smaller batches
def process_large_directory(path)
  files = Dir.glob(File.join(path, "**/*")).select { |f| File.file?(f) }
  
  files.each_slice(10) do |batch|
    batch.each { |file| client.add_file(file) }
    GC.start  # Force garbage collection
    sleep(1)  # Brief pause
  end
end

# Reduce chunk size to decrease memory usage
Ragdoll.configure do |config|
  config.chunk_size = 500  # Smaller chunks
  config.chunk_overlap = 50
end
```

## Network and API Issues

### Rate Limiting

**Error:** `OpenAI::RateLimitError: Rate limit reached`

**Solution:**
```ruby
# Implement retry logic with exponential backoff
def with_retry(max_retries: 3, &block)
  retries = 0
  begin
    yield
  rescue OpenAI::RateLimitError => e
    if retries < max_retries
      wait_time = 2 ** retries
      Rails.logger.warn "Rate limited, waiting #{wait_time}s (attempt #{retries + 1})"
      sleep(wait_time)
      retries += 1
      retry
    else
      raise e
    end
  end
end

# Use in document processing
with_retry do
  client.add_document(content)
end
```

### Network Timeouts

**Error:** `Faraday::TimeoutError: Net::ReadTimeout`

**Solution:**
```ruby
# Increase timeout in configuration
Ragdoll.configure do |config|
  config.llm_config[:openai][:timeout] = 60  # Increase timeout to 60 seconds
end

# Or configure Faraday directly
require 'faraday'
require 'faraday/retry'

connection = Faraday.new(url: 'https://api.openai.com') do |f|
  f.request :retry, max: 3, interval: 0.5
  f.options.timeout = 60
  f.options.read_timeout = 60
end
```

## Database Issues

### Connection Problems

**Error:** `PG::ConnectionBad: FATAL: database "ragdoll_development" does not exist`

**Solution:**
```bash
# Create database
rails db:create

# Or manually
createdb ragdoll_development

# Check database configuration
cat config/database.yml
```

**Error:** `PG::ConnectionBad: FATAL: role "username" does not exist`

**Solution:**
```sql
-- Create user with appropriate privileges
sudo -u postgres psql
CREATE USER your_username WITH CREATEDB PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE ragdoll_development TO your_username;
```

### Disk Space Issues

**Error:** `PG::DiskFull: ERROR: could not extend file`

**Solution:**
```bash
# Check disk space
df -h

# Clean up old embeddings if needed
rails console
old_embeddings = Ragdoll::Embedding.where('created_at < ?', 30.days.ago)
old_embeddings.delete_all

# Vacuum database to reclaim space
rails dbconsole
VACUUM FULL ragdoll_embeddings;
```

## Development and Testing Issues

### Test Database Setup

**Problem:** Tests failing due to missing extensions

**Solution:**
```ruby
# In spec/rails_helper.rb or test/test_helper.rb
RSpec.configure do |config|
  config.before(:suite) do
    # Ensure extensions are available in test database
    ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector")
    ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS fuzzystrmatch")
  end
end
```

### Factory Issues

**Problem:** FactoryBot factories not working with ragdoll models

**Solution:**
```ruby
# Create proper factories in spec/factories/
FactoryBot.define do
  factory :ragdoll_document, class: 'Ragdoll::Document' do
    title { "Test Document" }
    content { "Sample content for testing" }
    document_type { "text" }
    status { "processed" }
    location { "/tmp/test.txt" }
  end
  
  factory :ragdoll_embedding, class: 'Ragdoll::Embedding' do
    association :document, factory: :ragdoll_document
    content { "Sample embedding content" }
    embedding { Array.new(1536) { rand(-1.0..1.0) } }
    model_name { "text-embedding-3-small" }
    embedding_dimensions { 1536 }
  end
end
```

## Debugging Tips

### Enable Debug Logging

```ruby
# In development environment
Rails.logger.level = :debug

# For ragdoll-specific debugging
Ragdoll.configure do |config|
  config.debug = true  # If available
end

# Monitor SQL queries
ActiveRecord::Base.logger = Rails.logger
```

### Inspect Configuration

```ruby
# Check current configuration
puts Ragdoll.configuration.inspect

# Test API connectivity
begin
  client = Ragdoll::Client.new
  puts "Health check: #{client.healthy?}"
rescue => e
  puts "Configuration error: #{e.message}"
end
```

### Database Inspection

```sql
-- Check table sizes
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats 
WHERE tablename IN ('ragdoll_documents', 'ragdoll_embeddings', 'ragdoll_searches');

-- Check embedding statistics
SELECT 
    COUNT(*) as total_embeddings,
    AVG(embedding_dimensions) as avg_dimensions,
    COUNT(DISTINCT model_name) as unique_models
FROM ragdoll_embeddings;

-- Find problematic embeddings
SELECT id, model_name, embedding_dimensions 
FROM ragdoll_embeddings 
WHERE embedding IS NULL OR embedding_dimensions IS NULL;
```

## Getting Help

### Log Analysis

When reporting issues, include relevant logs:

```bash
# Application logs
tail -f log/development.log

# Sidekiq logs
tail -f log/sidekiq.log

# PostgreSQL logs (location varies by system)
tail -f /var/log/postgresql/postgresql-14-main.log
```

### Environment Information

Collect environment details:

```ruby
# In rails console
puts "Ruby version: #{RUBY_VERSION}"
puts "Rails version: #{Rails.version}"
puts "Ragdoll version: #{Ragdoll::VERSION}"
puts "Database adapter: #{ActiveRecord::Base.connection.adapter_name}"

# Check gem versions
puts Gem.loaded_specs['ragdoll']&.version
puts Gem.loaded_specs['pgvector']&.version
puts Gem.loaded_specs['ruby_llm']&.version
```

### Useful Commands for Diagnosis

```bash
# Check database connectivity
rails runner "puts ActiveRecord::Base.connection.execute('SELECT version()').first"

# Test embedding service
rails runner "puts Ragdoll::EmbeddingService.new.generate_embedding('test').length"

# Count records
rails runner "puts 'Documents: ' + Ragdoll::Document.count.to_s"
rails runner "puts 'Embeddings: ' + Ragdoll::Embedding.count.to_s"

# Check background job status
rails runner "puts 'Queue size: ' + Sidekiq::Queue.new.size.to_s"
```

For additional support, consult the GitHub issues page or check the test/dummy application for working examples.