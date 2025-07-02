# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ragdoll::API, type: :service do
  let(:embedding_service) { instance_double(Ragdoll::EmbeddingService) }
  let(:api) { described_class.new(embedding_service: embedding_service) }
  let(:document) { create(:ragdoll_document) }
  let(:query_embedding) { Array.new(1536, 0.5) }
  
  before do
    allow(embedding_service).to receive(:generate_embedding).and_return(query_embedding)
    allow(Ragdoll.configuration).to receive(:usage_ranking_enabled).and_return(true)
    allow(Ragdoll.configuration).to receive(:usage_recency_weight).and_return(0.3)
    allow(Ragdoll.configuration).to receive(:usage_frequency_weight).and_return(0.7)
    allow(Ragdoll.configuration).to receive(:usage_similarity_weight).and_return(1.0)
  end
  
  describe '#search with usage tracking' do
    let(:mock_results) do
      [
        {
          embedding_id: 1,
          document_id: document.id,
          document_title: "Test Document",
          document_location: "/test/doc.txt",
          document_type: "text",
          content: "Test content",
          similarity: 0.95,
          distance: 0.05,
          chunk_index: 0,
          metadata: { test: true },
          usage_count: 5,
          returned_at: 1.hour.ago,
          usage_score: 0.8,
          combined_score: 1.75
        },
        {
          embedding_id: 2,
          document_id: document.id,
          document_title: "Test Document",
          document_location: "/test/doc.txt",
          document_type: "text",
          content: "More test content",
          similarity: 0.90,
          distance: 0.10,
          chunk_index: 1,
          metadata: { test: true },
          usage_count: 0,
          returned_at: nil,
          usage_score: 0.0,
          combined_score: 0.90
        }
      ]
    end
    
    before do
      allow(embedding_service).to receive(:search_similar).and_return(mock_results)
    end
    
    it 'passes usage tracking options to embedding service' do
      expect(embedding_service).to receive(:search_similar).with(
        query_embedding,
        limit: 10,
        threshold: 0.7,
        options: hash_including(
          use_usage_ranking: true,
          recency_weight: 0.3,
          frequency_weight: 0.7,
          similarity_weight: 1.0
        )
      )
      
      api.search("test query")
    end
    
    it 'includes usage information in search results' do
      results = api.search("test query")
      
      expect(results[:results]).to be_an(Array)
      expect(results[:results].first).to include(
        :id,
        :content,
        :similarity,
        :document,
        :chunk_index,
        :metadata
      )
    end
    
    it 'formats document information correctly' do
      results = api.search("test query")
      
      first_result = results[:results].first
      expect(first_result[:document]).to include(
        :id,
        :title,
        :location,
        :type
      )
    end
    
    it 'returns results ordered by combined score' do
      results = api.search("test query")
      
      expect(results[:results].first[:similarity]).to eq(0.95)
      expect(results[:results].last[:similarity]).to eq(0.90)
    end
    
    it 'handles custom limits and thresholds' do
      expect(embedding_service).to receive(:search_similar).with(
        anything,
        limit: 5,
        threshold: 0.8,
        options: anything
      )
      
      api.search("test query", limit: 5, threshold: 0.8)
    end
    
    it 'applies document filters when provided' do
      filters = { document_type: 'pdf', document_status: 'processed' }
      
      # Mock the filter application
      allow(api).to receive(:apply_document_filters).and_return(mock_results)
      
      api.search("test query", filters: filters)
      
      expect(api).to have_received(:apply_document_filters).with(mock_results, filters)
    end
  end
  
  describe '#get_context with usage tracking' do
    let(:mock_results) do
      [
        {
          embedding_id: 1,
          document_id: document.id,
          document_title: "Test Document",
          document_location: "/test/doc.txt",
          content: "Important context content",
          similarity: 0.95,
          chunk_index: 0,
          usage_count: 10,
          returned_at: 30.minutes.ago,
          usage_score: 0.9,
          combined_score: 1.85
        }
      ]
    end
    
    before do
      allow(embedding_service).to receive(:search_similar).and_return(mock_results)
    end
    
    it 'uses usage-aware ranking for context selection' do
      expect(embedding_service).to receive(:search_similar).with(
        query_embedding,
        limit: 10,
        threshold: 0.7,
        options: hash_including(use_usage_ranking: true)
      )
      
      api.get_context("test prompt")
    end
    
    it 'formats context results appropriately' do
      context = api.get_context("test prompt")
      
      expect(context).to include(
        :prompt,
        :context_chunks,
        :total_chunks,
        :combined_context
      )
      
      expect(context[:context_chunks]).to be_an(Array)
      expect(context[:context_chunks].first).to include(
        :content,
        :source,
        :relevance_score
      )
    end
    
    it 'combines context from multiple chunks' do
      context = api.get_context("test prompt")
      
      expect(context[:combined_context]).to include("Important context content")
      expect(context[:total_chunks]).to eq(1)
    end
  end
  
  describe 'search analytics integration' do
    before do
      allow(embedding_service).to receive(:search_similar).and_return([])
      allow(Ragdoll::Search).to receive(:create!)
    end
    
    it 'stores search records for analytics' do
      expect(Ragdoll::Search).to receive(:create!).with(
        hash_including(
          query: "test query",
          query_embedding: query_embedding,
          search_type: 'semantic',
          result_count: 0
        )
      )
      
      api.search("test query")
    end
    
    it 'handles search recording errors gracefully' do
      allow(Ragdoll::Search).to receive(:create!).and_raise(StandardError.new("Database error"))
      allow(Rails.logger).to receive(:warn)
      
      expect { api.search("test query") }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with(/Failed to store search record/)
    end
  end
  
  describe 'configuration integration' do
    context 'when usage tracking is disabled' do
      before do
        allow(Ragdoll.configuration).to receive(:usage_ranking_enabled).and_return(false)
      end
      
      it 'disables usage ranking in search options' do
        expect(embedding_service).to receive(:search_similar).with(
          anything,
          anything,
          anything,
          options: hash_including(use_usage_ranking: false)
        )
        
        api.search("test query")
      end
    end
    
    context 'with custom weight configuration' do
      before do
        allow(Ragdoll.configuration).to receive(:usage_recency_weight).and_return(0.4)
        allow(Ragdoll.configuration).to receive(:usage_frequency_weight).and_return(0.8)
        allow(Ragdoll.configuration).to receive(:usage_similarity_weight).and_return(1.2)
      end
      
      it 'passes custom weights to embedding service' do
        expect(embedding_service).to receive(:search_similar).with(
          anything,
          anything,
          anything,
          options: hash_including(
            recency_weight: 0.4,
            frequency_weight: 0.8,
            similarity_weight: 1.2
          )
        )
        
        api.search("test query")
      end
    end
  end
  
  describe 'error handling' do
    it 'handles embedding service errors' do
      allow(embedding_service).to receive(:search_similar).and_raise(StandardError.new("Service error"))
      
      expect { api.search("test query") }.to raise_error(Ragdoll::API::SearchError, /Search failed/)
    end
    
    it 'handles embedding generation errors' do
      allow(embedding_service).to receive(:generate_embedding).and_raise(StandardError.new("Embedding error"))
      
      expect { api.search("test query") }.to raise_error(Ragdoll::API::SearchError, /Search failed/)
    end
  end
  
  describe 'performance considerations' do
    let(:large_mock_results) do
      (1..100).map do |i|
        {
          embedding_id: i,
          document_id: document.id,
          document_title: "Document #{i}",
          document_location: "/test/doc#{i}.txt",
          content: "Content #{i}",
          similarity: 0.9 - (i * 0.001),
          chunk_index: 0,
          usage_count: i,
          returned_at: i.hours.ago,
          usage_score: 0.8 - (i * 0.001),
          combined_score: 1.7 - (i * 0.001)
        }
      end
    end
    
    before do
      allow(embedding_service).to receive(:search_similar).and_return(large_mock_results)
    end
    
    it 'handles large result sets efficiently' do
      expect {
        results = api.search("test query", limit: 100)
        expect(results[:results].size).to eq(100)
      }.not_to take_longer_than(2.seconds)
    end
    
    it 'respects result limits' do
      results = api.search("test query", limit: 10)
      expect(results[:results].size).to eq(10)
    end
  end
end