require 'rails_helper'

RSpec.describe Ragdoll do
  before do
    stub_openai_embeddings if respond_to?(:stub_openai_embeddings)
  end

  describe 'module structure' do
    it 'defines error classes' do
      expect(Ragdoll::Error).to be < StandardError
      expect(Ragdoll::EmbeddingError).to be < Ragdoll::Error
      expect(Ragdoll::SearchError).to be < Ragdoll::Error
      expect(Ragdoll::DocumentError).to be < Ragdoll::Error
    end

    it 'autoloads required components' do
      expect(defined?(Ragdoll::Configuration)).to be_truthy
      expect(defined?(Ragdoll::Engine)).to be_truthy
      expect(defined?(Ragdoll::DocumentParser)).to be_truthy
      expect(defined?(Ragdoll::TextChunker)).to be_truthy
      expect(defined?(Ragdoll::EmbeddingService)).to be_truthy
      expect(defined?(Ragdoll::DocumentTypeDetector)).to be_truthy
      expect(defined?(Ragdoll::API)).to be_truthy
      expect(defined?(Ragdoll::Client)).to be_truthy
    end
  end

  describe 'configuration management' do
    it 'provides configuration access' do
      expect(Ragdoll.configuration).to be_a(Ragdoll::Configuration)
    end

    it 'allows configuration customization' do
      Ragdoll.configure do |config|
        config.chunk_size = 1500
        config.embedding_model = 'test-model'
      end

      expect(Ragdoll.configuration.chunk_size).to eq(1500)
      expect(Ragdoll.configuration.embedding_model).to eq('test-model')
    end
  end

  describe 'class-level convenience methods' do
    let(:mock_client) { instance_double(Ragdoll::Client) }

    before do
      allow(Ragdoll).to receive(:client).and_return(mock_client)
      allow(mock_client).to receive(:search_similar_content).and_return([])
    end

    describe '.enhance_prompt' do
      it 'delegates to client' do
        allow(mock_client).to receive(:enhance_prompt)

        Ragdoll.enhance_prompt("test prompt", context_limit: 3)

        expect(mock_client).to have_received(:enhance_prompt)
          .with("test prompt", context_limit: 3)
      end

      it_behaves_like 'a context provider' do
        subject { Ragdoll }
      end
    end

    describe '.search' do
      it 'delegates to client' do
        allow(mock_client).to receive(:search)

        Ragdoll.search("test query", limit: 5)

        expect(mock_client).to have_received(:search)
          .with("test query", limit: 5)
      end

      it_behaves_like 'a searchable interface' do
        subject { Ragdoll }
        
        before do
          allow(Ragdoll).to receive(:search).and_call_original
          allow(Ragdoll).to receive(:search_similar_content).and_return(mock_results)
          allow(mock_client).to receive(:search).and_return({
            query: query,
            results: mock_results,
            total_results: mock_results.length
          })
        end
      end
    end

    describe '.add_document' do
      it 'delegates to client' do
        allow(mock_client).to receive(:add_document)

        Ragdoll.add_document("content", title: "Test")

        expect(mock_client).to have_received(:add_document)
          .with("content", title: "Test")
      end
    end

    describe '.add_file' do
      it 'delegates to client' do
        allow(mock_client).to receive(:add_file)

        Ragdoll.add_file("/path/to/file.txt")

        expect(mock_client).to have_received(:add_file)
          .with("/path/to/file.txt")
      end
    end

    describe '.add_text' do
      it 'delegates to client' do
        allow(mock_client).to receive(:add_text)

        Ragdoll.add_text("content", title: "Test")

        expect(mock_client).to have_received(:add_text)
          .with("content", title: "Test")
      end
    end

    describe '.stats' do
      it 'delegates to client' do
        allow(mock_client).to receive(:stats)

        Ragdoll.stats

        expect(mock_client).to have_received(:stats)
      end

      it_behaves_like 'an analytics provider' do
        subject { Ragdoll }
        
        before do
          allow(Ragdoll).to receive(:stats).and_call_original
          allow(mock_client).to receive(:stats).and_return({
            total_documents: 3,
            total_embeddings: 15,
            documents_by_status: { 'completed' => 3 }
          })
          
          allow(Ragdoll).to receive(:search_analytics).and_call_original
          allow(mock_client).to receive(:search_analytics).and_return({
            total_searches: 5,
            unique_queries: 4,
            most_common_queries: []
          })
        end
      end
    end
  end

  describe 'client management' do
    it 'creates and memoizes client instance' do
      client1 = Ragdoll.client
      client2 = Ragdoll.client

      expect(client1).to be_a(Ragdoll::Client)
      expect(client1).to be(client2) # Same instance
    end

    it 'passes options to client constructor' do
      options = { embedding_service: double('service') }

      # Reset memoized client first
      Ragdoll.instance_variable_set(:@client, nil)
      
      expect(Ragdoll::Client).to receive(:new).with(options)

      Ragdoll.client(options)
    end

    it 'can be reset for testing' do
      original_client = Ragdoll.client
      Ragdoll.instance_variable_set(:@client, nil)
      new_client = Ragdoll.client

      expect(new_client).not_to be(original_client)
    end
  end

  describe 'integration capabilities' do
    it_behaves_like 'a configurable component' do
      subject { Ragdoll }
    end

    it_behaves_like 'a health checkable service' do
      subject { Ragdoll.client }
      
      before do
        allow(Ragdoll.client).to receive(:healthy?).and_call_original
        allow(Ragdoll.client).to receive(:stats).and_return({ total_documents: 0 })
        allow(Ragdoll.client.instance_variable_get(:@api)).to receive(:get_document_stats).and_return({ total_documents: 0 })
      end
    end
  end

  describe 'error handling and recovery' do
    it 'handles client creation errors gracefully' do
      # Reset memoized client first
      Ragdoll.instance_variable_set(:@client, nil)
      
      allow(Ragdoll::Client).to receive(:new)
        .and_raise(StandardError.new("Client creation error"))

      expect { Ragdoll.client }.to raise_error(StandardError, /Client creation error/)
    end

    it 'handles API method errors appropriately' do
      mock_client = instance_double(Ragdoll::Client)
      allow(Ragdoll).to receive(:client).and_return(mock_client)
      allow(mock_client).to receive(:search_similar_content)
        .and_raise(Ragdoll::SearchError.new("Search failed"))

      expect { Ragdoll.search("test") }.to raise_error(Ragdoll::SearchError, /Search failed/)
    end

    it 'provides meaningful error messages' do
      errors = [
        Ragdoll::Error.new("General error"),
        Ragdoll::EmbeddingError.new("Embedding error"),
        Ragdoll::SearchError.new("Search error"),
        Ragdoll::DocumentError.new("Document error")
      ]

      errors.each do |error|
        expect(error.message).to be_present
        expect(error).to be_a(StandardError)
      end
    end
  end

  describe 'version and metadata' do
    it 'defines version constant' do
      expect(defined?(Ragdoll::VERSION)).to be_truthy
      expect(Ragdoll::VERSION).to match(/\A\d+\.\d+\.\d+/)
    end
  end

  describe 'Rails engine integration' do
    it 'defines engine class' do
      expect(Ragdoll::Engine).to be < Rails::Engine
    end

    it 'isolates namespace properly' do
      expect(Ragdoll::Engine.isolated?).to be true
    end
  end
end