class AddSummaryMetadataToRagdollDocuments < ActiveRecord::Migration[8.0]
  def change
    # Summary field already exists, just add metadata fields
    add_column :ragdoll_documents, :summary_generated_at, :timestamp
    add_column :ragdoll_documents, :summary_model, :string
    
    # Add index for searching by summary metadata
    add_index :ragdoll_documents, :summary_generated_at
    add_index :ragdoll_documents, :summary_model
  end
end