# This migration comes from ragdoll (originally 20250226123456)
# Adds usage tracking functionality to embeddings for intelligent ranking and caching.
# Enables the system to learn which embeddings are most valuable and prioritize them in search results.
class AddUsageTrackingToRagdollEmbeddings < ActiveRecord::Migration[8.0]
  def change
    # Usage frequency tracking
    add_column :ragdoll_embeddings, :usage_count, :integer, default: 0, null: false, comment: 'Number of times this embedding has been returned in search results. Incremented each time the embedding appears in search results. Used for frequency-based ranking to surface more relevant content.' unless column_exists?(:ragdoll_embeddings, :usage_count)
    
    # Recency tracking for temporal relevance
    add_column :ragdoll_embeddings, :returned_at, :timestamp, comment: 'Timestamp of the most recent time this embedding was returned in search results. Used for recency-based ranking algorithms and cache warming strategies. NULL indicates never used.' unless column_exists?(:ragdoll_embeddings, :returned_at)
    
    # Performance indexes for usage-based ranking queries
    add_index :ragdoll_embeddings, :usage_count, name: 'index_ragdoll_embeddings_on_usage_count', comment: 'Index for sorting embeddings by usage frequency. Critical for popularity-based ranking algorithms and identifying most/least used content.' unless index_exists?(:ragdoll_embeddings, :usage_count)
    add_index :ragdoll_embeddings, :returned_at, name: 'index_ragdoll_embeddings_on_returned_at', comment: 'Index for sorting embeddings by recency of use. Enables temporal ranking algorithms and cache warming strategies based on recent usage patterns.' unless index_exists?(:ragdoll_embeddings, :returned_at)
    
    # Composite index for advanced ranking algorithms that combine frequency and recency
    unless index_exists?(:ragdoll_embeddings, [:usage_count, :returned_at])
      add_index :ragdoll_embeddings, [:usage_count, :returned_at], 
                name: 'index_ragdoll_embeddings_on_usage_and_recency',
                comment: 'Composite index for complex ranking algorithms that combine usage frequency with recency. Optimizes queries that balance popular content with recently accessed content for intelligent search result ranking.'
    end
    
    # Data migration to ensure existing records have proper default values
    # Usage count defaults to 0, returned_at remains null until first usage
    reversible do |dir|
      dir.up do
        execute "UPDATE ragdoll_embeddings SET usage_count = 0 WHERE usage_count IS NULL"
      end
    end
  end
end