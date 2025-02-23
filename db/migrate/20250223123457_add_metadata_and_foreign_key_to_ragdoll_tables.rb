class AddMetadataAndForeignKeyToRagdollTables < ActiveRecord::Migration[7.0]
  def change
    add_column :ragdoll_documents, :metadata, :jsonb, default: {}
    add_column :ragdoll_embeddings, :metadata, :jsonb, default: {}

    add_foreign_key :ragdoll_embeddings, :ragdoll_documents, column: :document_id
  end
end
