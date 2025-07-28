<div align="center" style="background-color: yellow; color: black; padding: 20px; margin: 20px 0; border: 2px solid black; font-size: 48px; font-weight: bold;">
  ⚠️ CAUTION ⚠️<br />
  Software Under Development by a Crazy Man
</div>
<br />
<div align="center">
  <table>
    <tr>
      <td width="50%">
        <a href="https://research.ibm.com/blog/retrieval-augmented-generation-RAG" target="_blank">
          <img src="ragdoll-rails.png" alt="Ragdoll Riding the Rails" width="800">
        </a>
      </td>
      <td width="50%" valign="top">
        <p>Multi-modal RAG (Retrieval-Augmented Generation) is an architecture that integrates multiple data types (such as text, images, and audio) to enhance AI response generation. It combines retrieval-based methods, which fetch relevant information from a knowledge base, with generative large language models (LLMs) that create coherent and contextually appropriate outputs. This approach allows for more comprehensive and engaging user interactions, such as chatbots that respond with both text and images or educational tools that incorporate visual aids into learning materials. By leveraging various modalities, multi-modal RAG systems improve context understanding and user experience.</p>
      </td>
    </tr>
  </table>
</div>

# Ragdoll::Rails

**Ragdoll** is a powerful Rails engine that adds **Multi-modal Retrieval Augmented Generation (RAG)** capabilities to any Rails application. It provides semantic search, document ingestion, and context-enhanced AI prompts using vector embeddings and PostgreSQL with pgvector. With support for multiple LLM providers through [ruby_llm](https://rubyllm.com), you can use OpenAI, Anthropic, Google, Azure, Ollama, and more.

See Also:

- [Ragdoll::Core](https://github.com/MadBomber/ragdoll)
- [Ragdoll::CLI](https://github.com/MadBomber/ragdoll-cli)
- [Ragdoll::Rails](https://github.com/MadBomber/ragdoll-rails) this gem
- [Demo Rails App](https://github.com/madbomber/ragdoll_demo_app)

## ✨ Features

- 🔍 **Semantic Search** - Vector similarity search with flexible embedding models and pgvector
- 🤖 **Multi-Provider Support** - OpenAI, Anthropic, Google, Azure, Ollama, HuggingFace via ruby_llm
- 📄 **Multi-format Support** - PDF, DOCX, text, HTML, JSON, XML, CSV document parsing
- 🧠 **Context Enhancement** - Automatically enhance AI prompts with relevant context
- ⚡ **Background Processing** - Asynchronous document processing with Sidekiq
- 🎛️ **Simple API** - Clean, intuitive interface for Rails integration
- 📊 **Analytics** - Search analytics and document management insights
- 🔧 **Configurable** - Flexible chunking, embedding, and search parameters
- 🔄 **Flexible Vectors** - Variable-length embeddings for different models

## 🚀 Quick Start

### Installation

Add Ragdoll to your Rails application:

```ruby
# Gemfile
gem 'ragdoll-rails'
gem 'ragdoll-cli' # Optional CLI tool for managing documents and embeddings
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
  # LLM Provider Configuration
  config.llm_provider = :openai  # or :anthropic, :google, :azure, :ollama, :huggingface
  config.embedding_provider = :openai  # optional, defaults to llm_provider

  # Provider-specific API keys
  config.llm_config = {
    openai: { api_key: ENV['OPENAI_API_KEY'] },
    anthropic: { api_key: ENV['ANTHROPIC_API_KEY'] },
    google: { api_key: ENV['GOOGLE_API_KEY'], project_id: ENV['GOOGLE_PROJECT_ID'] }
  }

  # Embedding and processing settings
  config.embedding_model = 'text-embedding-3-small'
  config.chunk_size = 1000
  config.search_similarity_threshold = 0.7
  config.max_embedding_dimensions = 3072  # supports variable-length vectors
end
```

### Basic Usage

```ruby
# Add documents
Ragdoll.add_document('/path/to/manual.pdf')
Ragdoll.add_directory('/path/to/directory_of_documents', recursive: true)

# Enhance AI prompts with context
enhanced = Ragdoll.enhance_prompt(
  'How do I configure the database?',
  context_limit: 5
)

# Use enhanced prompt with RubyLLM
ai_response = RubyLLM.ask(enhanced[:enhanced_prompt])
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

### Multi-Provider Configuration

```ruby
Ragdoll.configure do |config|
  # Primary LLM provider for chat/completion
  config.llm_provider = :anthropic

  # Separate provider for embeddings (optional)
  config.embedding_provider = :openai

  # Provider-specific configurations
  config.llm_config = {
    openai: {
      api_key: ENV['OPENAI_API_KEY'],
      organization: ENV['OPENAI_ORGANIZATION'],  # optional
      project: ENV['OPENAI_PROJECT']              # optional
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
end
```

### Model and Processing Settings

```ruby
Ragdoll.configure do |config|
  # Embedding configuration
  config.embedding_model = 'text-embedding-3-small'
  config.max_embedding_dimensions = 3072  # supports variable dimensions
  config.default_model = 'gpt-4'  # for chat/completion

  # Text chunking settings
  config.chunk_size = 1000
  config.chunk_overlap = 200

  # Search and similarity settings
  config.search_similarity_threshold = 0.7
  config.max_search_results = 10

  # Analytics and performance
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

### Provider Examples

```ruby
# OpenAI Configuration
Ragdoll.configure do |config|
  config.llm_provider = :openai
  config.llm_config = {
    openai: { api_key: ENV['OPENAI_API_KEY'] }
  }
  config.embedding_model = 'text-embedding-3-small'
end

# Anthropic + OpenAI Embeddings
Ragdoll.configure do |config|
  config.llm_provider = :anthropic
  config.embedding_provider = :openai
  config.llm_config = {
    anthropic: { api_key: ENV['ANTHROPIC_API_KEY'] },
    openai: { api_key: ENV['OPENAI_API_KEY'] }
  }
end

# Local Ollama Setup
Ragdoll.configure do |config|
  config.llm_provider = :ollama
  config.llm_config = {
    ollama: { endpoint: 'http://localhost:11434' }
  }
  config.embedding_model = 'nomic-embed-text'
end
```

## 🏗️ Database Schema

Ragdoll creates three main tables:

- **`ragdoll_documents`** - Document metadata and content
- **`ragdoll_embeddings`** - Vector embeddings with pgvector (variable dimensions)
- **`ragdoll_searches`** - Search analytics and performance tracking

### Key Features

- **Variable Vector Dimensions**: Supports different embedding models with different dimensions
- **Model Tracking**: Tracks which embedding model was used for each vector
- **Performance Indexes**: Optimized for similarity search and filtering
- **Search Analytics**: Comprehensive search performance and usage tracking

## 📊 Analytics and Monitoring

```ruby
# Document statistics
stats = Ragdoll.client.stats
# => { total_documents: 150, total_embeddings: 1250, ... }

# Search analytics
analytics = Ragdoll::Search.analytics(days: 30)
# => {
#   total_searches: 500,
#   unique_queries: 350,
#   average_results: 8.5,
#   average_search_time: 0.15,
#   success_rate: 85.2,
#   most_common_queries: [...],
#   search_types: { semantic: 450, keyword: 50 },
#   models_used: { "text-embedding-3-small": 400, "text-embedding-3-large": 100 },
#   performance_stats: { fastest: 0.05, slowest: 2.3, median: 0.12 }
# }

# Performance monitoring
slow_searches = Ragdoll::Search.slow_searches(2.0)  # > 2 seconds
failed_searches = Ragdoll::Search.failed

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
- **ruby_llm** for multi-provider LLM support
- **LLM Provider APIs** (OpenAI, Anthropic, Google, etc.)

### Supported LLM Providers

| Provider | Chat/Completion | Embeddings | Notes |
|----------|----------------|------------|---------|
| OpenAI | ✅ | ✅ | GPT models, text-embedding-3-* |
| Anthropic | ✅ | ❌ | Claude models |
| Google | ✅ | ✅ | Gemini models |
| Azure OpenAI | ✅ | ✅ | Azure-hosted OpenAI |
| Ollama | ✅ | ✅ | Local models |
| HuggingFace | ✅ | ✅ | Various open-source models |

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
