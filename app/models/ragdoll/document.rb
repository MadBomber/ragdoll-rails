# This file defines the Rails-specific Document model for the Ragdoll Rails engine.
# This model is separate from Ragdoll::Core::Models::Document to avoid conflicts.

# frozen_string_literal: true

module Ragdoll
  module Rails
    class Document < ApplicationRecord
      self.table_name = 'ragdoll_documents'
    
    # Associations
    has_many :ragdoll_embeddings, class_name: 'Ragdoll::Rails::Embedding', foreign_key: 'document_id', dependent: :destroy
    has_one_attached :file if respond_to?(:has_one_attached)
    
    # Validations
    validates :location, presence: true, uniqueness: true
    validates :status, inclusion: { in: %w[pending processing completed failed] }
    validates :chunk_size, numericality: { greater_than: 0 }, allow_nil: true
    validates :chunk_overlap, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    
    # Scopes
    scope :completed, -> { where(status: 'completed') }
    scope :failed, -> { where(status: 'failed') }
    scope :processing, -> { where(status: 'processing') }
    scope :pending, -> { where(status: 'pending') }
    scope :by_type, ->(type) { where(document_type: type) }
    scope :with_summaries, -> { where.not(summary: nil) }
    scope :needs_summary, -> { where(summary: nil).completed }
    
    # Search configuration
    searchkick text_middle: [:title, :summary, :content, :metadata_name, :metadata_summary] if defined?(Searchkick)

    def search_data
      return {} unless defined?(Searchkick)
      
      {
        title: title,
        summary: summary,
        content: content,
        metadata_name: metadata&.dig('name'),
        metadata_summary: metadata&.dig('summary'),
        document_type: document_type,
        status: status
      }
    end
    
    # Summary-related methods
    def has_summary?
      summary.present?
    end
    
    def summary_stale?
      return false unless has_summary?
      return true unless summary_generated_at
      
      # Consider summary stale if document was updated after summary generation
      updated_at > summary_generated_at
    end
    
    def needs_summary?
      return false unless content.present?
      # Business logic should be handled by ragdoll gem
      # TODO: Delegate to Ragdoll.needs_summary?(content, summary, summary_generated_at)
      
      !has_summary? || summary_stale?
    end
    
    def summary_word_count
      return 0 unless summary.present?
      summary.split.length
    end
    
    def regenerate_summary!
      # Business logic for summary generation should be handled by the ragdoll gem
      # This is a placeholder that delegates to the core ragdoll functionality
      return false unless content.present?
      
      # TODO: Delegate to Ragdoll gem's summarization functionality
      # summarization_result = Ragdoll.generate_summary(content, options)
      # Update the model with the result
      
      Rails.logger.warn "Summary regeneration not implemented - should delegate to ragdoll gem"
      false
    end
    
    # Processing status helpers
    def completed?
      status == 'completed'
    end
    
    def failed?
      status == 'failed'
    end
    
    def processing?
      status == 'processing'
    end
    
    def pending?
      status == 'pending'
    end
    
    # Content helpers
    def word_count
      return 0 unless content.present?
      content.split.length
    end
    
    def character_count
      return 0 unless content.present?
      content.length
    end
    
    def processing_duration
      return nil unless processing_started_at && processing_finished_at
      processing_finished_at - processing_started_at
    end
    end
  end
end
