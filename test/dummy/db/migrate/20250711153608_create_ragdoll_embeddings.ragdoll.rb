# This migration comes from ragdoll (originally 20250219123456)
# Creates the embeddings table that stores vector representations of document chunks.
# This is the core table for semantic search functionality in the RAG system.
class CreateRagdollEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :ragdoll_embeddings, comment: 'Stores vector embeddings of document chunks for semantic search. Each row represents a chunk of text from a document converted to a high-dimensional vector for AI similarity matching.' do |t|
      # Foreign key relationship to parent document
      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents }, comment: 'Foreign key reference to the parent document. Each embedding belongs to exactly one document and represents a chunk of that document\'s content.'
      
      # The actual text content that was embedded
      t.text :content, null: false, comment: 'The actual text content of this chunk that was converted to an embedding vector. This is the searchable text that users will find when performing semantic search queries.'
      
      # Vector data storage - currently JSON format for compatibility
      t.text :embedding, comment: 'JSON-serialized vector embedding of the content. Contains the high-dimensional numerical representation (typically 1536 dimensions for OpenAI models) that enables semantic similarity calculations. Stored as text/JSON for database compatibility.'
      
      # Model identification and metadata
      t.string :model_name, comment: 'Name/identifier of the AI model used to generate this embedding (e.g., "text-embedding-ada-002", "text-embedding-3-small"). Critical for ensuring compatibility when performing similarity searches.'
      t.integer :token_count, comment: 'Number of tokens (word pieces) in the original content that was embedded. Used for cost calculation and monitoring model usage limits. One token ≈ 0.75 words for English text.'
      
      # Chunk organization within document
      t.integer :chunk_index, comment: 'Sequential position of this chunk within the parent document (0-based). Used for reconstructing document order and managing chunk relationships during search result presentation.'
      
      # Flexible metadata storage for embedding-specific information
      t.jsonb :metadata, default: {}, comment: 'Flexible JSON storage for embedding-specific metadata such as processing parameters, quality scores, or custom annotations. Indexed with GIN for efficient querying of nested properties.'
      
      # Type classification for different embedding strategies
      t.string :embedding_type, default: 'text', comment: 'Classification of embedding type (e.g., "text", "code", "summary"). Allows for different embedding strategies and models for different content types within the same system.'

      # Standard Rails timestamps
      t.timestamps comment: 'Standard Rails created_at and updated_at timestamps for tracking when embedding records are created and modified. Important for cache invalidation and processing monitoring.'
    end

    # Indexes for performance optimization
    add_index :ragdoll_embeddings, :document_id, comment: 'Foreign key index for efficient queries of all embeddings belonging to a specific document. Critical for document detail views and batch operations.' unless index_exists?(:ragdoll_embeddings, :document_id)
    add_index :ragdoll_embeddings, :chunk_index, comment: 'Index for ordering chunks within a document and finding specific chunks by position. Used for reconstructing document sections and navigating search results.' unless index_exists?(:ragdoll_embeddings, :chunk_index)
    add_index :ragdoll_embeddings, :embedding_type, comment: 'Index for filtering embeddings by type, enabling type-specific search strategies and processing workflows.' unless index_exists?(:ragdoll_embeddings, :embedding_type)
    add_index :ragdoll_embeddings, :metadata, using: :gin, comment: 'GIN index on JSONB metadata field enables efficient queries on nested JSON properties and complex filtering on embedding metadata.' unless index_exists?(:ragdoll_embeddings, :metadata)
  end
end