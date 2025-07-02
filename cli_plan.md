# Ragdoll CLI Utility Plan

## Overview

This plan outlines the development of a comprehensive command-line interface (CLI) utility for the Ragdoll RAG (Retrieval-Augmented Generation) engine. The `ragdoll` executable will provide users with a complete toolkit for database management, document ingestion, and intelligent query processing through a unified command-line interface.

## Executable Location

- **Path**: `bin/ragdoll`
- **Type**: Standalone Ruby executable
- **Dependencies**: Thor gem for command structure, Ragdoll engine

## Core Architecture

### Command Structure
The CLI will use a hierarchical command structure powered by Thor:

```
ragdoll <command> [subcommand] [options] [arguments]
```

### Configuration Management
- Global configuration file: `~/.ragdoll/config.yml`
- Project-local configuration: `.ragdoll.yml` (optional)
- Environment variable overrides
- Command-line option overrides

## Commands Specification

### 1. Initialization Command

**Command**: `ragdoll init [database_name]`

**Purpose**: Initialize a new Ragdoll database and configuration

**Options**:
- `--database-url` - Custom database connection string
- `--provider` - LLM provider (openai, anthropic, google, azure, ollama, huggingface)
- `--embedding-model` - Embedding model to use
- `--config-file` - Path to configuration file
- `--force` - Overwrite existing configuration

**Functionality**:
1. Create database schema (run migrations)
2. Generate configuration file with user preferences
3. Test database and API connections
4. Create initial project structure if needed
5. Display setup summary and next steps

**Example**:
```bash
ragdoll init my_knowledge_base --provider openai --embedding-model text-embedding-3-small
```

### 2. Configuration Commands

**Command Group**: `ragdoll config`

#### Subcommands:
- `ragdoll config show` - Display current configuration
- `ragdoll config set <key> <value>` - Set configuration value
- `ragdoll config get <key>` - Get specific configuration value
- `ragdoll config validate` - Validate configuration and connections
- `ragdoll config reset` - Reset to default configuration

**Options**:
- `--global` - Modify global configuration
- `--local` - Modify local project configuration
- `--format` - Output format (yaml, json, table)

### 3. Document Management Commands

**Command Group**: `ragdoll docs`

#### Subcommands:

##### Add Documents
- `ragdoll docs add <file_or_directory>` - Add single file or directory
- `ragdoll docs add-url <url>` - Add document from URL
- `ragdoll docs add-text <title>` - Add text from STDIN

**Options**:
- `--recursive` - Recursively process directories
- `--title` - Override document title
- `--type` - Specify document type
- `--metadata` - Additional metadata (JSON format)
- `--chunk-size` - Override default chunk size
- `--chunk-overlap` - Override default chunk overlap
- `--async` - Process in background
- `--watch` - Watch directory for changes

##### List and Search Documents
- `ragdoll docs list` - List all documents
- `ragdoll docs search <query>` - Search documents by content/metadata
- `ragdoll docs show <id>` - Show document details

**Options**:
- `--status` - Filter by status (pending, processing, completed, failed)
- `--type` - Filter by document type
- `--limit` - Limit number of results
- `--format` - Output format (table, json, yaml)
- `--include-content` - Include full content in output

##### Document Maintenance
- `ragdoll docs update <id>` - Update document metadata
- `ragdoll docs reprocess <id>` - Reprocess document embeddings
- `ragdoll docs delete <id>` - Delete document and embeddings
- `ragdoll docs cleanup` - Remove orphaned embeddings
- `ragdoll docs status` - Show processing status overview

### 4. Query and Answer Commands

**Primary Command**: `ragdoll query [prompt]`

**Purpose**: Process natural language queries and return AI-generated answers based on relevant document embeddings

**Input Methods**:
1. Command line argument: `ragdoll query "What is the database schema?"`
2. STDIN: `echo "How do I configure SSL?" | ragdoll query`
3. Interactive mode: `ragdoll query` (prompts for input)
4. File input: `ragdoll query --file questions.txt`

**Options**:
- `--limit` - Number of relevant chunks to retrieve (default: 10)
- `--threshold` - Similarity threshold (default: 0.7)
- `--model` - LLM model for answer generation
- `--temperature` - Response creativity (0.0-1.0)
- `--max-tokens` - Maximum response length
- `--format` - Output format (text, json, markdown)
- `--include-sources` - Show source documents in response
- `--no-generate` - Return only relevant chunks, no AI generation
- `--interactive` - Start interactive query session
- `--context-only` - Return only context, no answer generation

**Output Format**:
```
## Answer

[AI-generated response based on retrieved context]

## Sources

1. **Document Title** (similarity: 0.95)
   - Path: /path/to/document.pdf
   - Chunk: 1/15
   - Content: [relevant excerpt...]

2. **Another Document** (similarity: 0.87)
   - Path: /path/to/file.md
   - Chunk: 3/8
   - Content: [relevant excerpt...]

## Query Statistics

- Query processed in: 1.2s
- Documents searched: 1,245
- Relevant chunks found: 8
- Context length: 2,400 tokens
```

### 5. Interactive Mode

**Command**: `ragdoll interactive` or `ragdoll -i`

**Purpose**: Start an interactive REPL session for continuous querying

**Features**:
- Command history and editing
- Context persistence across queries
- Built-in help system
- Session export/import
- Real-time configuration changes

**Special Commands**:
- `/help` - Show help
- `/config <key> <value>` - Change configuration
- `/docs list` - Quick document listing
- `/stats` - Show database statistics
- `/export <file>` - Export session
- `/clear` - Clear context
- `/quit` - Exit session

### 6. Analytics and Statistics

**Command Group**: `ragdoll stats`

#### Subcommands:
- `ragdoll stats overview` - General database statistics
- `ragdoll stats usage` - Embedding usage analytics
- `ragdoll stats queries` - Query patterns and performance
- `ragdoll stats documents` - Document processing statistics

**Options**:
- `--days` - Time period for analysis (default: 30)
- `--format` - Output format (table, json, chart)
- `--export` - Export to file

### 7. Maintenance Commands

**Command Group**: `ragdoll maintenance`

#### Subcommands:
- `ragdoll maintenance backup <file>` - Backup database
- `ragdoll maintenance restore <file>` - Restore from backup
- `ragdoll maintenance optimize` - Optimize database performance
- `ragdoll maintenance vacuum` - Clean up unused space
- `ragdoll maintenance migrate` - Run pending migrations
- `ragdoll maintenance reset` - Reset entire database (with confirmation)

### 8. Server Mode

**Command**: `ragdoll server`

**Purpose**: Start HTTP API server for programmatic access

**Options**:
- `--port` - Server port (default: 3000)
- `--host` - Bind address (default: localhost)
- `--daemon` - Run as background daemon
- `--log-level` - Logging verbosity

## Implementation Architecture

### Directory Structure
```
bin/
  ragdoll                    # Main executable
lib/
  ragdoll/
    cli/
      base.rb               # Base CLI class
      init_command.rb       # Database initialization
      config_command.rb     # Configuration management
      docs_command.rb       # Document management
      query_command.rb      # Query processing
      stats_command.rb      # Analytics
      maintenance_command.rb # Maintenance operations
      server_command.rb     # Server mode
      interactive.rb        # Interactive REPL
      formatter.rb          # Output formatting
      progress_bar.rb       # Progress indicators
```

### Key Components

#### 1. CLI Framework
- **Thor**: Command structure and option parsing
- **TTY-Prompt**: Interactive prompts and menus
- **TTY-Table**: Formatted table output
- **TTY-Progressbar**: Progress indicators
- **TTY-Spinner**: Activity indicators

#### 2. Configuration System
- YAML-based configuration files
- Environment variable integration
- Hierarchical configuration (global → local → command-line)
- Configuration validation and error reporting

#### 3. Output Formatting
- Multiple output formats (text, JSON, YAML, table)
- Colorized output with fallback for non-TTY
- Progress bars for long-running operations
- Structured error messages

#### 4. Query Processing Pipeline
```
Input → Embedding Generation → Similarity Search → Context Assembly → LLM Generation → Formatted Output
```

#### 5. Error Handling
- Graceful degradation for network issues
- Detailed error messages with suggestions
- Recovery mechanisms for interrupted operations
- Comprehensive logging

## Advanced Features

### 1. Smart Context Management
- Automatic context window optimization
- Multi-turn conversation support
- Context relevance scoring
- Dynamic chunk retrieval based on query complexity

### 2. Performance Optimization
- Query result caching
- Parallel document processing
- Incremental embedding updates
- Connection pooling

### 3. Integration Features
- Shell completion (bash, zsh, fish)
- Integration with popular editors (VS Code, Vim)
- Export to various formats (PDF, Word, HTML)
- API compatibility with OpenAI format

### 4. Monitoring and Observability
- Query performance metrics
- Usage analytics dashboard
- Error rate monitoring
- Resource utilization tracking

## Configuration File Format

### Global Configuration (`~/.ragdoll/config.yml`)
```yaml
# LLM Provider Configuration
llm:
  provider: openai
  models:
    embedding: text-embedding-3-small
    generation: gpt-4
  config:
    openai:
      api_key: "${OPENAI_API_KEY}"
      organization: "${OPENAI_ORGANIZATION}"

# Database Configuration  
database:
  url: "postgresql://localhost/ragdoll_default"
  pool_size: 5

# Processing Configuration
processing:
  chunk_size: 1000
  chunk_overlap: 200
  max_concurrent_jobs: 4

# Search Configuration
search:
  similarity_threshold: 0.7
  max_results: 10
  enable_usage_tracking: true
  usage_weights:
    similarity: 1.0
    frequency: 0.7
    recency: 0.3

# CLI Configuration
cli:
  default_format: table
  colorize: true
  interactive_history: true
  progress_indicators: true

# Query Configuration
query:
  default_model: gpt-4
  default_temperature: 0.7
  max_tokens: 1000
  include_sources: true
```

## Installation and Distribution

### Installation Methods
1. **Gem Installation**: `gem install ragdoll`
2. **Bundler**: Add to Gemfile
3. **Direct Download**: Standalone executable
4. **Package Managers**: Homebrew, APT, YUM

### Dependencies
- Ruby 3.0+
- PostgreSQL with pgvector extension
- LLM provider API access
- Internet connection for initial setup

## Usage Examples

### Basic Workflow
```bash
# Initialize new database
ragdoll init my_project --provider openai

# Add documents
ragdoll docs add ./documentation/ --recursive
ragdoll docs add-url https://example.com/api-docs

# Query the knowledge base
ragdoll query "How do I authenticate with the API?"

# Interactive session
ragdoll interactive

# View statistics
ragdoll stats overview
```

### Advanced Usage
```bash
# Custom configuration
ragdoll config set search.similarity_threshold 0.8
ragdoll config set query.default_model gpt-4-turbo

# Batch processing
find ./docs -name "*.pdf" | xargs ragdoll docs add

# Complex queries with formatting
echo "Database schema questions" | ragdoll query --format json --include-sources

# Maintenance
ragdoll maintenance backup ./backup.sql
ragdoll stats usage --days 7 --format chart
```

## Testing Strategy

### Unit Tests
- Command parsing and validation
- Configuration management
- Output formatting
- Error handling

### Integration Tests  
- Full workflow testing
- Database operations
- LLM provider integration
- File processing

### User Acceptance Tests
- End-to-end scenarios
- Performance benchmarks
- Usability testing
- Cross-platform compatibility

## Documentation Plan

### User Documentation
- Installation guide
- Quick start tutorial
- Command reference
- Configuration guide
- Troubleshooting guide

### Developer Documentation
- Architecture overview
- Extension points
- API reference
- Contributing guidelines

## Future Enhancements

### Phase 2 Features
- Web interface integration
- Multi-database support
- Advanced query language
- Plugin system
- Docker container support

### Phase 3 Features
- Distributed processing
- Real-time collaboration
- Advanced analytics
- Enterprise features (SSO, audit logs)
- Cloud deployment options

## Implementation Timeline

### Phase 1 (Core CLI) - 4 weeks
- Week 1: Basic command structure and init command
- Week 2: Document management commands
- Week 3: Query processing and interactive mode
- Week 4: Configuration system and testing

### Phase 2 (Advanced Features) - 3 weeks
- Week 1: Analytics and maintenance commands
- Week 2: Server mode and API integration
- Week 3: Performance optimization and error handling

### Phase 3 (Polish and Distribution) - 2 weeks
- Week 1: Documentation and examples
- Week 2: Packaging and distribution setup

## Success Metrics

### Technical Metrics
- Query response time < 2 seconds
- 99.9% uptime for server mode
- Support for 10,000+ documents
- Sub-second similarity search

### User Experience Metrics
- Installation time < 5 minutes
- First successful query < 10 minutes from installation
- Comprehensive help system
- Intuitive command structure

This CLI utility will provide users with a powerful, easy-to-use interface for leveraging the full capabilities of the Ragdoll RAG engine, making advanced document processing and intelligent querying accessible through familiar command-line tools.