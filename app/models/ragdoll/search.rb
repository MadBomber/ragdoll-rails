# frozen_string_literal: true

module Ragdoll
  class Search < ApplicationRecord
    self.table_name = 'ragdoll_searches'

    # Override dangerous attribute to allow access to model_name column
    def self.dangerous_attribute_method?(name)
      name.to_s == 'model_name' ? false : super
    end

    # Validations
    validates :query, presence: true, length: { minimum: 1, maximum: 10000 }
    validates :search_type, presence: true, inclusion: { in: %w[semantic keyword hybrid] }
    validates :result_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :search_time, numericality: { greater_than: 0 }, allow_nil: true
    validates :model_name, presence: true, length: { maximum: 255 }

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :by_type, ->(type) { where(search_type: type) }
    scope :successful, -> { where('result_count > 0') }
    scope :failed, -> { where(result_count: 0) }
    scope :by_model, ->(model) { where(model_name: model) }
    scope :within_days, ->(days) { where(created_at: days.days.ago..) }
    scope :slow_searches, ->(threshold = 2.0) { where('search_time > ?', threshold) }

    # Callbacks
    before_validation :set_defaults
    before_save :normalize_query
    after_create :update_analytics, if: -> { Ragdoll.configuration.enable_search_analytics }

    # Class methods
    def self.analytics(days: 30)
      searches = within_days(days)
      
      {
        total_searches: searches.count,
        unique_queries: searches.distinct.count(:query),
        average_results: searches.average(:result_count)&.round(2) || 0,
        average_search_time: searches.where.not(search_time: nil).average(:search_time)&.round(3) || 0,
        success_rate: calculate_success_rate(searches),
        most_common_queries: most_common_queries(searches),
        search_types: searches.group(:search_type).count,
        models_used: searches.group(:model_name).count,
        performance_stats: performance_statistics(searches)
      }
    end

    def self.most_common_queries(searches = all, limit: 10)
      searches
        .group(:query)
        .count
        .sort_by { |_, count| -count }
        .first(limit)
        .map { |query, count| { query: query, count: count } }
    end

    def self.calculate_success_rate(searches = all)
      total = searches.count
      return 0 if total == 0
      
      successful_count = searches.successful.count
      (successful_count.to_f / total * 100).round(2)
    end

    def self.performance_statistics(searches = all)
      searches_with_time = searches.where.not(search_time: nil)
      return {} if searches_with_time.empty?

      times = searches_with_time.pluck(:search_time).sort
      
      {
        fastest: times.first,
        slowest: times.last,
        median: calculate_median(times),
        percentile_95: calculate_percentile(times, 95),
        slow_search_count: searches.slow_searches.count
      }
    end

    def self.calculate_median(sorted_array)
      length = sorted_array.length
      return 0 if length == 0
      
      if length.odd?
        sorted_array[length / 2]
      else
        (sorted_array[length / 2 - 1] + sorted_array[length / 2]) / 2.0
      end
    end

    def self.calculate_percentile(sorted_array, percentile)
      return 0 if sorted_array.empty?
      
      index = (percentile / 100.0 * (sorted_array.length - 1)).round
      sorted_array[index]
    end

    # Instance methods
    def successful?
      result_count > 0
    end

    def failed?
      result_count == 0
    end

    def slow?(threshold = 2.0)
      search_time && search_time > threshold
    end

    def embedding_vector
      return nil unless query_embedding
      
      if query_embedding.is_a?(String)
        # Handle string representation of vector
        JSON.parse(query_embedding)
      else
        query_embedding
      end
    rescue JSON::ParserError
      nil
    end

    def result_ids
      return [] unless results.is_a?(Hash)
      
      results['result_ids'] || results[:result_ids] || []
    end

    def filter_summary
      return 'None' if filters.blank?
      
      filter_parts = []
      filters.each do |key, value|
        filter_parts << "#{key}: #{value}"
      end
      
      filter_parts.join(', ')
    end

    def performance_category
      return 'unknown' unless search_time
      
      case search_time
      when 0..0.5
        'fast'
      when 0.5..1.0
        'normal'
      when 1.0..2.0
        'slow'
      else
        'very_slow'
      end
    end

    def to_analytics_hash
      {
        id: id,
        query: query,
        search_type: search_type,
        result_count: result_count,
        search_time: search_time,
        performance_category: performance_category,
        successful: successful?,
        model_name: model_name,
        filters: filter_summary,
        created_at: created_at
      }
    end

    private

    def set_defaults
      self.search_type ||= 'semantic'
      self.result_count ||= 0
      self.filters ||= {}
      self.results ||= {}
      self.model_name ||= Ragdoll.configuration.embedding_model
    end

    def normalize_query
      return unless query
      
      # Remove excessive whitespace
      self.query = query.strip.gsub(/\s+/, ' ')
      
      # Truncate if too long
      self.query = query.truncate(10000) if query.length > 10000
    end

    def update_analytics
      # This could be extended to update real-time analytics
      # For now, it's just a placeholder for future enhancements
      Rails.logger.debug "Search recorded: #{query} (#{result_count} results in #{search_time}s)"
    end
  end
end