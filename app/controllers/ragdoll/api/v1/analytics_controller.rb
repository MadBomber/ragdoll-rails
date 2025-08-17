# frozen_string_literal: true

module Ragdoll
  module Api
    module V1
      class AnalyticsController < BaseController
        def index
          analytics_data = {
            document_stats: {
              total_documents: ::Ragdoll::Document.count,
              processed_documents: ::Ragdoll::Document.where(status: 'processed').count,
              failed_documents: ::Ragdoll::Document.where(status: 'failed').count,
              pending_documents: ::Ragdoll::Document.where(status: 'pending').count,
              total_embeddings: ::Ragdoll::Embedding.count
            },
            
            search_stats: {
              total_searches: ::Ragdoll::Search.count,
              unique_queries: ::Ragdoll::Search.distinct.count(:query),
              searches_today: ::Ragdoll::Search.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
              searches_this_week: ::Ragdoll::Search.where(created_at: Date.current.beginning_of_week..Date.current.end_of_day).count,
              average_similarity: ::Ragdoll::Search.where.not(avg_similarity_score: nil).average(:avg_similarity_score)&.round(3) || 0
            },
            
            popular_queries: ::Ragdoll::Search.group(:query).count.sort_by { |query, count| -count }.first(10).to_h,
            
            document_types: ::Ragdoll::Document.group(:document_type).count,
            
            top_documents: ::Ragdoll::Embedding
              .joins("JOIN ragdoll_contents ON ragdoll_contents.id = ragdoll_embeddings.embeddable_id")
              .joins("JOIN ragdoll_documents ON ragdoll_documents.id = ragdoll_contents.document_id")
              .group('ragdoll_documents.title')
              .order('SUM(ragdoll_embeddings.usage_count) DESC')
              .limit(10)
              .sum(:usage_count),
            
            search_trends: (6.days.ago.to_date..Date.current).map do |date|
              count = ::Ragdoll::Search.where(created_at: date.beginning_of_day..date.end_of_day).count
              [date.strftime('%m/%d'), count]
            end.to_h,
            
            embedding_usage: ::Ragdoll::Embedding
              .joins("JOIN ragdoll_contents ON ragdoll_contents.id = ragdoll_embeddings.embeddable_id")
              .joins("JOIN ragdoll_documents ON ragdoll_documents.id = ragdoll_contents.document_id")
              .group('ragdoll_documents.title')
              .order('SUM(ragdoll_embeddings.usage_count) DESC')
              .limit(10)
              .sum(:usage_count),
            
            similarity_distribution: build_similarity_distribution
          }
          
          render json: analytics_data
        end
        
        private
        
        def build_similarity_distribution
          similarity_scores = ::Ragdoll::Search.where.not(avg_similarity_score: nil).pluck(:avg_similarity_score)
          {
            "0.9-1.0" => similarity_scores.count { |s| s >= 0.9 },
            "0.8-0.9" => similarity_scores.count { |s| s >= 0.8 && s < 0.9 },
            "0.7-0.8" => similarity_scores.count { |s| s >= 0.7 && s < 0.8 },
            "0.6-0.7" => similarity_scores.count { |s| s >= 0.6 && s < 0.7 },
            "0.5-0.6" => similarity_scores.count { |s| s >= 0.5 && s < 0.6 },
            "< 0.5" => similarity_scores.count { |s| s < 0.5 }
          }
        end
      end
    end
  end
end