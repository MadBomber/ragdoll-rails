# Updates the embeddings table to support variable vector dimensions and optimize queries.
# Originally intended to convert to pgvector format but maintains text compatibility for broader database support.
class UpdateEmbeddingsVectorColumn < ActiveRecord::Migration[8.0]
  def up
    # Remove the limit constraint to allow variable length vectors
    # Different AI models produce embeddings with different dimensions (e.g., 1536 for OpenAI, 384 for some sentence transformers)
    change_column :ragdoll_embeddings, :embedding, :vector, limit: nil, comment: 'High-dimensional vector representation with variable dimensions removed to support multiple embedding models. Allows for mixing different model outputs while maintaining pgvector compatibility.'
    
    # Add column to track embedding vector dimensions for validation and compatibility
    add_column :ragdoll_embeddings, :embedding_dimensions, :integer, comment: 'Number of dimensions in the embedding vector (e.g., 1536 for OpenAI text-embedding-3-small). Critical for ensuring embedding compatibility during similarity searches and preventing dimension mismatches.'
    
    # Update existing records to set their dimensions based on actual vector data
    # This ensures data integrity for existing embeddings
    execute <<~SQL
      UPDATE ragdoll_embeddings 
      SET embedding_dimensions = array_length(embedding::real[], 1) 
      WHERE embedding IS NOT NULL
    SQL
    
    # Add index on embedding_dimensions for efficient filtering by vector size
    # Used when searching embeddings to ensure only compatible vectors are compared
    add_index :ragdoll_embeddings, :embedding_dimensions, comment: 'Index for filtering embeddings by vector dimension size. Essential for ensuring only compatible embeddings are compared during similarity searches and avoiding dimension mismatch errors.'
    
    # Add composite index on model_name and embedding_dimensions for optimized similarity searches
    # This combination is frequently queried together when finding similar embeddings
    add_index :ragdoll_embeddings, [:model_name, :embedding_dimensions], 
              name: 'index_ragdoll_embeddings_on_model_and_dimensions',
              comment: 'Composite index on model name and vector dimensions. Optimizes the common query pattern of finding embeddings from the same model with matching dimensions for similarity calculations.'
  end

  def down
    # Remove the new columns and indexes in reverse order
    remove_index :ragdoll_embeddings, :embedding_dimensions
    remove_index :ragdoll_embeddings, name: 'index_ragdoll_embeddings_on_model_and_dimensions'
    remove_column :ragdoll_embeddings, :embedding_dimensions
    
    # Note: The original plan was to restore vector type, but this would fail with mixed dimensions
    # Restore the original limit (this will fail if there are vectors with different dimensions)
    change_column :ragdoll_embeddings, :embedding, :vector, limit: 1536
  end
end