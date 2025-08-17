# frozen_string_literal: true

module Ragdoll
  class DashboardController < ApplicationController
    def index
      @stats = {
        total_documents: ::Ragdoll::Document.count,
        processed_documents: ::Ragdoll::Document.where(status: 'processed').count,
        failed_documents: ::Ragdoll::Document.where(status: 'failed').count,
        pending_documents: ::Ragdoll::Document.where(status: 'pending').count,
        total_embeddings: ::Ragdoll::Embedding.count,
        total_searches: ::Ragdoll::Search.count,
        recent_searches: ::Ragdoll::Search.order(created_at: :desc).limit(5)
      }
      
      @document_types = ::Ragdoll::Document.group(:document_type).count
      @recent_documents = ::Ragdoll::Document.order(created_at: :desc).limit(10)
      
      # Usage analytics - join through embeddable (Content) to get to documents
      @top_searched_documents = ::Ragdoll::Embedding
        .joins("JOIN ragdoll_contents ON ragdoll_contents.id = ragdoll_embeddings.embeddable_id")
        .joins("JOIN ragdoll_documents ON ragdoll_documents.id = ragdoll_contents.document_id")
        .group('ragdoll_documents.title')
        .order(Arel.sql('SUM(ragdoll_embeddings.usage_count) DESC'))
        .limit(5)
        .sum(:usage_count)
    end
    
    def analytics
      today = Date.current
      week_start = today.beginning_of_week
      month_start = today.beginning_of_month
      
      # Calculate search statistics
      all_searches = ::Ragdoll::Search.all
      searches_today = all_searches.where(created_at: today.beginning_of_day..today.end_of_day)
      searches_this_week = all_searches.where(created_at: week_start.beginning_of_day..today.end_of_day)
      searches_this_month = all_searches.where(created_at: month_start.beginning_of_day..today.end_of_day)
      
      # Comprehensive search analytics combining both pages
      @search_analytics = {
        total_searches: all_searches.count,
        unique_queries: all_searches.distinct.count(:query),
        searches_today: searches_today.count,
        searches_this_week: searches_this_week.count,
        searches_this_month: searches_this_month.count,
        average_results: all_searches.average(:results_count)&.round(1) || 0,
        average_similarity: all_searches.where.not(avg_similarity_score: nil).average(:avg_similarity_score)&.round(3) || 0,
        avg_execution_time: all_searches.average(:execution_time_ms)&.round(1) || 0,
        search_types: all_searches.group(:search_type).count
      }
      
      # Top queries (most frequent)
      @top_queries = all_searches
        .group(:query)
        .count
        .sort_by { |query, count| -count }
        .first(10)
        .to_h
      
      # Search trends by day for the last 7 days
      @search_trends = (6.days.ago.to_date..today).map do |date|
        count = all_searches.where(created_at: date.beginning_of_day..date.end_of_day).count
        [date.strftime('%m/%d'), count]
      end.to_h
      
      # Most searched documents (using embedding usage as proxy)
      @top_documents = ::Ragdoll::Embedding
        .joins("JOIN ragdoll_contents ON ragdoll_contents.id = ragdoll_embeddings.embeddable_id")
        .joins("JOIN ragdoll_documents ON ragdoll_documents.id = ragdoll_contents.document_id")
        .group('ragdoll_documents.title')
        .order(Arel.sql('SUM(ragdoll_embeddings.usage_count) DESC'))
        .limit(10)
        .sum(:usage_count)
      
      # Similarity score distribution
      similarity_scores = all_searches.where.not(avg_similarity_score: nil).pluck(:avg_similarity_score)
      @similarity_distribution = {
        "0.9-1.0" => similarity_scores.count { |s| s >= 0.9 },
        "0.8-0.9" => similarity_scores.count { |s| s >= 0.8 && s < 0.9 },
        "0.7-0.8" => similarity_scores.count { |s| s >= 0.7 && s < 0.8 },
        "0.6-0.7" => similarity_scores.count { |s| s >= 0.6 && s < 0.7 },
        "0.5-0.6" => similarity_scores.count { |s| s >= 0.5 && s < 0.6 },
        "< 0.5" => similarity_scores.count { |s| s < 0.5 }
      }
      
      # System statistics
      @system_stats = {
        total_documents: ::Ragdoll::Document.count,
        processed_documents: ::Ragdoll::Document.where(status: 'processed').count,
        failed_documents: ::Ragdoll::Document.where(status: 'failed').count,
        pending_documents: ::Ragdoll::Document.where(status: 'pending').count,
        total_embeddings: ::Ragdoll::Embedding.count,
        total_embedding_usage: ::Ragdoll::Embedding.sum(:usage_count)
      }
    end
  end
end