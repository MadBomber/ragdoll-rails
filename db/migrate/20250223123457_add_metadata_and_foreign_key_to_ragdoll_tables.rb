class CreateRagdollSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :ragdoll_searches do |t|
      t.text :query, null: false
      t.vector :query_embedding, limit: 1536
      t.string :search_type, default: 'semantic'
      t.jsonb :filters, default: {}
      t.jsonb :results, default: {}
      t.integer :result_count, default: 0
      t.float :search_time
      t.string :model_name

      t.timestamps
    end

    add_index :ragdoll_searches, :search_type
    add_index :ragdoll_searches, :query_embedding, using: :hnsw, opclass: :vector_cosine_ops
    add_index :ragdoll_searches, :created_at
  end
end
