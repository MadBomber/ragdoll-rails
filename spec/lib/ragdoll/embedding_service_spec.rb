require 'rails_helper'

RSpec.describe Ragdoll::EmbeddingService do
  let(:mock_client) { double('openai_client') }
  let(:service) { described_class.new(client: mock_client) }

  describe '#initialize' do
    it 'creates default OpenAI client when none provided' do
      expect(OpenAI::Client).to receive(:new).with(access_token: 'test-key')
      described_class.new
    end

    it 'uses provided client' do
      service = described_class.new(client: mock_client)
      expect(service.instance_variable_get(:@client)).to eq(mock_client)
    end
  end

  describe '#generate_embedding' do
    let(:text) { "Test text for embedding" }
    let(:mock_embedding) { Array.new(1536) { rand } }

    context 'with successful API response' do
      before do
        allow(mock_client).to receive(:embeddings).and_return({
          'data' => [{ 'embedding' => mock_embedding }]
        })
      end

      it 'generates embedding for text' do
        result = service.generate_embedding(text)
        
        expect(result).to eq(mock_embedding)
        expect(mock_client).to have_received(:embeddings).with(
          parameters: {
            model: 'text-embedding-3-small',
            input: text
          }
        )
      end

      it 'cleans text before sending to API' do
        dirty_text = "  Text  with\n\nextra   whitespace\t\t  "
        cleaned_text = "Text with extra whitespace"
        
        service.generate_embedding(dirty_text)
        
        expect(mock_client).to have_received(:embeddings).with(
          parameters: {
            model: 'text-embedding-3-small',
            input: cleaned_text
          }
        )
      end

      it 'truncates very long text' do
        long_text = "word " * 3000 # Very long text
        
        service.generate_embedding(long_text)
        
        # Should truncate but still call the API
        expect(mock_client).to have_received(:embeddings)
      end
    end

    context 'with empty or nil text' do
      it 'returns nil for blank text' do
        expect(service.generate_embedding(nil)).to be_nil
        expect(service.generate_embedding("")).to be_nil
        expect(service.generate_embedding("   ")).to be_nil
      end
    end

    context 'with API errors' do
      it 'raises EmbeddingError for network errors' do
        allow(mock_client).to receive(:embeddings)
          .and_raise(Faraday::Error.new("Network error"))
        
        expect {
          service.generate_embedding(text)
        }.to raise_error(Ragdoll::EmbeddingService::EmbeddingError, /Network error/)
      end

      it 'raises EmbeddingError for JSON parsing errors' do
        allow(mock_client).to receive(:embeddings)
          .and_raise(JSON::ParserError.new("Invalid JSON"))
        
        expect {
          service.generate_embedding(text)
        }.to raise_error(Ragdoll::EmbeddingService::EmbeddingError, /Invalid JSON/)
      end

      it 'raises EmbeddingError for invalid response format' do
        allow(mock_client).to receive(:embeddings).and_return({
          'error' => 'Invalid request'
        })
        
        expect {
          service.generate_embedding(text)
        }.to raise_error(Ragdoll::EmbeddingService::EmbeddingError, /Invalid response format/)
      end

      it 'raises EmbeddingError for other exceptions' do
        allow(mock_client).to receive(:embeddings)
          .and_raise(StandardError.new("Unknown error"))
        
        expect {
          service.generate_embedding(text)
        }.to raise_error(Ragdoll::EmbeddingService::EmbeddingError, /Failed to generate embedding/)
      end
    end
  end

  describe '#generate_embeddings_batch' do
    let(:texts) { ["First text", "Second text", "Third text"] }
    let(:mock_embeddings) do
      texts.map { |_| Array.new(1536) { rand } }
    end

    context 'with successful API response' do
      before do
        allow(mock_client).to receive(:embeddings).and_return({
          'data' => mock_embeddings.map { |embedding| { 'embedding' => embedding } }
        })
      end

      it 'generates embeddings for multiple texts' do
        result = service.generate_embeddings_batch(texts)
        
        expect(result).to eq(mock_embeddings)
        expect(mock_client).to have_received(:embeddings).with(
          parameters: {
            model: 'text-embedding-3-small',
            input: texts
          }
        )
      end

      it 'filters out blank texts' do
        texts_with_blanks = ["Text 1", "", "  ", "Text 2", nil]
        expected_clean_texts = ["Text 1", "Text 2"]
        
        service.generate_embeddings_batch(texts_with_blanks)
        
        expect(mock_client).to have_received(:embeddings).with(
          parameters: {
            model: 'text-embedding-3-small',
            input: expected_clean_texts
          }
        )
      end
    end

    context 'with empty input' do
      it 'returns empty array for empty input' do
        expect(service.generate_embeddings_batch([])).to eq([])
        expect(service.generate_embeddings_batch([nil, ""])).to eq([])
      end
    end

    context 'with API errors' do
      it 'raises EmbeddingError for batch processing errors' do
        allow(mock_client).to receive(:embeddings)
          .and_raise(Faraday::Error.new("Batch error"))
        
        expect {
          service.generate_embeddings_batch(texts)
        }.to raise_error(Ragdoll::EmbeddingService::EmbeddingError, /Network error/)
      end
    end
  end

  describe '#cosine_similarity' do
    it 'calculates similarity between identical embeddings' do
      embedding = [1.0, 2.0, 3.0]
      
      similarity = service.cosine_similarity(embedding, embedding)
      
      expect(similarity).to be_within(0.001).of(1.0)
    end

    it 'calculates similarity between orthogonal embeddings' do
      embedding1 = [1.0, 0.0, 0.0]
      embedding2 = [0.0, 1.0, 0.0]
      
      similarity = service.cosine_similarity(embedding1, embedding2)
      
      expect(similarity).to be_within(0.001).of(0.0)
    end

    it 'calculates similarity between opposite embeddings' do
      embedding1 = [1.0, 2.0, 3.0]
      embedding2 = [-1.0, -2.0, -3.0]
      
      similarity = service.cosine_similarity(embedding1, embedding2)
      
      expect(similarity).to be_within(0.001).of(-1.0)
    end

    it 'returns 0 for nil embeddings' do
      embedding = [1.0, 2.0, 3.0]
      
      expect(service.cosine_similarity(nil, embedding)).to eq(0.0)
      expect(service.cosine_similarity(embedding, nil)).to eq(0.0)
      expect(service.cosine_similarity(nil, nil)).to eq(0.0)
    end

    it 'returns 0 for different length embeddings' do
      embedding1 = [1.0, 2.0, 3.0]
      embedding2 = [1.0, 2.0]
      
      similarity = service.cosine_similarity(embedding1, embedding2)
      
      expect(similarity).to eq(0.0)
    end

    it 'returns 0 for zero magnitude embeddings' do
      embedding1 = [1.0, 2.0, 3.0]
      embedding2 = [0.0, 0.0, 0.0]
      
      similarity = service.cosine_similarity(embedding1, embedding2)
      
      expect(similarity).to eq(0.0)
    end
  end

  describe '#search_similar' do
    let(:query_embedding) { Array.new(1536, 0.5) }
    let(:mock_results) do
      [
        {
          'id' => 1,
          'document_id' => 10,
          'title' => 'Test Document',
          'location' => '/test.txt',
          'content' => 'Test content',
          'similarity' => 0.9,
          'distance' => 0.1,
          'chunk_index' => 0,
          'metadata' => '{}'
        }
      ]
    end

    before do
      allow(ActiveRecord::Base.connection).to receive(:exec_query).and_return(mock_results)
    end

    it 'searches for similar embeddings with default parameters' do
      result = service.search_similar(query_embedding)
      
      expect(result).to be_an(Array)
      expect(result.first).to include(
        embedding_id: 1,
        document_id: 10,
        document_title: 'Test Document',
        similarity: 0.9
      )
      
      expect(ActiveRecord::Base.connection).to have_received(:exec_query)
        .with(anything, 'search_similar_embeddings', [query_embedding.to_s, 0.7, 10])
    end

    it 'uses custom limit and threshold' do
      service.search_similar(query_embedding, limit: 5, threshold: 0.8)
      
      expect(ActiveRecord::Base.connection).to have_received(:exec_query)
        .with(anything, 'search_similar_embeddings', [query_embedding.to_s, 0.8, 5])
    end

    it 'parses metadata JSON in results' do
      mock_results[0]['metadata'] = '{"key": "value"}'
      allow(ActiveRecord::Base.connection).to receive(:exec_query).and_return(mock_results)
      
      result = service.search_similar(query_embedding)
      
      expect(result.first[:metadata]).to eq({ 'key' => 'value' })
    end

    it 'handles invalid JSON metadata gracefully' do
      mock_results[0]['metadata'] = 'invalid json'
      allow(ActiveRecord::Base.connection).to receive(:exec_query).and_return(mock_results)
      
      result = service.search_similar(query_embedding)
      
      expect(result.first[:metadata]).to eq({})
    end
  end

  describe 'private methods' do
    describe '#clean_text' do
      it 'normalizes whitespace' do
        dirty_text = "  Text   with\n\n\nextra\t\twhitespace  "
        
        cleaned = service.send(:clean_text, dirty_text)
        
        expect(cleaned).to eq("Text with\nextra whitespace")
      end

      it 'handles nil input' do
        expect(service.send(:clean_text, nil)).to eq('')
      end

      it 'truncates very long text' do
        long_text = "a" * 10000
        
        cleaned = service.send(:clean_text, long_text)
        
        expect(cleaned.length).to be <= 8000
        expect(cleaned).to end_with('...')
      end

      it 'preserves text shorter than limit' do
        short_text = "Short text"
        
        cleaned = service.send(:clean_text, short_text)
        
        expect(cleaned).to eq(short_text)
      end

      it 'normalizes multiple newlines' do
        text_with_newlines = "Line 1\n\n\n\nLine 2"
        
        cleaned = service.send(:clean_text, text_with_newlines)
        
        expect(cleaned).to eq("Line 1\nLine 2")
      end

      it 'converts tabs to spaces' do
        text_with_tabs = "Text\t\twith\ttabs"
        
        cleaned = service.send(:clean_text, text_with_tabs)
        
        expect(cleaned).to eq("Text with tabs")
      end
    end
  end

  describe 'integration with configuration' do
    it 'uses configured embedding model' do
      with_ragdoll_config(embedding_model: 'text-embedding-3-large') do
        allow(mock_client).to receive(:embeddings).and_return({
          'data' => [{ 'embedding' => [1.0] }]
        })
        
        service.generate_embedding("test")
        
        expect(mock_client).to have_received(:embeddings).with(
          parameters: {
            model: 'text-embedding-3-large',
            input: 'test'
          }
        )
      end
    end

    it 'uses configured similarity threshold in search' do
      with_ragdoll_config(search_similarity_threshold: 0.85) do
        allow(ActiveRecord::Base.connection).to receive(:exec_query).and_return([])
        
        service.search_similar([1.0])
        
        expect(ActiveRecord::Base.connection).to have_received(:exec_query)
          .with(anything, anything, ['[1.0]', 0.85, 10])
      end
    end
  end
end