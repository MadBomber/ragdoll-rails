# Ragdoll Engine Documentation

## Overview

Ragdoll is a comprehensive Rails engine that provides Retrieval Augmented Generation (RAG) capabilities for Rails applications. It integrates semantic search, document processing, and AI-enhanced context retrieval using PostgreSQL with vector extensions.

## What is Ragdoll?

Ragdoll transforms your Rails application into a powerful RAG system by providing:

- **Document Ingestion**: Support for PDF, DOCX, TXT, HTML, Markdown, and more
- **Semantic Search**: Vector-based similarity search using AI embeddings
- **Context Enhancement**: Intelligent context injection for AI prompts
- **Multi-Provider Support**: OpenAI, Anthropic, Google, Azure, Ollama, HuggingFace
- **Web Interface**: Complete admin dashboard for document and search management
- **Analytics**: Usage tracking and performance monitoring
- **Background Processing**: Scalable document processing with Sidekiq

## Architecture

Ragdoll is built as a Rails 8.0 engine with the following components:

- **Models**: `Document`, `Embedding`, `Search` for data persistence
- **Services**: Document parsing, text chunking, embedding generation, summarization
- **API Layer**: RESTful API and simplified client interface
- **Background Jobs**: Asynchronous document processing
- **Web Interface**: Bootstrap-based admin dashboard
- **Configuration**: Flexible multi-provider configuration system

## Quick Start

### 1. Installation

Add to your Gemfile:

```ruby
gem 'ragdoll'
```

Run the installer:

```bash
bundle install
rails generate ragdoll:install
rails db:migrate
```

### 2. Configuration

```ruby
# config/initializers/ragdoll.rb
Ragdoll.configure do |config|
  config.embedding_provider = :openai
  config.embedding_model = "text-embedding-3-small"
  config.openai_api_key = ENV['OPENAI_API_KEY']
end
```

### 3. Basic Usage

```ruby
# Add documents
client = Ragdoll::Client.new
document = client.add_file("/path/to/document.pdf")

# Search semantically
results = client.search("machine learning algorithms")

# Enhance prompts with context
enhanced = client.enhance_prompt("Explain neural networks")
puts enhanced[:enhanced_prompt]
```

## Documentation Guide

This documentation is organized into the following sections:

### Getting Started

1. **[Installation Guide](installation.md)** - Complete setup instructions
   - Prerequisites and system requirements
   - Database setup with PostgreSQL and pgvector
   - Gem installation and configuration
   - Environment setup and verification

2. **[Configuration Guide](configuration.md)** - Comprehensive configuration options
   - Multi-provider LLM setup (OpenAI, Anthropic, Google, etc.)
   - Document processing settings
   - Search and similarity configuration
   - Analytics and feature flags
   - Environment-specific configurations

### Integration and Usage

3. **[API Usage Guide](api_usage.md)** - Complete API reference
   - Client interface for common operations
   - Document management (upload, edit, delete)
   - Search and context retrieval
   - Analytics and monitoring
   - Error handling and best practices

4. **[UI Integration Guide](ui_integration.md)** - Web interface integration
   - Dashboard and analytics interfaces
   - Document management UI
   - Search interfaces
   - Configuration management
   - Customization and theming

### Support

5. **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
   - Installation problems
   - Configuration errors
   - Performance issues
   - Database problems
   - Development and testing issues

## Key Features

### Document Processing

- **Multi-format Support**: PDF, DOCX, TXT, HTML, Markdown, JSON, XML, CSV
- **Intelligent Chunking**: Multiple strategies for optimal context preservation
- **Metadata Extraction**: Automatic title, author, and content metadata
- **Background Processing**: Non-blocking document ingestion with Sidekiq

### Semantic Search

- **Vector Embeddings**: High-dimensional semantic representations
- **Similarity Scoring**: Cosine similarity with configurable thresholds
- **Usage-based Ranking**: Learn from user interactions for better results
- **Advanced Filtering**: Filter by document type, metadata, and custom attributes

### AI Integration

- **Multi-Provider Support**: Works with 6+ LLM providers
- **Context Enhancement**: Intelligent prompt augmentation with relevant content
- **Model Flexibility**: Switch between different embedding and chat models
- **Cost Optimization**: Token usage tracking and optimization

### Web Interface

- **Admin Dashboard**: Complete system overview with analytics
- **Document Management**: Upload, organize, and manage documents
- **Search Interface**: Advanced search with real-time filtering
- **Configuration UI**: Visual configuration management
- **Responsive Design**: Mobile-friendly Bootstrap 5 interface

### Analytics and Monitoring

- **Search Analytics**: Track popular queries and performance
- **Usage Metrics**: Document access patterns and user behavior
- **Performance Monitoring**: Search response times and system health
- **Cost Tracking**: API usage and token consumption

## Use Cases

### Customer Support

Enhance customer support with intelligent knowledge base search:

```ruby
# Customer query with context
enhanced = client.enhance_prompt(
  "How do I reset my password?",
  filters: { document_type: "help_article" }
)

# Use enhanced prompt with your chatbot
response = your_ai_service.chat(enhanced[:enhanced_prompt])
```

### Documentation Search

Build powerful documentation search:

```ruby
# Add documentation
client.add_directory("/docs", recursive: true)

# Semantic search across all docs
results = client.search("authentication setup")
```

### Content Management

Intelligent content discovery and recommendation:

```ruby
# Find related content
related = client.search(current_article.title, limit: 5)

# Content recommendations
recommendations = client.get_context(
  user.interests.join(" "),
  filters: { content_type: "article" }
)
```

### Research and Analysis

Semantic search across research documents:

```ruby
# Upload research papers
papers.each { |pdf| client.add_file(pdf, document_type: "research") }

# Find relevant papers
relevant = client.search(
  "transformer architecture attention mechanisms",
  filters: { document_type: "research" }
)
```

## Technical Requirements

### System Requirements

- **Ruby**: 3.2+ (Rails 8.0 compatible)
- **Rails**: 8.0+
- **PostgreSQL**: 14+ with pgvector extension
- **Redis**: For background job processing (recommended)

### External Dependencies

- **AI Provider**: API key for OpenAI, Anthropic, Google, or others
- **Background Jobs**: Sidekiq for production deployments
- **Vector Search**: pgvector PostgreSQL extension

## Performance Characteristics

### Scalability

- **Documents**: Tested with 10,000+ documents
- **Embeddings**: Millions of vector embeddings with HNSW indexing
- **Search**: Sub-second search across large document collections
- **Concurrent Users**: Supports multiple simultaneous users

### Resource Usage

- **Memory**: ~100MB base + 1-2MB per 1000 documents
- **Storage**: ~1KB per embedding, ~10KB per document
- **API Costs**: Configurable to minimize external API usage

## Security Considerations

### Data Protection

- **API Keys**: Secure credential management with Rails credentials
- **User Data**: Isolated document access with proper authorization
- **Content Security**: Configurable content filtering and sanitization

### Access Control

- **Authentication**: Integrate with your existing auth system
- **Authorization**: Role-based access to documents and features
- **Audit Trails**: Track document access and search activity

## Development and Testing

### Development Setup

```bash
# Clone and setup
git clone https://github.com/madbomber/ragdoll.git
cd ragdoll
bundle install

# Run test suite
bundle exec rspec

# Start test application
cd test/dummy
rails server
```

### Testing Support

```ruby
# RSpec helpers provided
include RagdollTestHelpers

# Mock client for testing
let(:client) { mock_ragdoll_client }

# Factory support
create(:ragdoll_document)
create(:ragdoll_embedding)
```

## Contributing

### Development Process

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Code Quality

- **Test Coverage**: Maintain high test coverage
- **Documentation**: Update docs for new features
- **Code Style**: Follow established Ruby/Rails conventions

## Support and Community

### Getting Help

1. **Documentation**: Start with this comprehensive guide
2. **Issues**: GitHub issues for bug reports and feature requests
3. **Examples**: Check the test/dummy application for working examples
4. **Community**: Join discussions and share experiences

### Resources

- **GitHub Repository**: [madbomber/ragdoll](https://github.com/madbomber/ragdoll)
- **Demo Application**: `test/dummy` directory
- **API Documentation**: Generated from source code
- **Examples**: Real-world integration patterns

## Roadmap

### Upcoming Features

- **Vector Database Support**: Pinecone, Weaviate, Chroma integration
- **Advanced Chunking**: Smart document structure awareness
- **Multi-modal Support**: Image and audio document processing
- **Federation**: Multi-tenant and multi-source search
- **Advanced Analytics**: Machine learning insights and recommendations

### Version History

- **0.1.0**: Initial release with core RAG functionality
- **Future**: Enhanced UI, additional providers, performance optimizations

## License

MIT License - see LICENSE file for details.

## Acknowledgments

Built with:
- [Ruby on Rails](https://rubyonrails.org/) - Web framework
- [pgvector](https://github.com/pgvector/pgvector) - Vector similarity search
- [ruby_llm](https://github.com/alexrudall/ruby-openai) - LLM provider integration
- [Bootstrap](https://getbootstrap.com/) - UI framework
- [Sidekiq](https://sidekiq.org/) - Background job processing

---

*This documentation is comprehensive but evolving. For the latest updates, check the GitHub repository and changelog.*