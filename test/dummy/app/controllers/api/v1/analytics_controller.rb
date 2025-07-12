class Api::V1::AnalyticsController < Api::V1::BaseController
  def index
    analytics_data = {
      document_stats: {
        total_documents: Ragdoll::Document.count,
        processed_documents: Ragdoll::Document.where(status: 'processed').count,
        failed_documents: Ragdoll::Document.where(status: 'failed').count,
        pending_documents: Ragdoll::Document.where(status: 'pending').count,
        total_embeddings: Ragdoll::Embedding.count
      },
      
      search_stats: {
        total_searches: Ragdoll::Search.count,
        unique_queries: Ragdoll::Search.distinct.count(:query),
        searches_today: Ragdoll::Search.where('created_at > ?', 1.day.ago).count,
        searches_this_week: Ragdoll::Search.where('created_at > ?', 1.week.ago).count,
        average_similarity: Ragdoll::Search.average(:similarity_score)&.round(3) || 0
      },
      
      popular_queries: Ragdoll::Search
        .group(:query)
        .order('COUNT(*) DESC')
        .limit(10)
        .count,
      
      document_types: Ragdoll::Document.group(:document_type).count,
      
      top_documents: Ragdoll::Search
        .joins(:document)
        .group('ragdoll_documents.title')
        .order('COUNT(*) DESC')
        .limit(10)
        .count,
      
      search_trends: Ragdoll::Search
        .where('created_at > ?', 30.days.ago)
        .group('DATE(created_at)')
        .count
        .transform_keys(&:to_s),
      
      embedding_usage: Ragdoll::Embedding
        .joins(:document)
        .group('ragdoll_documents.title')
        .order('SUM(ragdoll_embeddings.usage_count) DESC')
        .limit(10)
        .sum(:usage_count),
      
      similarity_distribution: Ragdoll::Search
        .where('similarity_score IS NOT NULL')
        .group('ROUND(similarity_score::numeric, 1)')
        .count
        .transform_keys(&:to_f)
        .sort
        .to_h
    }
    
    render json: analytics_data
  end
end