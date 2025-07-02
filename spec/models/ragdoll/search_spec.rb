require 'rails_helper'

RSpec.describe Ragdoll::Search, type: :model do
  describe 'validations' do
    it 'validates presence of query' do
      search = build(:ragdoll_search, query: nil)
      expect(search).not_to be_valid
      expect(search.errors[:query]).to include("can't be blank")
    end

    it 'validates length of query' do
      search = build(:ragdoll_search, query: 'a' * 10001)
      expect(search).not_to be_valid
      expect(search.errors[:query]).to include('is too long (maximum is 10000 characters)')
    end

    it 'validates search_type inclusion' do
      search = build(:ragdoll_search, search_type: 'invalid')
      expect(search).not_to be_valid
      expect(search.errors[:search_type]).to include('is not included in the list')
    end

    it 'validates result_count numericality' do
      search = build(:ragdoll_search, result_count: -1)
      expect(search).not_to be_valid
      expect(search.errors[:result_count]).to include('must be greater than or equal to 0')
    end

    it 'validates search_time numericality when present' do
      search = build(:ragdoll_search, search_time: -1.0)
      expect(search).not_to be_valid
      expect(search.errors[:search_time]).to include('must be greater than 0')
    end

    it 'validates model_name presence and length' do
      search = build(:ragdoll_search, model_name: nil)
      expect(search).not_to be_valid
      expect(search.errors[:model_name]).to include("can't be blank")

      search = build(:ragdoll_search, model_name: 'a' * 256)
      expect(search).not_to be_valid
      expect(search.errors[:model_name]).to include('is too long (maximum is 255 characters)')
    end
  end

  describe 'scopes' do
    let!(:successful_search) { create(:ragdoll_search, result_count: 5) }
    let!(:failed_search) { create(:ragdoll_search, result_count: 0) }
    let!(:semantic_search) { create(:ragdoll_search, search_type: 'semantic') }
    let!(:keyword_search) { create(:ragdoll_search, search_type: 'keyword') }
    let!(:slow_search) { create(:ragdoll_search, search_time: 3.0) }
    let!(:fast_search) { create(:ragdoll_search, search_time: 0.5) }

    describe '.successful' do
      it 'returns searches with results' do
        expect(described_class.successful).to include(successful_search)
        expect(described_class.successful).not_to include(failed_search)
      end
    end

    describe '.failed' do
      it 'returns searches without results' do
        expect(described_class.failed).to include(failed_search)
        expect(described_class.failed).not_to include(successful_search)
      end
    end

    describe '.by_type' do
      it 'filters by search type' do
        expect(described_class.by_type('semantic')).to include(semantic_search)
        expect(described_class.by_type('semantic')).not_to include(keyword_search)
      end
    end

    describe '.slow_searches' do
      it 'returns slow searches above threshold' do
        expect(described_class.slow_searches(2.0)).to include(slow_search)
        expect(described_class.slow_searches(2.0)).not_to include(fast_search)
      end
    end

    describe '.within_days' do
      it 'returns recent searches' do
        old_search = create(:ragdoll_search, created_at: 40.days.ago)
        recent_search = create(:ragdoll_search, created_at: 10.days.ago)

        expect(described_class.within_days(30)).to include(recent_search)
        expect(described_class.within_days(30)).not_to include(old_search)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation :set_defaults' do
      it 'sets default values' do
        search = described_class.new(query: 'test')
        search.valid?

        expect(search.search_type).to eq('semantic')
        expect(search.result_count).to eq(0)
        expect(search.filters).to eq({})
        expect(search.results).to eq({})
        expect(search.model_name).to eq('text-embedding-3-small')
      end
    end

    describe 'before_save :normalize_query' do
      it 'normalizes whitespace in query' do
        search = create(:ragdoll_search, query: '  test   query  with   spaces  ')
        expect(search.query).to eq('test query with spaces')
      end

      it 'truncates very long queries' do
        long_query = 'a' * 10001
        search = create(:ragdoll_search, query: long_query)
        expect(search.query.length).to be <= 10000
      end
    end
  end

  describe 'class methods' do
    let!(:search1) { create(:ragdoll_search, query: 'test query', result_count: 5, search_time: 1.5) }
    let!(:search2) { create(:ragdoll_search, query: 'another query', result_count: 0, search_time: 0.8) }
    let!(:search3) { create(:ragdoll_search, query: 'test query', result_count: 3, search_time: 2.1) }

    describe '.analytics' do
      it 'returns comprehensive analytics' do
        analytics = described_class.analytics(days: 30)

        expect(analytics).to include(
          :total_searches,
          :unique_queries,
          :average_results,
          :average_search_time,
          :success_rate,
          :most_common_queries,
          :search_types,
          :models_used,
          :performance_stats
        )

        expect(analytics[:total_searches]).to eq(3)
        expect(analytics[:unique_queries]).to eq(2)
        expect(analytics[:success_rate]).to eq(66.67)
      end
    end

    describe '.most_common_queries' do
      it 'returns most frequent queries' do
        common_queries = described_class.most_common_queries

        expect(common_queries.first[:query]).to eq('test query')
        expect(common_queries.first[:count]).to eq(2)
      end
    end

    describe '.calculate_success_rate' do
      it 'calculates success rate percentage' do
        rate = described_class.calculate_success_rate
        expect(rate).to eq(66.67)
      end

      it 'returns 0 for no searches' do
        described_class.destroy_all
        rate = described_class.calculate_success_rate
        expect(rate).to eq(0)
      end
    end

    describe '.performance_statistics' do
      it 'returns performance metrics' do
        stats = described_class.performance_statistics

        expect(stats).to include(:fastest, :slowest, :median, :percentile_95)
        expect(stats[:fastest]).to eq(0.8)
        expect(stats[:slowest]).to eq(2.1)
      end
    end
  end

  describe 'instance methods' do
    let(:successful_search) { create(:ragdoll_search, result_count: 5, search_time: 1.5) }
    let(:failed_search) { create(:ragdoll_search, result_count: 0) }

    describe '#successful?' do
      it 'returns true for searches with results' do
        expect(successful_search.successful?).to be true
        expect(failed_search.successful?).to be false
      end
    end

    describe '#failed?' do
      it 'returns true for searches without results' do
        expect(failed_search.failed?).to be true
        expect(successful_search.failed?).to be false
      end
    end

    describe '#slow?' do
      it 'determines if search is slow' do
        expect(successful_search.slow?(1.0)).to be true
        expect(successful_search.slow?(2.0)).to be false
      end
    end

    describe '#embedding_vector' do
      it 'parses JSON string embedding' do
        search = create(:ragdoll_search, query_embedding: '[1.0, 2.0, 3.0]')
        expect(search.embedding_vector).to eq([1.0, 2.0, 3.0])
      end

      it 'returns array embedding as-is' do
        search = create(:ragdoll_search, query_embedding: [1.0, 2.0, 3.0])
        expect(search.embedding_vector).to eq([1.0, 2.0, 3.0])
      end

      it 'handles invalid JSON gracefully' do
        search = create(:ragdoll_search, query_embedding: 'invalid json')
        expect(search.embedding_vector).to be_nil
      end
    end

    describe '#result_ids' do
      it 'extracts result IDs from results hash' do
        search = create(:ragdoll_search, results: { 'result_ids' => [1, 2, 3] })
        expect(search.result_ids).to eq([1, 2, 3])
      end

      it 'returns empty array for no results' do
        search = create(:ragdoll_search, results: {})
        expect(search.result_ids).to eq([])
      end
    end

    describe '#filter_summary' do
      it 'summarizes filters' do
        search = create(:ragdoll_search, filters: { 'type' => 'pdf', 'size' => 'large' })
        expect(search.filter_summary).to eq('type: pdf, size: large')
      end

      it 'returns None for no filters' do
        search = create(:ragdoll_search, filters: {})
        expect(search.filter_summary).to eq('None')
      end
    end

    describe '#performance_category' do
      it 'categorizes search performance' do
        fast_search = create(:ragdoll_search, search_time: 0.3)
        normal_search = create(:ragdoll_search, search_time: 0.8)
        slow_search = create(:ragdoll_search, search_time: 1.5)
        very_slow_search = create(:ragdoll_search, search_time: 3.0)

        expect(fast_search.performance_category).to eq('fast')
        expect(normal_search.performance_category).to eq('normal')
        expect(slow_search.performance_category).to eq('slow')
        expect(very_slow_search.performance_category).to eq('very_slow')
      end
    end

    describe '#to_analytics_hash' do
      it 'returns analytics representation' do
        search = create(:ragdoll_search, 
          query: 'test', 
          result_count: 5, 
          search_time: 1.2,
          filters: { 'type' => 'pdf' }
        )

        hash = search.to_analytics_hash

        expect(hash).to include(
          :id, :query, :search_type, :result_count, :search_time,
          :performance_category, :successful, :model_name, :filters, :created_at
        )
        expect(hash[:successful]).to be true
        expect(hash[:performance_category]).to eq('slow')
      end
    end
  end

  describe 'configuration integration' do
    it 'respects search analytics configuration' do
      with_ragdoll_config(enable_search_analytics: true) do
        expect(Rails.logger).to receive(:debug).with(/Search recorded/)
        create(:ragdoll_search)
      end
    end

    it 'skips analytics when disabled' do
      with_ragdoll_config(enable_search_analytics: false) do
        expect(Rails.logger).not_to receive(:debug)
        create(:ragdoll_search)
      end
    end
  end
end