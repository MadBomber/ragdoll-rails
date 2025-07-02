# frozen_string_literal: true

module Ragdoll
  class Embedding < ApplicationRecord
    self.table_name = 'ragdoll_embeddings'
    
    # Associations
    belongs_to :ragdoll_document, class_name: 'Ragdoll::Document', foreign_key: 'document_id'
    
    # Validations
    validates :content, presence: true
    validates :embedding, presence: true
    validates :usage_count, numericality: { greater_than_or_equal_to: 0 }
    
    # Scopes
    scope :most_used, -> { order(usage_count: :desc) }
    scope :recently_used, -> { order(returned_at: :desc) }
    scope :never_used, -> { where(returned_at: nil) }
    scope :frequently_used, ->(threshold = 5) { where('usage_count >= ?', threshold) }
    scope :used_since, ->(date) { where('returned_at >= ?', date) }
    
    # Combined scopes for ranking
    scope :by_usage_and_recency, -> {
      order('usage_count DESC, returned_at DESC NULLS LAST')
    }
    scope :by_recency_and_usage, -> {
      order('returned_at DESC NULLS LAST, usage_count DESC')
    }
    
    # Search configuration
    searchkick text_middle: [:content, :metadata_content, :metadata_propositions]

    def search_data
      {
        content: content,
        metadata_content: metadata&.dig('content'),
        metadata_propositions: metadata&.dig('propositions'),
        model_name: model_name,
        embedding_type: embedding_type,
        usage_count: usage_count
      }
    end

    # Usage tracking methods
    def record_usage!
      increment!(:usage_count)
      touch(:returned_at)
    end
    
    def mark_as_returned!
      record_usage!
    end
    
    # Usage statistics
    def never_used?
      returned_at.nil?
    end
    
    def used_recently?(within: 24.hours)
      returned_at && returned_at > within.ago
    end
    
    def frequently_used?(threshold: 5)
      usage_count >= threshold
    end
    
    def last_used_days_ago
      return nil if returned_at.nil?
      ((Time.current - returned_at) / 1.day).round
    end
    
    # Calculate usage score for ranking
    def usage_score(recency_weight: 0.3, frequency_weight: 0.7)
      return 0.0 if never_used?
      
      # Normalize usage count (logarithmic scaling)
      frequency_score = Math.log(usage_count + 1) / Math.log(100) # Scale to ~0-1
      frequency_score = [frequency_score, 1.0].min
      
      # Recency score (decay over time)
      days_since_use = last_used_days_ago || Float::INFINITY
      recency_score = Math.exp(-days_since_use / 30.0) # 30-day half-life
      
      (frequency_weight * frequency_score) + (recency_weight * recency_score)
    end
    
    # Class methods for analytics
    def self.usage_analytics
      {
        total_embeddings: count,
        used_embeddings: where.not(returned_at: nil).count,
        never_used: where(returned_at: nil).count,
        average_usage: average(:usage_count)&.round(2) || 0,
        most_used_count: maximum(:usage_count) || 0,
        recently_used_count: where('returned_at > ?', 7.days.ago).count,
        usage_distribution: group('CASE 
          WHEN usage_count = 0 THEN \'unused\' 
          WHEN usage_count BETWEEN 1 AND 5 THEN \'low\' 
          WHEN usage_count BETWEEN 6 AND 20 THEN \'medium\' 
          ELSE \'high\' END').count
      }
    end
    
    def self.top_used(limit: 10)
      most_used.limit(limit)
    end
    
    def self.trending(days: 7, limit: 10)
      where('returned_at > ?', days.days.ago)
        .group(:id)
        .order('COUNT(*) DESC')
        .limit(limit)
    end
    
    # Batch usage recording for performance
    def self.record_batch_usage(embedding_ids)
      return if embedding_ids.empty?
      
      # Use raw SQL for better performance on large batches
      connection.execute(<<~SQL)
        UPDATE ragdoll_embeddings 
        SET usage_count = usage_count + 1, 
            returned_at = NOW(), 
            updated_at = NOW()
        WHERE id IN (#{embedding_ids.map(&:to_i).join(',')})
      SQL
    end
    
    # Vector similarity (assuming pgvector)
    def self.similar_to(vector, limit: 10)
      # This would be implemented based on the vector similarity search
      # The actual implementation depends on your vector search setup
    end
  end
end
