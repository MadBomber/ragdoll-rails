# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ragdoll Usage Tracking', type: :model do
  let(:document) { create(:ragdoll_document) }
  
  describe 'Embedding usage tracking' do
    let(:embedding) { create(:ragdoll_embedding, document: document) }
    
    describe '#record_usage!' do
      it 'increments usage count and updates returned_at' do
        freeze_time do
          expect { embedding.record_usage! }.to change { embedding.usage_count }.from(0).to(1)
          expect(embedding.returned_at).to be_within(1.second).of(Time.current)
        end
      end
      
      it 'can be called multiple times' do
        freeze_time do
          embedding.record_usage!
          embedding.record_usage!
          embedding.record_usage!
          
          expect(embedding.usage_count).to eq(3)
          expect(embedding.returned_at).to be_within(1.second).of(Time.current)
        end
      end
    end
    
    describe '#mark_as_returned!' do
      it 'acts as an alias for record_usage!' do
        freeze_time do
          expect { embedding.mark_as_returned! }.to change { embedding.usage_count }.from(0).to(1)
          expect(embedding.returned_at).to be_within(1.second).of(Time.current)
        end
      end
    end
    
    describe 'usage state methods' do
      context 'never used embedding' do
        let(:embedding) { create(:ragdoll_embedding, :never_used, document: document) }
        
        it 'returns correct state' do
          expect(embedding.never_used?).to be true
          expect(embedding.used_recently?).to be false
          expect(embedding.frequently_used?).to be false
          expect(embedding.last_used_days_ago).to be_nil
        end
      end
      
      context 'recently used embedding' do
        let(:embedding) { create(:ragdoll_embedding, :recently_used, document: document) }
        
        it 'returns correct state' do
          expect(embedding.never_used?).to be false
          expect(embedding.used_recently?).to be true
          expect(embedding.frequently_used?).to be false
          expect(embedding.last_used_days_ago).to eq(0)
        end
      end
      
      context 'frequently used embedding' do
        let(:embedding) { create(:ragdoll_embedding, :frequently_used, document: document) }
        
        it 'returns correct state' do
          expect(embedding.never_used?).to be false
          expect(embedding.used_recently?).to be true
          expect(embedding.frequently_used?).to be true
          expect(embedding.last_used_days_ago).to eq(0)
        end
      end
      
      context 'old usage embedding' do
        let(:embedding) { create(:ragdoll_embedding, :old_usage, document: document) }
        
        it 'returns correct state' do
          expect(embedding.never_used?).to be false
          expect(embedding.used_recently?).to be false
          expect(embedding.frequently_used?).to be true
          expect(embedding.last_used_days_ago).to eq(30)
        end
      end
    end
    
    describe '#usage_score' do
      it 'returns 0 for never used embeddings' do
        embedding = create(:ragdoll_embedding, :never_used, document: document)
        expect(embedding.usage_score).to eq(0.0)
      end
      
      it 'calculates score based on frequency and recency' do
        embedding = create(:ragdoll_embedding, :frequently_used, document: document)
        score = embedding.usage_score
        
        expect(score).to be > 0
        expect(score).to be <= 1.0
      end
      
      it 'gives higher scores to more frequently used embeddings' do
        frequent_embedding = create(:ragdoll_embedding, usage_count: 50, returned_at: 1.day.ago, document: document)
        infrequent_embedding = create(:ragdoll_embedding, usage_count: 2, returned_at: 1.day.ago, document: document)
        
        expect(frequent_embedding.usage_score).to be > infrequent_embedding.usage_score
      end
      
      it 'gives higher scores to more recently used embeddings' do
        recent_embedding = create(:ragdoll_embedding, usage_count: 10, returned_at: 1.hour.ago, document: document)
        old_embedding = create(:ragdoll_embedding, usage_count: 10, returned_at: 30.days.ago, document: document)
        
        expect(recent_embedding.usage_score).to be > old_embedding.usage_score
      end
      
      it 'accepts custom weights' do
        embedding = create(:ragdoll_embedding, :frequently_used, document: document)
        
        frequency_heavy = embedding.usage_score(recency_weight: 0.1, frequency_weight: 0.9)
        recency_heavy = embedding.usage_score(recency_weight: 0.9, frequency_weight: 0.1)
        
        expect(frequency_heavy).to be > 0
        expect(recency_heavy).to be > 0
      end
    end
  end
  
  describe 'Embedding scopes' do
    let!(:never_used) { create(:ragdoll_embedding, :never_used, document: document) }
    let!(:used_once) { create(:ragdoll_embedding, :used_once, document: document) }
    let!(:frequently_used) { create(:ragdoll_embedding, :frequently_used, document: document) }
    let!(:recently_used) { create(:ragdoll_embedding, :recently_used, document: document) }
    let!(:old_usage) { create(:ragdoll_embedding, :old_usage, document: document) }
    
    describe '.most_used' do
      it 'orders by usage count descending' do
        results = Ragdoll::Embedding.most_used
        expect(results.first).to eq(frequently_used)
        expect(results.last).to eq(never_used)
      end
    end
    
    describe '.recently_used' do
      it 'orders by returned_at descending' do
        results = Ragdoll::Embedding.recently_used
        expect(results.first).to eq(recently_used)
        expect(results.last).to eq(old_usage)
      end
    end
    
    describe '.never_used' do
      it 'returns embeddings that have never been used' do
        results = Ragdoll::Embedding.never_used
        expect(results).to contain_exactly(never_used)
      end
    end
    
    describe '.frequently_used' do
      it 'returns embeddings with usage count >= threshold' do
        results = Ragdoll::Embedding.frequently_used(5)
        expect(results).to contain_exactly(frequently_used, old_usage)
      end
      
      it 'uses default threshold of 5' do
        results = Ragdoll::Embedding.frequently_used
        expect(results).to contain_exactly(frequently_used, old_usage)
      end
    end
    
    describe '.used_since' do
      it 'returns embeddings used since given date' do
        results = Ragdoll::Embedding.used_since(2.days.ago)
        expect(results).to contain_exactly(used_once, frequently_used, recently_used)
      end
    end
    
    describe '.by_usage_and_recency' do
      it 'orders by usage count, then recency' do
        results = Ragdoll::Embedding.by_usage_and_recency
        expect(results.first).to eq(frequently_used) # highest usage count
        expect(results.second).to eq(old_usage) # second highest usage count
      end
    end
  end
  
  describe 'Class methods for analytics' do
    let!(:never_used) { create(:ragdoll_embedding, :never_used, document: document) }
    let!(:used_once) { create(:ragdoll_embedding, :used_once, document: document) }
    let!(:frequently_used) { create(:ragdoll_embedding, :frequently_used, document: document) }
    let!(:recently_used) { create(:ragdoll_embedding, :recently_used, document: document) }
    
    describe '.usage_analytics' do
      it 'returns comprehensive usage statistics' do
        analytics = Ragdoll::Embedding.usage_analytics
        
        expect(analytics).to include(
          total_embeddings: 4,
          used_embeddings: 3,
          never_used: 1,
          average_usage: be_a(Float),
          most_used_count: 10,
          recently_used_count: be_a(Integer),
          usage_distribution: be_a(Hash)
        )
      end
    end
    
    describe '.top_used' do
      it 'returns most used embeddings limited by count' do
        results = Ragdoll::Embedding.top_used(2)
        expect(results.length).to eq(2)
        expect(results.first).to eq(frequently_used)
      end
    end
    
    describe '.record_batch_usage' do
      it 'updates usage statistics for multiple embeddings' do
        embeddings = [never_used, used_once]
        embedding_ids = embeddings.map(&:id)
        
        expect {
          Ragdoll::Embedding.record_batch_usage(embedding_ids)
        }.to change { never_used.reload.usage_count }.from(0).to(1)
         .and change { used_once.reload.usage_count }.from(1).to(2)
      end
      
      it 'handles empty array gracefully' do
        expect { Ragdoll::Embedding.record_batch_usage([]) }.not_to raise_error
      end
    end
  end
end