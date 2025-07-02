class AddUsageTrackingToRagdollEmbeddings < ActiveRecord::Migration[8.0]
  def change
    add_column :ragdoll_embeddings, :usage_count, :integer, default: 0, null: false
    add_column :ragdoll_embeddings, :returned_at, :timestamp
    
    # Add indexes for performance when sorting by usage metrics
    add_index :ragdoll_embeddings, :usage_count, name: 'index_ragdoll_embeddings_on_usage_count'
    add_index :ragdoll_embeddings, :returned_at, name: 'index_ragdoll_embeddings_on_returned_at'
    
    # Composite index for combined usage and recency sorting
    add_index :ragdoll_embeddings, [:usage_count, :returned_at], 
              name: 'index_ragdoll_embeddings_on_usage_and_recency'
    
    # Update existing records to have a default usage_count of 0
    # returned_at will remain null until first usage
    reversible do |dir|
      dir.up do
        execute "UPDATE ragdoll_embeddings SET usage_count = 0 WHERE usage_count IS NULL"
      end
    end
  end
end