# This migration comes from ragdoll (originally 20250225123456)
# Adds summary metadata tracking to documents table for AI-generated summaries.
# Enhances the existing summary field with provenance and timing information.
class AddSummaryToRagdollDocuments < ActiveRecord::Migration[8.0]
  def change
    # Summary field already exists from initial migration, just add metadata fields for tracking
    
    # Timestamp tracking for summary generation
    add_column :ragdoll_documents, :summary_generated_at, :timestamp, comment: 'Timestamp when the AI-generated summary was created. Used for cache invalidation, determining summary freshness, and analytics on summary generation performance.' unless column_exists?(:ragdoll_documents, :summary_generated_at)
    
    # Model identification for summary provenance
    add_column :ragdoll_documents, :summary_model, :string, comment: 'Name/identifier of the AI model used to generate the summary (e.g., "gpt-3.5-turbo", "claude-3-haiku"). Critical for tracking summary quality, cost analysis, and ensuring consistency in summary style.' unless column_exists?(:ragdoll_documents, :summary_model)
    
    # Indexes for summary metadata queries and analytics
    add_index :ragdoll_documents, :summary_generated_at, comment: 'Index for filtering and sorting documents by summary generation time. Used for cache invalidation queries and identifying documents with stale summaries that need regeneration.' unless index_exists?(:ragdoll_documents, :summary_generated_at)
    add_index :ragdoll_documents, :summary_model, comment: 'Index for filtering documents by the AI model used for summarization. Enables analytics on summary quality by model and batch re-summarization with newer models.' unless index_exists?(:ragdoll_documents, :summary_model)
  end
end