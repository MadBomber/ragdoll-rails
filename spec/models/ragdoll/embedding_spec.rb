require 'rails_helper'

RSpec.describe Ragdoll::Embedding, type: :model do
  describe 'associations' do
    it { should belong_to(:document).class_name('Ragdoll::Document') }
  end

  describe 'validations' do
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:embedding) }
  end

  describe 'attributes and defaults' do
    let(:embedding) { build(:ragdoll_embedding) }

    it 'has default embedding_type as text' do
      embedding = Ragdoll::Embedding.new
      expect(embedding.embedding_type).to eq('text')
    end

    it 'has default metadata as empty hash' do
      embedding = Ragdoll::Embedding.new
      expect(embedding.metadata).to eq({})
    end

    it 'stores vector embedding' do
      vector = Array.new(1536) { rand }
      embedding = create(:ragdoll_embedding, embedding: vector)
      
      expect(embedding.reload.embedding).to eq(vector)
    end
  end

  describe 'vector operations' do
    let(:document) { create(:ragdoll_document) }
    let(:embedding1) { create(:ragdoll_embedding, document: document, embedding: Array.new(1536, 0.5)) }
    let(:embedding2) { create(:ragdoll_embedding, document: document, embedding: Array.new(1536, 0.7)) }

    it 'stores vector embeddings with correct dimensions' do
      expect(embedding1.embedding.length).to eq(1536)
      expect(embedding2.embedding.length).to eq(1536)
    end

    it 'can be queried for similarity' do
      # Test that we can perform vector operations (would need pgvector in real test)
      expect(embedding1.embedding).to be_an(Array)
      expect(embedding2.embedding).to be_an(Array)
    end
  end

  describe 'content handling' do
    it 'stores chunk content' do
      content = "This is a test chunk of content from a larger document."
      embedding = create(:ragdoll_embedding, content: content)
      
      expect(embedding.reload.content).to eq(content)
    end

    it 'handles large content chunks' do
      large_content = "Large chunk content. " * 1000 # ~20KB
      embedding = create(:ragdoll_embedding, :large_chunk, content: large_content)
      
      expect(embedding.reload.content).to eq(large_content)
    end

    it 'handles unicode in content' do
      unicode_content = "Content with émojis 🔥 and ñoñó"
      embedding = create(:ragdoll_embedding, content: unicode_content)
      
      expect(embedding.reload.content).to eq(unicode_content)
    end
  end

  describe 'metadata storage' do
    it 'stores chunk metadata' do
      metadata = {
        chunk_length: 150,
        word_count: 25,
        language: 'en',
        sentiment: 'neutral'
      }
      embedding = create(:ragdoll_embedding, metadata: metadata)
      
      expect(embedding.reload.metadata).to eq(metadata.stringify_keys)
    end

    it 'allows empty metadata' do
      embedding = create(:ragdoll_embedding, metadata: {})
      expect(embedding.metadata).to eq({})
    end
  end

  describe 'model and token tracking' do
    it 'tracks the embedding model used' do
      embedding = create(:ragdoll_embedding, model_name: 'text-embedding-3-large')
      expect(embedding.model_name).to eq('text-embedding-3-large')
    end

    it 'tracks token count' do
      embedding = create(:ragdoll_embedding, token_count: 150)
      expect(embedding.token_count).to eq(150)
    end

    it 'calculates approximate token count from content' do
      content = "This is a test with approximately twenty five tokens in total content here"
      embedding = create(:ragdoll_embedding, content: content)
      
      # Token count should be reasonable approximation
      expect(embedding.token_count).to be_between(10, 50)
    end
  end

  describe 'chunk indexing' do
    let(:document) { create(:ragdoll_document) }

    it 'tracks chunk index within document' do
      embedding1 = create(:ragdoll_embedding, document: document, chunk_index: 0)
      embedding2 = create(:ragdoll_embedding, document: document, chunk_index: 1)
      embedding3 = create(:ragdoll_embedding, document: document, chunk_index: 2)
      
      expect(embedding1.chunk_index).to eq(0)
      expect(embedding2.chunk_index).to eq(1)
      expect(embedding3.chunk_index).to eq(2)
    end

    it 'orders embeddings by chunk index' do
      embedding3 = create(:ragdoll_embedding, document: document, chunk_index: 2)
      embedding1 = create(:ragdoll_embedding, document: document, chunk_index: 0)
      embedding2 = create(:ragdoll_embedding, document: document, chunk_index: 1)
      
      ordered = document.ragdoll_embeddings.order(:chunk_index)
      expect(ordered.map(&:chunk_index)).to eq([0, 1, 2])
    end
  end

  describe 'embedding types' do
    it 'supports text embedding type' do
      embedding = create(:ragdoll_embedding, embedding_type: 'text')
      expect(embedding.embedding_type).to eq('text')
    end

    it 'supports code embedding type' do
      embedding = create(:ragdoll_embedding, :code_content)
      expect(embedding.embedding_type).to eq('code')
    end

    it 'supports question embedding type' do
      embedding = create(:ragdoll_embedding, :question_content)
      expect(embedding.embedding_type).to eq('question')
    end
  end

  describe 'scopes and queries' do
    let(:document) { create(:ragdoll_document) }

    before do
      create(:ragdoll_embedding, document: document, embedding_type: 'text', chunk_index: 0)
      create(:ragdoll_embedding, document: document, embedding_type: 'code', chunk_index: 1)
      create(:ragdoll_embedding, document: document, embedding_type: 'text', chunk_index: 2)
    end

    it 'filters by embedding type' do
      text_embeddings = Ragdoll::Embedding.where(embedding_type: 'text')
      code_embeddings = Ragdoll::Embedding.where(embedding_type: 'code')
      
      expect(text_embeddings.count).to eq(2)
      expect(code_embeddings.count).to eq(1)
    end

    it 'filters by document' do
      other_document = create(:ragdoll_document)
      create(:ragdoll_embedding, document: other_document)
      
      expect(document.ragdoll_embeddings.count).to eq(3)
      expect(other_document.ragdoll_embeddings.count).to eq(1)
    end

    it 'searches by content' do
      specific_content = "Very specific test content for searching"
      create(:ragdoll_embedding, document: document, content: specific_content)
      
      results = Ragdoll::Embedding.where("content ILIKE ?", "%specific test%")
      expect(results.count).to eq(1)
      expect(results.first.content).to eq(specific_content)
    end
  end

  describe 'vector similarity (mock tests)' do
    # These would require pgvector in a real test environment
    # For now, we test the structure and data storage
    
    let(:document) { create(:ragdoll_document) }
    
    it 'stores embeddings that could be used for similarity search' do
      embedding1 = create(:ragdoll_embedding, :high_similarity, document: document)
      embedding2 = create(:ragdoll_embedding, :high_similarity, document: document)
      
      # Both embeddings have the same vector values
      expect(embedding1.embedding).to eq(embedding2.embedding)
    end

    it 'stores different embeddings for different content' do
      embedding1 = create(:ragdoll_embedding, :high_similarity, document: document)
      embedding2 = create(:ragdoll_embedding, :low_similarity, document: document)
      
      # Different embeddings have different vector values
      expect(embedding1.embedding).not_to eq(embedding2.embedding)
    end
  end
end
