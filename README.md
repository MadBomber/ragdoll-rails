<div align="center">
  <h1>🎯 Ragdoll</h1>
  <p><strong>Retrieval Augmented Generation for Rails Applications</strong></p>
  <img src="images/ragdoll.png" alt="Raggedy Ann playing with blocks" width="200">
</div>

---

> CAUTION: Ragdoll is still under development and may not be suitable for production use.

**Ragdoll** is a powerful Rails engine that adds **Retrieval Augmented Generation (RAG)** capabilities to any Rails application. It provides semantic search, document ingestion, and context-enhanced AI prompts using vector embeddings and PostgreSQL with pgvector.

## ✨ Features

- 🔍 **Semantic Search** - Vector similarity search using OpenAI embeddings and pgvector
- 📄 **Multi-format Support** - PDF, DOCX, text, HTML, JSON, XML, CSV document parsing
- 🧠 **Context Enhancement** - Automatically enhance AI prompts with relevant context
- ⚡ **Background Processing** - Asynchronous document processing with Sidekiq
- 🎛️ **Simple API** - Clean, intuitive interface for Rails integration
- 📊 **Analytics** - Search analytics and document management insights
- 🔧 **Configurable** - Flexible chunking, embedding, and search parameters

## 🚀 Quick Start

### Installation

Add Ragdoll to your Rails application:

```ruby
# Gemfile
gem 'ragdoll'
```

```bash
bundle install
```

### Database Setup

Ragdoll requires PostgreSQL with the pgvector extension:

```bash
# Run migrations
rails ragdoll:install:migrations
rails db:migrate
```

### Configuration

```ruby
# config/initializers/ragdoll.rb
Ragdoll.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.embedding_model = 'text-embedding-3-small'
  config.chunk_size = 1000
  config.search_similarity_threshold = 0.7
end
```

### Basic Usage

```ruby
# Add documents
Ragdoll.add_file('/path/to/manual.pdf')
Ragdoll.add_text('Your content here', title: 'Knowledge Base')

# Enhance AI prompts with context
enhanced = Ragdoll.enhance_prompt(
  'How do I configure the database?',
  context_limit: 5
)

# Use enhanced prompt with your AI service
ai_response = YourAI.complete(enhanced[:enhanced_prompt])
```

## 📖 API Reference

### Context Enhancement for AI

The primary method for RAG applications - automatically finds relevant context and enhances prompts:

```ruby
enhanced = Ragdoll.enhance_prompt(
  "How do I deploy to production?",
  context_limit: 3,
  threshold: 0.8
)

# Returns:
{
  enhanced_prompt: "...",    # Prompt with context injected
  original_prompt: "...",    # Original user prompt
  context_sources: [...],    # Source documents
  context_count: 2           # Number of context chunks
}
```

### Semantic Search

```ruby
# Search for similar content
results = Ragdoll.search(
  "database configuration",
  limit: 10,
  threshold: 0.6,
  filters: { document_type: 'pdf' }
)

# Get raw context without prompt enhancement
context = Ragdoll.client.get_context(
  "API authentication",
  limit: 5
)
```

### Document Management

```ruby
# Add documents
Ragdoll.add_file('/docs/manual.pdf')
Ragdoll.add_text('Content', title: 'Guide')
Ragdoll.add_directory('/knowledge-base', recursive: true)

# Manage documents
client = Ragdoll::Client.new
client.update_document(123, title: 'New Title')
client.delete_document(123)
client.list_documents(limit: 50)

# Bulk operations
client.reprocess_failed
client.add_directory('/docs', recursive: true)
```

## 🏗️ Rails Integration Examples

### Chat Controller

```ruby
class ChatController < ApplicationController
  def ask
    enhanced = Ragdoll.enhance_prompt(
      params[:question],
      context_limit: 5
    )

    ai_response = OpenAI.complete(enhanced[:enhanced_prompt])

    render json: {
      answer: ai_response,
      sources: enhanced[:context_sources],
      context_used: enhanced[:context_count] > 0
    }
  end
end
```

### Support Bot Service

```ruby
class SupportBot
  def initialize
    @ragdoll = Ragdoll::Client.new
  end

  def answer_question(question, category: nil)
    filters = { document_type: 'pdf' } if category == 'manual'

    context = @ragdoll.get_context(
      question,
      limit: 3,
      threshold: 0.8,
      filters: filters
    )

    if context[:total_chunks] > 0
      prompt = build_prompt(question, context[:combined_context])
      ai_response = call_ai_service(prompt)

      {
        answer: ai_response,
        confidence: :high,
        sources: context[:context_chunks]
      }
    else
      fallback_response(question)
    end
  end
end
```

### Background Processing

```ruby
class ProcessDocumentsJob < ApplicationJob
  def perform(file_paths)
    ragdoll = Ragdoll::Client.new

    file_paths.each do |path|
      ragdoll.add_file(path, process_immediately: true)
    end
  end
end
```

## 🛠️ Command Line Tools

### Thor Commands

```bash
# Document management
thor ragdoll:document:add /path/to/file.pdf --process_now
thor ragdoll:document:list --status completed --limit 20
thor ragdoll:document:show 123
thor ragdoll:document:delete 123 --confirm

# Import operations
thor ragdoll:import:import /docs --recursive --jobs 4
```

### Rake Tasks

```bash
# Add documents
rake ragdoll:document:add[/path/to/file.pdf] PROCESS_NOW=true
TITLE="Manual" rake ragdoll:document:add[content.txt]

# Bulk operations
rake ragdoll:document:bulk:reprocess_failed
rake ragdoll:document:bulk:cleanup_orphaned
STATUS=failed rake ragdoll:document:bulk:delete_by_status[failed]

# List and search
LIMIT=50 rake ragdoll:document:list
rake ragdoll:document:show[123]
```

## 📋 Supported Document Types

| Format | Extension | Features |
|--------|-----------|----------|
| PDF | `.pdf` | Text extraction, metadata, page info |
| DOCX | `.docx` | Paragraphs, tables, document properties |
| Text | `.txt`, `.md` | Plain text, markdown |
| HTML | `.html`, `.htm` | Tag stripping, content extraction |
| Data | `.json`, `.xml`, `.csv` | Structured data parsing |

## ⚙️ Configuration Options

```ruby
Ragdoll.configure do |config|
  # OpenAI settings
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.embedding_model = 'text-embedding-3-small'
  config.default_model = 'gpt-4'

  # Chunking settings
  config.chunk_size = 1000
  config.chunk_overlap = 200

  # Search settings
  config.search_similarity_threshold = 0.7
  config.max_search_results = 10

  # Analytics and caching
  config.enable_search_analytics = true
  config.cache_embeddings = true

  # Custom prompt template
  config.prompt_template = <<~TEMPLATE
    Context: {{context}}
    Question: {{prompt}}
    Answer:
  TEMPLATE
end
```

## 🏗️ Database Schema

Ragdoll creates three main tables:

- **`ragdoll_documents`** - Document metadata and content
- **`ragdoll_embeddings`** - Vector embeddings with pgvector
- **`ragdoll_searches`** - Search analytics and caching

## 📊 Analytics and Monitoring

```ruby
# Document statistics
stats = Ragdoll.client.stats
# => { total_documents: 150, total_embeddings: 1250, ... }

# Search analytics
analytics = Ragdoll.client.search_analytics(days: 30)
# => { total_searches: 500, average_results: 8.5, ... }

# Health check
healthy = Ragdoll.client.healthy?
# => true/false
```

## 🧪 Testing

```ruby
# spec/support/ragdoll_helpers.rb
module RagdollHelpers
  def setup_test_documents
    @ragdoll = Ragdoll::Client.new
    @doc = @ragdoll.add_text(
      "Rails is a web framework",
      title: "Rails Guide",
      process_immediately: true
    )
  end
end

# In your specs
RSpec.describe ChatController do
  include RagdollHelpers

  before { setup_test_documents }

  it "enhances prompts with context" do
    enhanced = Ragdoll.enhance_prompt("What is Rails?")
    expect(enhanced[:context_count]).to be > 0
  end
end
```

## 📦 Dependencies

- **Rails** 8.0+
- **PostgreSQL** with pgvector extension
- **Sidekiq** for background processing
- **OpenAI API** for embeddings

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## 🆘 Support

- 📖 [Documentation](https://github.com/MadBomber/ragdoll)
- 🐛 [Issues](https://github.com/MadBomber/ragdoll/issues)
- 💬 [Discussions](https://github.com/MadBomber/ragdoll/discussions)

---

<div align="center">
  <p>Made with ❤️ for the Rails community</p>
  <p>⭐ Star this repo if you find it useful!</p>
</div>
