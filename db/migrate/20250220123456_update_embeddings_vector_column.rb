class UpdateEmbeddingsVectorColumn < ActiveRecord::Migration[8.0]
  def up
    # Remove the limit constraint to allow variable length vectors
    change_column :ragdoll_embeddings, :embedding, :vector, limit: nil
    
    # Add column to track embedding dimensions
    add_column :ragdoll_embeddings, :embedding_dimensions, :integer
    
    # Update existing records to set their dimensions
    execute <<~SQL
      UPDATE ragdoll_embeddings 
      SET embedding_dimensions = array_length(embedding::real[], 1) 
      WHERE embedding IS NOT NULL
    SQL
    
    # Add index on embedding_dimensions for faster filtering
    add_index :ragdoll_embeddings, :embedding_dimensions
    
    # Add index on model_name and embedding_dimensions combination
    add_index :ragdoll_embeddings, [:model_name, :embedding_dimensions], 
              name: 'index_ragdoll_embeddings_on_model_and_dimensions'
  end

  def down
    # Remove the new columns and indexes
    remove_index :ragdoll_embeddings, :embedding_dimensions
    remove_index :ragdoll_embeddings, name: 'index_ragdoll_embeddings_on_model_and_dimensions'
    remove_column :ragdoll_embeddings, :embedding_dimensions
    
    # Restore the original limit (this will fail if there are vectors with different dimensions)
    change_column :ragdoll_embeddings, :embedding, :vector, limit: 1536
  end
end