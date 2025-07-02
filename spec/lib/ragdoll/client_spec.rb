require 'rails_helper'

RSpec.describe Ragdoll::Client do
  let(:mock_api) { instance_double(Ragdoll::API) }
  let(:client) { described_class.new }

  before do
    allow(Ragdoll::API).to receive(:new).and_return(mock_api)
  end

  describe '#initialize' do
    it 'creates API instance with provided options' do
      options = { embedding_service: double('service') }
      
      expect(Ragdoll::API).to receive(:new).with(options)
      
      described_class.new(options)
    end
  end

  describe '#enhance_prompt' do
    let(:prompt) { "How do I configure the database?" }
    let(:context_data) do
      {
        context_chunks: [
          { source: { document_id: 1, document_title: 'Rails Guide', chunk_index: 0 } },
          { source: { document_id: 2, document_title: 'Config Guide', chunk_index: 1 } }
        ],
        combined_context: "Database configuration info\n\n---\n\nMore config details",
        total_chunks: 2
      }
    end

    before do
      allow(mock_api).to receive(:get_context).and_return(context_data)
      allow(client).to receive(:build_enhanced_prompt).and_call_original
    end

    context 'with context available' do
      it 'enhances prompt with context' do
        result = client.enhance_prompt(prompt, context_limit: 5)

        expect(mock_api).to have_received(:get_context).with(prompt, limit: 5)
        expect(result[:enhanced_prompt]).to include(prompt)
        expect(result[:enhanced_prompt]).to include("Database configuration info")
        expect(result[:original_prompt]).to eq(prompt)
        expect(result[:context_sources]).to eq(context_data[:context_chunks].map { |c| c[:source] })
        expect(result[:context_count]).to eq(2)
      end

      it 'passes through additional options' do
        client.enhance_prompt(prompt, context_limit: 3, threshold: 0.8, filters: { type: 'pdf' })

        expect(mock_api).to have_received(:get_context)
          .with(prompt, limit: 3, threshold: 0.8, filters: { type: 'pdf' })
      end
    end

    context 'with no context available' do
      before do
        allow(mock_api).to receive(:get_context).and_return({
          context_chunks: [],
          combined_context: "",
          total_chunks: 0
        })
      end

      it 'returns original prompt when no context found' do
        result = client.enhance_prompt(prompt)

        expect(result[:enhanced_prompt]).to eq(prompt)
        expect(result[:original_prompt]).to eq(prompt)
        expect(result[:context_sources]).to be_empty
        expect(result[:context_count]).to eq(0)
      end
    end
  end

  describe '#get_context' do
    it 'delegates to API with correct parameters' do
      allow(mock_api).to receive(:get_context)

      client.get_context("test query", limit: 5, threshold: 0.8)

      expect(mock_api).to have_received(:get_context)
        .with("test query", limit: 5, threshold: 0.8)
    end
  end

  describe '#search' do
    it 'delegates to API search method' do
      allow(mock_api).to receive(:search)

      client.search("test query", limit: 10)

      expect(mock_api).to have_received(:search)
        .with("test query", limit: 10)
    end
  end

  describe 'document management methods' do
    describe '#add_document' do
      it 'delegates to API add_document' do
        allow(mock_api).to receive(:add_document)

        client.add_document("/path/to/file.pdf", process_immediately: true)

        expect(mock_api).to have_received(:add_document)
          .with("/path/to/file.pdf", process_immediately: true)
      end
    end

    describe '#add_file' do
      it 'delegates to add_document' do
        allow(mock_api).to receive(:add_document)

        client.add_file("/path/to/file.pdf", metadata: { author: "Test" })

        expect(mock_api).to have_received(:add_document)
          .with("/path/to/file.pdf", metadata: { author: "Test" })
      end
    end

    describe '#add_text' do
      it 'adds text content with proper parameters' do
        allow(mock_api).to receive(:add_document)

        client.add_text("Text content", title: "Test Document", metadata: { type: "note" })

        expect(mock_api).to have_received(:add_document)
          .with("Text content", title: "Test Document", document_type: 'text', metadata: { type: "note" })
      end
    end

    describe '#add_directory' do
      it 'delegates to API add_documents_from_directory' do
        allow(mock_api).to receive(:add_documents_from_directory)

        client.add_directory("/docs", recursive: true, process_immediately: false)

        expect(mock_api).to have_received(:add_documents_from_directory)
          .with("/docs", recursive: true, process_immediately: false)
      end
    end

    describe '#get_document' do
      it 'delegates to API get_document' do
        allow(mock_api).to receive(:get_document)

        client.get_document(123)

        expect(mock_api).to have_received(:get_document).with(123)
      end
    end

    describe '#update_document' do
      it 'delegates to API update_document' do
        allow(mock_api).to receive(:update_document)

        client.update_document(123, title: "New Title")

        expect(mock_api).to have_received(:update_document)
          .with(123, title: "New Title")
      end
    end

    describe '#delete_document' do
      it 'delegates to API delete_document' do
        allow(mock_api).to receive(:delete_document)

        client.delete_document(123)

        expect(mock_api).to have_received(:delete_document).with(123)
      end
    end

    describe '#list_documents' do
      it 'delegates to API list_documents' do
        allow(mock_api).to receive(:list_documents)

        client.list_documents(limit: 50, offset: 10)

        expect(mock_api).to have_received(:list_documents)
          .with(limit: 50, offset: 10)
      end
    end
  end

  describe 'bulk operations' do
    describe '#reprocess_all' do
      it 'delegates to API reprocess_documents' do
        allow(mock_api).to receive(:reprocess_documents)

        client.reprocess_all(status_filter: 'failed')

        expect(mock_api).to have_received(:reprocess_documents)
          .with(status_filter: 'failed')
      end
    end

    describe '#reprocess_failed' do
      it 'reprocesses only failed documents' do
        allow(mock_api).to receive(:reprocess_documents)

        client.reprocess_failed

        expect(mock_api).to have_received(:reprocess_documents)
          .with(status_filter: 'failed')
      end
    end
  end

  describe 'analytics methods' do
    describe '#stats' do
      it 'delegates to API get_document_stats' do
        allow(mock_api).to receive(:get_document_stats)

        client.stats

        expect(mock_api).to have_received(:get_document_stats)
      end
    end

    describe '#search_analytics' do
      it 'delegates to API get_search_analytics' do
        allow(mock_api).to receive(:get_search_analytics)

        client.search_analytics(days: 14)

        expect(mock_api).to have_received(:get_search_analytics)
          .with(days: 14)
      end
    end
  end

  describe '#healthy?' do
    context 'when API is working' do
      before do
        allow(mock_api).to receive(:get_document_stats)
          .and_return({ total_documents: 5 })
      end

      it 'returns true for successful stats call' do
        expect(client.healthy?).to be true
      end
    end

    context 'when API fails' do
      before do
        allow(mock_api).to receive(:get_document_stats)
          .and_raise(StandardError.new("API Error"))
      end

      it 'returns false for API errors' do
        expect(client.healthy?).to be false
      end
    end
  end

  describe 'private methods' do
    describe '#build_enhanced_prompt' do
      let(:original_prompt) { "What is Rails?" }
      let(:context) { "Ruby on Rails is a web framework.\n\nIt follows MVC pattern." }

      context 'with custom template' do
        before do
          allow(Ragdoll.configuration).to receive(:prompt_template).and_return(
            "Context: {{context}}\nQuestion: {{prompt}}\nAnswer:"
          )
        end

        it 'uses custom template' do
          result = client.send(:build_enhanced_prompt, original_prompt, context)

          expect(result).to include("Context: #{context}")
          expect(result).to include("Question: #{original_prompt}")
          expect(result).to include("Answer:")
        end
      end

      context 'with default template' do
        before do
          allow(Ragdoll.configuration).to receive(:prompt_template).and_return(nil)
        end

        it 'uses default template' do
          result = client.send(:build_enhanced_prompt, original_prompt, context)

          expect(result).to include("Context:")
          expect(result).to include(context)
          expect(result).to include("Question: #{original_prompt}")
          expect(result).to include("Answer:")
        end
      end
    end

    describe '#default_prompt_template' do
      it 'returns well-formed template' do
        template = client.send(:default_prompt_template)

        expect(template).to include("{{context}}")
        expect(template).to include("{{prompt}}")
        expect(template).to include("Context:")
        expect(template).to include("Question:")
        expect(template).to include("Answer:")
      end
    end
  end
end

# Test class-level convenience methods
RSpec.describe Ragdoll do
  let(:mock_client) { instance_double(Ragdoll::Client) }

  before do
    allow(Ragdoll::Client).to receive(:new).and_return(mock_client)
    # Reset the memoized client
    Ragdoll.instance_variable_set(:@client, nil)
  end

  describe '.client' do
    it 'creates and memoizes client instance' do
      expect(Ragdoll::Client).to receive(:new).once.and_return(mock_client)

      client1 = Ragdoll.client
      client2 = Ragdoll.client

      expect(client1).to eq(mock_client)
      expect(client2).to eq(mock_client)
    end

    it 'passes options to client constructor' do
      options = { embedding_service: double('service') }

      expect(Ragdoll::Client).to receive(:new).with(options).and_return(mock_client)

      Ragdoll.client(options)
    end
  end

  describe 'class-level convenience methods' do
    before do
      allow(Ragdoll).to receive(:client).and_return(mock_client)
    end

    describe '.enhance_prompt' do
      it 'delegates to client' do
        allow(mock_client).to receive(:enhance_prompt)

        Ragdoll.enhance_prompt("test prompt", context_limit: 5)

        expect(mock_client).to have_received(:enhance_prompt)
          .with("test prompt", context_limit: 5)
      end
    end

    describe '.search' do
      it 'delegates to client' do
        allow(mock_client).to receive(:search)

        Ragdoll.search("test query", limit: 10)

        expect(mock_client).to have_received(:search)
          .with("test query", limit: 10)
      end
    end

    describe '.add_document' do
      it 'delegates to client' do
        allow(mock_client).to receive(:add_document)

        Ragdoll.add_document("/path/to/file.pdf")

        expect(mock_client).to have_received(:add_document)
          .with("/path/to/file.pdf")
      end
    end

    describe '.add_file' do
      it 'delegates to client' do
        allow(mock_client).to receive(:add_file)

        Ragdoll.add_file("/path/to/file.pdf")

        expect(mock_client).to have_received(:add_file)
          .with("/path/to/file.pdf")
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
    end
  end
end