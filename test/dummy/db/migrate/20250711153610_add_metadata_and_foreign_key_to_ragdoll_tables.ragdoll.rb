# This migration comes from ragdoll (originally 20250223123457)
# Creates the searches table for tracking user search queries and analytics.
# This table enables search analytics, caching, and performance monitoring for the RAG system.
class AddMetadataAndForeignKeyToRagdollTables < ActiveRecord::Migration[8.0]
  def change
    create_table :ragdoll_searches, comment: 'Tracks user search queries and results for analytics and performance monitoring. Each row represents a search performed by a user, storing both the query and metadata about results.' do |t|
      # User's original search query
      t.text :query, null: false, comment: 'The original search query text entered by the user. Required field that captures the exact search terms for analytics, popular queries tracking, and search result caching.'
      
      # Embedding of the search query for similarity calculations
      t.text :query_embedding, comment: 'JSON-serialized vector embedding of the search query. Generated using the same model as document embeddings to enable semantic similarity calculations. Stored as text for database compatibility.'
      
      # Search classification and method
      t.string :search_type, default: 'semantic', comment: 'Type of search performed (e.g., "semantic", "keyword", "hybrid"). Allows for different search strategies and helps analyze which search methods are most effective for users.'
      
      # Search parameters and constraints
      t.jsonb :filters, default: {}, comment: 'JSON object containing search filters applied (e.g., document_type, date_range, status). Used for analyzing how users refine searches and for recreating search contexts.'
      
      # Search results metadata  
      t.jsonb :results, default: {}, comment: 'JSON object containing search result metadata such as result IDs, similarity scores, and ranking information. Enables search result caching and detailed analytics on result quality.'
      t.integer :result_count, default: 0, comment: 'Number of results returned by this search. Used for analytics on search effectiveness and identifying queries that return too few or too many results.'
      
      # Performance tracking
      t.float :search_time, comment: 'Time in seconds taken to execute this search query. Critical for performance monitoring, identifying slow queries, and optimizing search algorithms.'
      
      # Model identification for compatibility
      t.string :model_name, comment: 'Name of the AI model used to generate the query embedding (e.g., "text-embedding-3-small"). Ensures search compatibility and enables analytics by model performance.'

      # Standard Rails timestamps
      t.timestamps comment: 'Standard Rails created_at and updated_at timestamps. The created_at timestamp is particularly important for search analytics and identifying search patterns over time.'
    end

    # Indexes for analytics and performance
    add_index :ragdoll_searches, :search_type, comment: 'Index for filtering searches by type, used in analytics dashboards to compare effectiveness of different search strategies.' unless index_exists?(:ragdoll_searches, :search_type)
    add_index :ragdoll_searches, :created_at, comment: 'Index for time-based queries and analytics. Essential for generating search trend reports, popular queries over time, and performance monitoring.' unless index_exists?(:ragdoll_searches, :created_at)
  end
end
