# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding Ragdoll Demo Data..."

# Create sample documents to demonstrate the engine capabilities
sample_documents = [
  {
    title: "Introduction to Machine Learning",
    content: <<~TEXT
      Machine learning is a subset of artificial intelligence that focuses on the development of algorithms and statistical models that enable computers to improve their performance on a specific task through experience.

      The field encompasses various approaches including:
      - Supervised learning: Training models with labeled data
      - Unsupervised learning: Finding patterns in unlabeled data
      - Reinforcement learning: Learning through interaction with an environment

      Key concepts include:
      - Feature engineering: Selecting and transforming input variables
      - Model selection: Choosing appropriate algorithms for specific tasks
      - Cross-validation: Evaluating model performance on unseen data
      - Overfitting and underfitting: Balancing model complexity and generalization

      Popular algorithms include linear regression, decision trees, random forests, support vector machines, and neural networks.
    TEXT
  },
  {
    title: "Ruby on Rails Best Practices",
    content: <<~TEXT
      Ruby on Rails is a web application framework written in Ruby that follows the model-view-controller (MVC) architectural pattern.

      Key principles and best practices:
      - Convention over Configuration: Rails provides sensible defaults
      - Don't Repeat Yourself (DRY): Avoid duplicating code
      - Fat Models, Skinny Controllers: Keep business logic in models
      - RESTful design: Use standard HTTP methods and resource-oriented URLs

      Database best practices:
      - Use migrations for database schema changes
      - Add proper indexes for query performance
      - Use database constraints for data integrity
      - Implement proper associations between models

      Testing approaches:
      - Unit tests for models and helpers
      - Integration tests for controllers
      - Feature tests for user workflows
      - Use factories instead of fixtures for test data

      Performance optimization:
      - Use eager loading to avoid N+1 queries
      - Implement caching strategies
      - Optimize database queries
      - Use background jobs for long-running tasks
    TEXT
  },
  {
    title: "Vector Embeddings and Semantic Search",
    content: <<~TEXT
      Vector embeddings are dense numerical representations of words, phrases, or documents that capture semantic meaning in a high-dimensional space.

      How embeddings work:
      - Text is converted into numerical vectors
      - Similar concepts are positioned close together in vector space
      - Cosine similarity measures the angle between vectors
      - Lower angles indicate higher semantic similarity

      Applications:
      - Semantic search: Finding documents by meaning rather than keywords
      - Recommendation systems: Suggesting similar items
      - Natural language processing: Understanding context and relationships
      - Information retrieval: Improving search relevance

      Popular embedding models:
      - OpenAI's text-embedding-3-small and text-embedding-3-large
      - Sentence-BERT for sentence-level embeddings
      - Universal Sentence Encoder by Google
      - Custom domain-specific embeddings

      Implementation considerations:
      - Choosing appropriate embedding dimensions
      - Handling out-of-vocabulary words
      - Updating embeddings for new data
      - Balancing accuracy and computational cost
    TEXT
  },
  {
    title: "Database Optimization Strategies",
    content: <<~TEXT
      Database optimization is crucial for application performance and scalability.

      Indexing strategies:
      - B-tree indexes for equality and range queries
      - Hash indexes for exact matches
      - Composite indexes for multi-column queries
      - Partial indexes for filtered data

      Query optimization:
      - Use EXPLAIN to analyze query execution plans
      - Avoid SELECT * in production code
      - Use appropriate JOIN types
      - Implement proper WHERE clause filtering

      Database design principles:
      - Normalize to eliminate data redundancy
      - Denormalize for read performance when appropriate
      - Use appropriate data types
      - Implement proper constraints

      Performance monitoring:
      - Track slow queries
      - Monitor connection pool usage
      - Analyze query frequency and patterns
      - Set up alerts for performance degradation

      Scaling approaches:
      - Read replicas for read-heavy workloads
      - Sharding for horizontal scaling
      - Connection pooling for resource management
      - Caching strategies to reduce database load
    TEXT
  },
  {
    title: "API Design and Documentation",
    content: <<~TEXT
      Well-designed APIs are essential for modern web applications and microservices architectures.

      RESTful API principles:
      - Use HTTP methods appropriately (GET, POST, PUT, DELETE)
      - Implement proper status codes
      - Design resource-oriented URLs
      - Use consistent naming conventions

      Authentication and authorization:
      - Implement proper authentication mechanisms
      - Use JWT tokens for stateless authentication
      - Implement role-based access control
      - Secure sensitive endpoints

      Documentation best practices:
      - Use OpenAPI/Swagger specifications
      - Provide clear examples and use cases
      - Document error responses
      - Keep documentation up-to-date with code changes

      Versioning strategies:
      - URL versioning (e.g., /v1/users)
      - Header versioning
      - Parameter versioning
      - Plan for backward compatibility

      Performance considerations:
      - Implement pagination for large datasets
      - Use appropriate caching headers
      - Optimize JSON serialization
      - Implement rate limiting
    TEXT
  }
]

sample_documents.each do |doc_data|
  puts "Creating document: #{doc_data[:title]}"
  
  location = "seed_document_#{doc_data[:title].parameterize}"
  
  # Create or find document record
  document = Ragdoll::Document.find_or_create_by(location: location) do |doc|
    doc.title = doc_data[:title]
    doc.content = doc_data[:content]
    doc.document_type = 'text'
    doc.status = 'completed'
    doc.metadata = {
      created_by: 'seed_script',
      category: 'technical_documentation',
      language: 'en',
      content_length: doc_data[:content].length,
      chunk_count: 0
    }
  end
  
  # Create sample embeddings (with dummy vectors for demo purposes)
  # In a real application, these would be generated by the embedding service
  chunks = doc_data[:content].scan(/.{1,500}(?:\s|$)/m).map(&:strip).reject(&:empty?)
  
  # Skip if embeddings already exist
  next if document.ragdoll_embeddings.any?
  
  chunks.each_with_index do |chunk, index|
    # Generate a dummy vector (in production, this would come from the embedding service)
    dummy_vector = Array.new(1536) { rand(-1.0..1.0) }
    
    Ragdoll::Embedding.create!(
      document: document,
      content: chunk,
      chunk_index: index,
      embedding: dummy_vector.to_json,
      model_name: 'text-embedding-3-small',
      usage_count: rand(0..10),
      returned_at: rand(30.days.ago..Time.current),
      metadata: {
        dimensions: 1536,
        provider: 'openai'
      }
    )
  end
  
  # Update document metadata with chunk count
  document.metadata['chunk_count'] = chunks.count
  document.save!
end

# Create some sample searches to demonstrate analytics
sample_queries = [
  "machine learning algorithms",
  "rails best practices",
  "database optimization",
  "vector embeddings",
  "API design",
  "semantic search",
  "query performance",
  "ruby on rails",
  "artificial intelligence",
  "database indexing"
]

puts "Creating sample search data..."
sample_queries.each do |query|
  # Generate a dummy query embedding vector
  query_vector = Array.new(1536) { rand(-1.0..1.0) }
  
  Ragdoll::Search.create!(
    query: query,
    query_embedding: query_vector.to_json,
    search_type: ['semantic', 'keyword', 'hybrid'].sample,
    result_count: rand(0..10),
    search_time: rand(0.1..2.0).round(3),
    model_name: 'text-embedding-3-small',
    filters: {},
    results: { result_ids: [], scores: [] },
    created_at: rand(30.days.ago..Time.current)
  )
end

puts "✅ Seeding completed!"
puts "📊 Created #{Ragdoll::Document.count} documents"
puts "🔍 Created #{Ragdoll::Embedding.count} embeddings"
puts "📈 Created #{Ragdoll::Search.count} search records"
puts ""
puts "🚀 Your Ragdoll Engine demo is ready!"
puts "Start the server with: rails server"
puts "Then visit: http://localhost:3000"
