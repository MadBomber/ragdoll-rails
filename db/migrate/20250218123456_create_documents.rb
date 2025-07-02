class CreateRagdollDocuments < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    enable_extension 'fuzzystrmatch' unless extension_enabled?('fuzzystrmatch')
    enable_extension 'vector' unless extension_enabled?('vector')

    create_table :ragdoll_documents do |t|
      t.string :location, null: false
      t.text :content
      t.text :summary
      t.string :document_type
      t.string :title
      t.string :source_type
      t.integer :chunk_size
      t.integer :chunk_overlap
      t.jsonb :metadata, default: {}
      t.datetime :processing_started_at
      t.datetime :processing_finished_at
      t.string :status, default: 'pending'

      t.timestamps
    end

    add_index :ragdoll_documents, :location, unique: true
    add_index :ragdoll_documents, :document_type
    add_index :ragdoll_documents, :status
    add_index :ragdoll_documents, :metadata, using: :gin
    add_index :ragdoll_documents, :processing_started_at
  end
end
