# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ragdoll::EmbeddingService, type: :service do
  let(:service) { described_class.new }
  let(:document) { create(:ragdoll_document) }
  let(:query_embedding) { Array.new(1536, 0.5) }
  
  before do
    # Mock the ruby_llm configuration
    allow(service).to receive(:configure_ruby_llm)
    allow(RubyLLM).to receive(:embed).and_return(query_embedding)
  end
  
  describe '#search_similar with usage tracking' do
    let!(:high_similarity) { create(:ragdoll_embedding, :high_similarity, :never_used, document: document) }
    let!(:frequently_used) { create(:ragdoll_embedding, :high_similarity, :frequently_used, document: document) }
    let!(:recently_used) { create(:ragdoll_embedding, :high_similarity, :recently_used, document: document) }
    let!(:old_usage) { create(:ragdoll_embedding, :high_similarity, :old_usage, document: document) }
    
    context 'with usage ranking enabled' do
      it 'includes usage metrics in results' do
        results = service.search_similar(query_embedding, limit: 4, options: { use_usage_ranking: true })
        
        expect(results).not_to be_empty
        results.each do |result|
          expect(result).to include(
            :usage_count,
            :returned_at,
            :usage_score,
            :combined_score
          )
        end
      end
      
      it 'ranks results by combined score including usage' do
        results = service.search_similar(query_embedding, limit: 4, options: { use_usage_ranking: true })
        
        # Results should be ordered by combined score (similarity + usage)
        combined_scores = results.map { |r| r[:combined_score] }
        expect(combined_scores).to eq(combined_scores.sort.reverse)
      end
      
      it 'gives preference to frequently used embeddings with similar similarity' do
        results = service.search_similar(query_embedding, limit: 4, options: { use_usage_ranking: true })
        
        # Find our test embeddings in results
        frequent_result = results.find { |r| r[:embedding_id] == frequently_used.id }
        never_used_result = results.find { |r| r[:embedding_id] == high_similarity.id }
        
        expect(frequent_result[:combined_score]).to be > never_used_result[:combined_score]
      end
      
      it 'respects custom weight configuration' do
        # High frequency weight should favor frequently used
        high_freq_results = service.search_similar(
          query_embedding, 
          limit: 4, 
          options: { 
            use_usage_ranking: true,
            frequency_weight: 0.9,
            recency_weight: 0.1,
            similarity_weight: 0.5
          }
        )
        
        # High recency weight should favor recently used
        high_recency_results = service.search_similar(
          query_embedding, 
          limit: 4, 
          options: { 
            use_usage_ranking: true,
            frequency_weight: 0.1,
            recency_weight: 0.9,
            similarity_weight: 0.5
          }
        )
        
        freq_result_freq = high_freq_results.find { |r| r[:embedding_id] == frequently_used.id }
        recent_result_freq = high_freq_results.find { |r| r[:embedding_id] == recently_used.id }
        
        freq_result_rec = high_recency_results.find { |r| r[:embedding_id] == frequently_used.id }
        recent_result_rec = high_recency_results.find { |r| r[:embedding_id] == recently_used.id }
        
        # In high frequency weight scenario, frequently used should rank higher
        expect(freq_result_freq[:combined_score]).to be > recent_result_freq[:combined_score]
        
        # In high recency weight scenario, recently used should rank higher
        expect(recent_result_rec[:combined_score]).to be > freq_result_rec[:combined_score]
      end
    end
    
    context 'with usage ranking disabled' do
      it 'still includes usage fields but ignores them in ranking' do
        results = service.search_similar(query_embedding, limit: 4, options: { use_usage_ranking: false })
        
        results.each do |result|
          expect(result).to include(
            :usage_count,
            :returned_at,
            :usage_score,
            :combined_score
          )
          expect(result[:usage_score]).to eq(0.0)
          expect(result[:combined_score]).to eq(result[:similarity])
        end
      end
      
      it 'ranks results purely by similarity' do
        results = service.search_similar(query_embedding, limit: 4, options: { use_usage_ranking: false })
        
        similarities = results.map { |r| r[:similarity] }
        expect(similarities).to eq(similarities.sort.reverse)
      end
    end
    
    context 'usage recording' do
      it 'records usage for returned embeddings' do
        expect(Ragdoll::Embedding).to receive(:record_batch_usage).with(array_including(Integer))
        
        service.search_similar(query_embedding, limit: 4)
      end
      
      it 'handles usage recording errors gracefully' do
        allow(Ragdoll::Embedding).to receive(:record_batch_usage).and_raise(StandardError.new("Database error"))
        allow(Rails.logger).to receive(:warn)
        
        expect { service.search_similar(query_embedding, limit: 4) }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).with(/Failed to record embedding usage/)
      end
      
      it 'does not fail search if usage recording fails' do
        allow(Ragdoll::Embedding).to receive(:record_batch_usage).and_raise(StandardError.new("Database error"))
        
        results = service.search_similar(query_embedding, limit: 4)
        expect(results).not_to be_empty
      end
    end
    
    context 'filtering and dimensions' do
      let!(:different_model) { create(:ragdoll_embedding, :different_model, :frequently_used, document: document) }
      
      it 'filters by embedding dimensions' do
        results = service.search_similar(query_embedding, limit: 10)
        
        # Should only return embeddings with matching dimensions (1536)
        results.each do |result|
          expect(result[:embedding_dimensions]).to eq(1536)
        end
        
        # Should not include the 3072-dimension embedding
        embedding_ids = results.map { |r| r[:embedding_id] }
        expect(embedding_ids).not_to include(different_model.id)
      end
      
      it 'filters by model name when specified' do
        results = service.search_similar(
          query_embedding, 
          limit: 10, 
          model_name: 'text-embedding-3-small'
        )
        
        results.each do |result|
          expect(result[:model_name]).to eq('text-embedding-3-small')
        end
      end
    end
    
    context 'threshold filtering' do
      it 'respects similarity threshold' do
        results = service.search_similar(query_embedding, limit: 10, threshold: 0.9)
        
        results.each do |result|
          expect(result[:similarity]).to be >= 0.9
        end
      end
    end
  end
  
  describe 'integration with configuration' do
    before do
      allow(Ragdoll.configuration).to receive(:usage_ranking_enabled).and_return(true)
      allow(Ragdoll.configuration).to receive(:usage_recency_weight).and_return(0.4)
      allow(Ragdoll.configuration).to receive(:usage_frequency_weight).and_return(0.6)
      allow(Ragdoll.configuration).to receive(:usage_similarity_weight).and_return(1.2)
    end
    
    it 'uses configuration values as defaults' do
      # We can't easily test the SQL generation, but we can test that the method
      # doesn't fail and returns results when configuration values are used
      results = service.search_similar(query_embedding, limit: 5)
      expect(results).to be_an(Array)
    end
  end
  
  describe 'performance considerations' do
    it 'uses batch updates for usage recording' do
      create_list(:ragdoll_embedding, 10, :high_similarity, document: document)
      
      expect(Ragdoll::Embedding).to receive(:record_batch_usage).once
      
      service.search_similar(query_embedding, limit: 10)
    end
    
    it 'handles large result sets efficiently' do
      create_list(:ragdoll_embedding, 50, :high_similarity, document: document)
      
      expect {
        results = service.search_similar(query_embedding, limit: 50)
        expect(results.size).to be <= 50
      }.not_to take_longer_than(5.seconds)
    end
  end
end